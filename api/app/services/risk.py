"""Probabilidad del modelo → nivel de riesgo + recomendación.

Los umbrales vienen de RISK_THRESHOLD_YELLOW / RISK_THRESHOLD_RED. Son bajos a propósito
(se prefiere falso positivo a falso negativo) y PROVISIONALES: el valor definitivo sale del
barrido de umbral en la validación cruzada de ml/.
"""

import math
from dataclasses import dataclass

from app.models.enums import RiskLevel

# Va en TODAS las recomendaciones. La app lo muestra siempre y no se puede ocultar.
VET_NOTICE = (
    "Este resultado es orientativo y no es un diagnóstico: consulta siempre a tu veterinario."
)

_GUIDANCE = {
    RiskLevel.GREEN: (
        "No se observaron signos de riesgo en esta foto. Si notas dolor al comer, mal aliento "
        "persistente, sangrado, inflamación o cambios en la mandíbula, consulta a tu veterinario."
    ),
    RiskLevel.YELLOW: (
        "Se observaron algunos signos que conviene revisar. Agenda una valoración con tu "
        "veterinario en los próximos días."
    ),
    RiskLevel.RED: (
        "Se observaron signos compatibles con una posible alteración mandibular. Consulta a tu "
        "veterinario lo antes posible."
    ),
}


@dataclass(frozen=True)
class RiskAssessment:
    level: RiskLevel
    probability_signs: float
    confidence: float
    recommendation: str


def recommendation_for(level: RiskLevel) -> str:
    return f"{_GUIDANCE[level]} {VET_NOTICE}"


def assess_risk(probability: float, *, yellow: float, red: float) -> RiskAssessment:
    if math.isnan(probability) or not 0.0 <= probability <= 1.0:
        raise ValueError(f"Probabilidad fuera de rango: {probability}")
    if not 0.0 < yellow < red < 1.0:
        raise ValueError("Se requiere 0 < umbral amarillo < umbral rojo < 1")

    if probability >= red:
        level = RiskLevel.RED
    elif probability >= yellow:
        level = RiskLevel.YELLOW
    else:
        level = RiskLevel.GREEN

    return RiskAssessment(
        level=level,
        probability_signs=round(probability, 4),
        confidence=round(max(probability, 1.0 - probability), 4),
        recommendation=recommendation_for(level),
    )
