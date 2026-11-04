"""Interpretación del resultado del SDK de AI for Pet (escaneo dental).

Contrato documentado en https://sdk.aiforpet.com (guía Flutter v2.0.x, Android scansdk-lib
2.2.3). Reglas que se respetan aquí:
- La raíz `status` = SUCCESS solo significa que el análisis terminó, no que todo esté normal.
- `response.status` (NORMAL / CAUTION / WARNING) es el resumen que define el semáforo.
- Cada hallazgo se identifica por `code`, nunca por su posición en la lista.
- `abnormalLevel` (si viene) o `abnormLevel`: 0 normal, positivo anormal, negativo no evaluado.
- AI for Pet no expone puntajes ni probabilidades del modelo.
"""

from dataclasses import dataclass
from datetime import UTC, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.core.errors import UnprocessableError
from app.models.enums import RiskLevel

MAX_RESULT_BYTES = 64 * 1024

STATUS_TO_LEVEL = {
    "NORMAL": RiskLevel.GREEN,
    "CAUTION": RiskLevel.YELLOW,
    "WARNING": RiskLevel.RED,
}

# El SDK no tiene español: traducimos los códigos que documenta para dientes.
FINDING_NAMES_ES = {
    "calculus": "Sarro (cálculo dental)",
    "inflammation": "Inflamación de encías",
}

# Va en TODAS las recomendaciones. La app lo muestra siempre y no se puede ocultar.
VET_NOTICE = (
    "Este resultado es orientativo y no es un diagnóstico: consulta siempre a tu veterinario."
)

_GUIDANCE = {
    RiskLevel.GREEN: (
        "No se observaron signos de sarro ni de inflamación de encías en esta foto. Mantén la "
        "higiene dental de tu perro y consulta a tu veterinario si notas mal aliento "
        "persistente, sangrado, dolor al comer o cambios en la boca."
    ),
    RiskLevel.YELLOW: (
        "Se observaron signos en los dientes o las encías que conviene vigilar. Programa una "
        "revisión dental con tu veterinario."
    ),
    RiskLevel.RED: (
        "Se observaron signos en los dientes o las encías que requieren atención. Agenda una "
        "consulta con tu veterinario lo antes posible."
    ),
}


# ------------------------------------------------- contrato del SDK (camelCase)


class _SdkModel(BaseModel):
    # AI for Pet puede agregar campos nuevos: se aceptan y se guardan en el JSON original.
    model_config = ConfigDict(extra="allow")


class SdkSymptom(_SdkModel):
    code: str = Field(min_length=1, max_length=64)
    name: str | None = None
    abnormLevel: int | None = None
    abnormalLevel: int | None = None
    isAbnormal: bool | None = None
    resultLabel: str | None = None


class SdkResponse(_SdkModel):
    status: Literal["NORMAL", "CAUTION", "WARNING"]
    symptoms: list[SdkSymptom] = Field(default_factory=list, max_length=20)


class SdkToothResult(_SdkModel):
    status: Literal["SUCCESS"]
    petType: Literal["DOG"]
    part: Literal["TOOTH"]
    subPart: Literal["TLEFT", "TCENTER", "TRIGHT"] | None = None
    createdAt: int | None = None
    userId: str | None = None
    petId: str | None = None
    response: SdkResponse


# ------------------------------------------------------- resultado normalizado

FindingStatus = Literal["normal", "abnormal", "unknown"]


@dataclass(frozen=True)
class Finding:
    code: str
    name: str
    status: FindingStatus
    level: int | None

    def as_dict(self) -> dict[str, Any]:
        return {"code": self.code, "name": self.name, "status": self.status, "level": self.level}


@dataclass(frozen=True)
class ToothScan:
    risk_level: RiskLevel
    provider_status: str
    part: str
    sub_part: str | None
    findings: list[Finding]
    analyzed_at: datetime | None
    user_id: str | None
    pet_id: str | None
    recommendation: str


def recommendation_for(level: RiskLevel) -> str:
    return f"{_GUIDANCE[level]} {VET_NOTICE}"


def _finding_status(symptom: SdkSymptom) -> tuple[FindingStatus, int | None]:
    level = symptom.abnormalLevel if symptom.abnormalLevel is not None else symptom.abnormLevel
    if level is not None:
        if level < 0:
            return "unknown", level
        return ("abnormal" if level > 0 else "normal"), level
    label = (symptom.resultLabel or "").lower()
    if label == "normal":
        return "normal", None
    if label == "abnormal":
        return "abnormal", None
    return "unknown", None


def _epoch_ms(value: int | None) -> datetime | None:
    if value is None:
        return None
    try:
        moment = datetime.fromtimestamp(value / 1000, tz=UTC)
    except (OverflowError, OSError, ValueError):
        return None
    # Descarta valores absurdos en lugar de guardarlos.
    return moment if 2020 <= moment.year <= 2100 else None


def _validation_details(exc: ValidationError) -> list[dict[str, Any]]:
    return [
        {"field": ".".join(str(p) for p in err["loc"]), "problem": err["msg"]}
        for err in exc.errors()
    ]


def parse_tooth_scan(raw: dict[str, Any], *, raw_size: int) -> ToothScan:
    if raw_size > MAX_RESULT_BYTES:
        raise UnprocessableError(
            "scan_result_invalid", "El resultado del escaneo es demasiado grande."
        )
    try:
        sdk = SdkToothResult.model_validate(raw)
    except ValidationError as exc:
        raise UnprocessableError(
            "scan_result_invalid",
            "El resultado del escaneo no tiene el formato esperado de un análisis dental.",
            details=_validation_details(exc),
        ) from exc

    findings = []
    seen: set[str] = set()
    for symptom in sdk.response.symptoms:
        if symptom.code in seen:
            continue
        seen.add(symptom.code)
        status, level = _finding_status(symptom)
        name = FINDING_NAMES_ES.get(symptom.code) or symptom.name or symptom.code
        findings.append(Finding(code=symptom.code, name=name, status=status, level=level))

    level = STATUS_TO_LEVEL[sdk.response.status]
    return ToothScan(
        risk_level=level,
        provider_status=sdk.response.status,
        part=sdk.part,
        sub_part=sdk.subPart,
        findings=findings,
        analyzed_at=_epoch_ms(sdk.createdAt),
        user_id=sdk.userId,
        pet_id=sdk.petId,
        recommendation=recommendation_for(level),
    )
