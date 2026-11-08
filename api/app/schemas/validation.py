import uuid
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.models import RiskLevel, VetAssessment


class PendingCaseOut(BaseModel):
    """Caso para valorar a ciegas: sin nivel de riesgo, estado ni hallazgos de la IA."""

    analysis_id: uuid.UUID
    created_at: datetime
    sub_part: Literal["TLEFT", "TCENTER", "TRIGHT"] | None
    pet_name: str
    breed: str | None
    sex: str
    birth_date: date | None
    photo_urls: list[str] = Field(
        description="Recortes de la foto analizada (sin mapas de calor). Pueden vencer."
    )


class ValidationIn(BaseModel):
    vet_assessment: VetAssessment
    notes: str | None = Field(default=None, max_length=1000)


class RevealOut(BaseModel):
    """Se entrega solo después de registrar la valoración."""

    validation_id: uuid.UUID
    vet_assessment: VetAssessment
    ai_risk_level: RiskLevel
    ai_provider_status: Literal["NORMAL", "CAUTION", "WARNING"]
    ai_sees_signs: bool
    agreement: bool | None = Field(description="null si el caso no era evaluable")


class MatrixOut(BaseModel):
    n: int
    true_positive: int
    false_positive: int
    false_negative: int
    true_negative: int
    sensitivity: float | None
    specificity: float | None
    accuracy: float | None


class SummaryOut(BaseModel):
    validations: int
    not_evaluable: int
    criterion: str
    overall: MatrixOut
    by_cephalic_group: dict[str, MatrixOut]
    by_breed: dict[str, MatrixOut]
