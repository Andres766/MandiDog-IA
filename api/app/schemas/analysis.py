import uuid
from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

from app.models import Analysis, RiskLevel


class AnalysisCreateIn(BaseModel):
    pet_id: uuid.UUID
    client_scan_id: uuid.UUID = Field(
        description="UUID que genera la app antes de escanear. Si el envío falla, reintenta "
        "con el mismo valor: la API no duplica el análisis."
    )
    sdk_platform: Literal["android", "ios"]
    sdk_version: str = Field(pattern=r"^[0-9]+(\.[0-9]+){1,3}([-+][0-9A-Za-z.]+)?$")
    result: dict[str, Any] = Field(
        description="JSON tal como lo devolvió el SDK de AI for Pet (escaneo de dientes)."
    )


class FindingOut(BaseModel):
    code: str
    name: str = Field(description="Nombre en español para mostrar")
    status: Literal["normal", "abnormal", "unknown"]


class AnalysisOut(BaseModel):
    analysis_id: uuid.UUID
    risk_level: RiskLevel
    provider_status: Literal["NORMAL", "CAUTION", "WARNING"]
    findings: list[FindingOut]
    sub_part: Literal["TLEFT", "TCENTER", "TRIGHT"] | None
    model_version: str
    recommendation: str
    created_at: datetime

    @classmethod
    def from_model(cls, analysis: Analysis) -> "AnalysisOut":
        return cls(
            analysis_id=analysis.id,
            risk_level=analysis.risk_level,
            provider_status=analysis.provider_status,
            findings=[FindingOut.model_validate(f) for f in analysis.findings],
            sub_part=analysis.sub_part,
            model_version=analysis.model_version,
            recommendation=analysis.recommendation,
            created_at=analysis.created_at,
        )
