import uuid
from datetime import datetime

from pydantic import BaseModel, Field, model_validator

from app.models import Analysis, RiskLevel
from app.services.upload_service import OBJECT_KEY_PATTERN


class AnalysisCreateIn(BaseModel):
    pet_id: uuid.UUID
    object_key: str = Field(pattern=OBJECT_KEY_PATTERN)
    image_consent: bool = False
    consent_policy_version: str | None = Field(
        default=None,
        max_length=50,
        description="Versión del texto de autorización que vio el usuario. "
        "Obligatoria si image_consent=true.",
    )

    @model_validator(mode="after")
    def _version_si_hay_consentimiento(self) -> "AnalysisCreateIn":
        if self.image_consent and not self.consent_policy_version:
            raise ValueError("consent_policy_version es obligatoria cuando image_consent=true")
        return self


class AnalysisOut(BaseModel):
    analysis_id: uuid.UUID
    risk_level: RiskLevel
    confidence: float
    model_version: str
    recommendation: str
    created_at: datetime

    @classmethod
    def from_model(cls, analysis: Analysis) -> "AnalysisOut":
        return cls(
            analysis_id=analysis.id,
            risk_level=analysis.risk_level,
            confidence=analysis.confidence,
            model_version=analysis.model_version,
            recommendation=analysis.recommendation,
            created_at=analysis.created_at,
        )


class AnalysisHistoryItem(AnalysisOut):
    image_consent: bool
    has_image: bool

    @classmethod
    def from_model(cls, analysis: Analysis) -> "AnalysisHistoryItem":
        base = AnalysisOut.from_model(analysis).model_dump()
        return cls(
            **base,
            image_consent=analysis.image_consent,
            has_image=analysis.image_key is not None,
        )
