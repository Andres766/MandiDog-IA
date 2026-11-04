"""Pruebas unitarias de servicios puros (no necesitan BD ni almacenamiento)."""

import math

import numpy as np
import pytest
from PIL import Image

from app.inference.base import PreprocessingSpec
from app.inference.stub import StubInference
from app.models import RiskLevel
from app.services.image_quality import QualityThresholds, assess_quality, laplacian_variance
from app.services.preprocessing import preprocess
from app.services.risk import VET_NOTICE, assess_risk
from tests.helpers import (
    _noise,
    blurry_jpeg,
    bright_jpeg,
    dark_jpeg,
    encode,
    sharp_jpeg,
    sharp_png,
    small_jpeg,
)

THRESHOLDS = QualityThresholds(
    min_side_px=224, min_blur_variance=60, min_luminance=40, max_luminance=225
)

# ---------------------------------------------------------------- riesgo


@pytest.mark.parametrize(
    ("p", "level"),
    [
        (0.0, RiskLevel.GREEN),
        (0.2999, RiskLevel.GREEN),
        (0.30, RiskLevel.YELLOW),
        (0.5999, RiskLevel.YELLOW),
        (0.60, RiskLevel.RED),
        (1.0, RiskLevel.RED),
    ],
)
def test_umbrales_de_riesgo(p, level):
    assert assess_risk(p, yellow=0.30, red=0.60).level == level


def test_confianza_es_la_probabilidad_de_la_clase_predicha():
    assert assess_risk(0.2, yellow=0.3, red=0.6).confidence == pytest.approx(0.8)
    assert assess_risk(0.9, yellow=0.3, red=0.6).confidence == pytest.approx(0.9)


@pytest.mark.parametrize("p", [0.05, 0.4, 0.95])
def test_toda_recomendacion_incluye_aviso_veterinario(p):
    assert VET_NOTICE in assess_risk(p, yellow=0.3, red=0.6).recommendation


@pytest.mark.parametrize("p", [-0.01, 1.01, math.nan])
def test_probabilidad_fuera_de_rango(p):
    with pytest.raises(ValueError):
        assess_risk(p, yellow=0.3, red=0.6)


def test_umbrales_incoherentes():
    with pytest.raises(ValueError):
        assess_risk(0.5, yellow=0.6, red=0.3)


# --------------------------------------------------------------- calidad


def test_laplaciano_de_imagen_plana_es_cero():
    assert laplacian_variance(np.full((50, 50), 128, dtype=np.uint8)) == 0


def test_foto_nitida_pasa_el_control():
    report = assess_quality(sharp_jpeg(), "image/jpeg", THRESHOLDS)
    assert report.ok
    assert (report.width, report.height) == (640, 480)
    assert 100 < report.luminance < 160


def test_png_nitido_pasa_el_control():
    assert assess_quality(sharp_png(), "image/png", THRESHOLDS).ok


@pytest.mark.parametrize(
    ("image", "code"),
    [
        (blurry_jpeg, "blurry"),
        (dark_jpeg, "too_dark"),
        (bright_jpeg, "too_bright"),
        (small_jpeg, "too_small"),
    ],
)
def test_problemas_de_calidad_detectados(image, code):
    report = assess_quality(image(), "image/jpeg", THRESHOLDS)
    assert not report.ok
    assert code in [issue.code for issue in report.issues]


def test_bytes_que_no_son_imagen():
    report = assess_quality(b"esto no es una imagen", "image/jpeg", THRESHOLDS)
    assert [i.code for i in report.issues] == ["unreadable"]


def test_formato_real_distinto_al_declarado():
    report = assess_quality(sharp_png(), "image/jpeg", THRESHOLDS)
    assert [i.code for i in report.issues] == ["format_mismatch"]


def test_orientacion_exif_se_aplica():
    """Una foto vertical de celular llega como 640x480 con EXIF de rotación 90°."""
    exif = Image.Exif()
    exif[0x0112] = 6
    data = encode(_noise(640, 480, 60, 200), exif=exif)
    report = assess_quality(data, "image/jpeg", THRESHOLDS)
    assert (report.width, report.height) == (480, 640)


# --------------------------------------------------------- preprocesado


@pytest.mark.parametrize(
    ("mode", "low", "high"),
    [("unit", 0.0, 1.0), ("mobilenet_v2", -1.0, 1.0), ("resnet50", -124.0, 152.0)],
)
def test_preprocesado_tamano_y_rango(mode, low, high):
    image = _noise(640, 480, 0, 256)
    batch = preprocess(image, PreprocessingSpec(224, mode))
    assert batch.shape == (1, 224, 224, 3)
    assert batch.dtype == np.float32
    assert low <= batch.min() and batch.max() <= high


def test_preprocesado_resnet_invierte_canales_a_bgr():
    red = Image.new("RGB", (224, 224), (255, 0, 0))
    batch = preprocess(red, PreprocessingSpec(224, "resnet50"))
    # En BGR el rojo queda en el último canal.
    assert batch[0, 0, 0, 2] == pytest.approx(255 - 123.68)
    assert batch[0, 0, 0, 0] == pytest.approx(-103.939)


# ------------------------------------------------------------------ stub


def test_stub_devuelve_probabilidad_fija():
    stub = StubInference(0.42)
    assert stub.predict(np.zeros((1, 224, 224, 3), np.float32)) == 0.42
    assert stub.version == "stub-1"


def test_stub_valida_forma_del_lote():
    with pytest.raises(ValueError):
        StubInference(0.42).predict(np.zeros((224, 224, 3), np.float32))


def test_stub_valida_probabilidad():
    with pytest.raises(ValueError):
        StubInference(1.5)
