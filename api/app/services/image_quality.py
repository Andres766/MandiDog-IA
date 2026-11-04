"""Control de calidad de la foto antes de inferir: formato, tamaño, desenfoque y luz.

Los mensajes se muestran tal cual al usuario y dicen qué corregir.
"""

from dataclasses import dataclass, field
from io import BytesIO

import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

# Formato real que debe tener el archivo según el Content-Type autorizado en la firma.
# Varios celulares guardan JPEG que Pillow identifica como MPO (multi-picture).
EXPECTED_FORMATS = {"image/jpeg": {"JPEG", "MPO"}, "image/png": {"PNG"}}
# Tope de píxeles para evitar bombas de descompresión (≈ 40 MP).
MAX_PIXELS = 40_000_000
# El desenfoque se mide siempre con el lado mayor reducido a este tamaño, para que el
# umbral no dependa de la resolución de la cámara.
BLUR_ANALYSIS_LONG_SIDE = 512

MESSAGES = {
    "unreadable": "No pudimos leer la imagen. Toma la foto de nuevo con la cámara de la app.",
    "format_mismatch": (
        "El archivo no corresponde al formato declarado. Toma la foto de nuevo con la cámara "
        "de la app."
    ),
    "too_many_pixels": (
        "La imagen tiene una resolución demasiado alta. Toma la foto con la cámara de la app."
    ),
    "too_small": (
        "La imagen es muy pequeña ({width}×{height} px; mínimo {min_side} px por lado). "
        "Toma la foto completa, sin recortarla."
    ),
    "blurry": (
        "La foto está desenfocada. Sostén el teléfono firme, a unos 20–30 cm de la boca, y "
        "toca la pantalla para enfocar antes de disparar."
    ),
    "too_dark": (
        "La foto está muy oscura. Busca luz natural o una lámpara que ilumine la boca del perro."
    ),
    "too_bright": (
        "La foto tiene demasiada luz. Evita el sol directo y el reflejo del flash sobre la boca."
    ),
}


@dataclass(frozen=True)
class QualityThresholds:
    min_side_px: int
    min_blur_variance: float
    min_luminance: float
    max_luminance: float


@dataclass(frozen=True)
class QualityIssue:
    code: str
    message: str


@dataclass
class QualityReport:
    issues: list[QualityIssue] = field(default_factory=list)
    image: Image.Image | None = None
    width: int = 0
    height: int = 0
    blur_variance: float = 0.0
    luminance: float = 0.0

    @property
    def ok(self) -> bool:
        return not self.issues and self.image is not None

    def add(self, code: str, **fmt: object) -> None:
        self.issues.append(QualityIssue(code=code, message=MESSAGES[code].format(**fmt)))


def laplacian_variance(gray: np.ndarray) -> float:
    """Varianza del laplaciano 4-vecinos. Valores bajos = imagen borrosa."""
    g = gray.astype(np.float64)
    lap = g[:-2, 1:-1] + g[2:, 1:-1] + g[1:-1, :-2] + g[1:-1, 2:] - 4.0 * g[1:-1, 1:-1]
    return float(lap.var())


def _gray_for_analysis(image: Image.Image) -> np.ndarray:
    gray = image.convert("L")
    long_side = max(gray.size)
    if long_side > BLUR_ANALYSIS_LONG_SIDE:
        scale = BLUR_ANALYSIS_LONG_SIDE / long_side
        new_size = (max(1, round(gray.width * scale)), max(1, round(gray.height * scale)))
        gray = gray.resize(new_size, Image.Resampling.BILINEAR)
    return np.asarray(gray)


def assess_quality(
    data: bytes, declared_content_type: str, thresholds: QualityThresholds
) -> QualityReport:
    report = QualityReport()
    try:
        with Image.open(BytesIO(data)) as probe:
            real_format = probe.format
            pixels = probe.width * probe.height
            probe.verify()
    except (UnidentifiedImageError, OSError, SyntaxError, Image.DecompressionBombError):
        report.add("unreadable")
        return report

    if real_format not in EXPECTED_FORMATS.get(declared_content_type, set()):
        report.add("format_mismatch")
        return report
    if pixels > MAX_PIXELS:
        report.add("too_many_pixels")
        return report

    try:
        image = Image.open(BytesIO(data))
        image.load()
        # La orientación EXIF del celular se aplica antes de medir y de inferir.
        image = ImageOps.exif_transpose(image).convert("RGB")
    except (OSError, SyntaxError, Image.DecompressionBombError):
        report.add("unreadable")
        return report

    report.image = image
    report.width, report.height = image.size
    if min(image.size) < thresholds.min_side_px:
        report.add(
            "too_small",
            width=report.width,
            height=report.height,
            min_side=thresholds.min_side_px,
        )

    gray = _gray_for_analysis(image)
    report.luminance = float(gray.mean())
    report.blur_variance = laplacian_variance(gray)

    if report.blur_variance < thresholds.min_blur_variance:
        report.add("blurry")
    if report.luminance < thresholds.min_luminance:
        report.add("too_dark")
    elif report.luminance > thresholds.max_luminance:
        report.add("too_bright")
    return report
