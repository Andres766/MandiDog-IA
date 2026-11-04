import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, created_at_col, uuid_pk
from app.models.enums import RiskLevel, pg_enum


class Analysis(Base):
    """Resultado de un escaneo dental hecho con el SDK de AI for Pet."""

    __tablename__ = "analyses"

    id: Mapped[uuid.UUID] = uuid_pk()
    pet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("pets.id", ondelete="CASCADE"), nullable=False
    )
    # Generado por la app antes de escanear: permite reintentar el envío sin duplicar.
    client_scan_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), unique=True, nullable=False
    )
    risk_level: Mapped[RiskLevel] = mapped_column(pg_enum(RiskLevel, "risk_level"), nullable=False)
    # NORMAL | CAUTION | WARNING tal como lo devolvió AI for Pet
    provider_status: Mapped[str] = mapped_column(Text, nullable=False)
    part: Mapped[str] = mapped_column(Text, nullable=False)
    sub_part: Mapped[str | None] = mapped_column(Text)
    # Hallazgos normalizados: [{"code", "name", "status", "level"}]
    findings: Mapped[list[dict[str, Any]]] = mapped_column(JSONB, nullable=False)
    # JSON completo del SDK, para auditoría y para la validación clínica
    provider_result: Mapped[dict[str, Any]] = mapped_column(JSONB, nullable=False)
    provider_analyzed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    model_version: Mapped[str] = mapped_column(Text, nullable=False)
    recommendation: Mapped[str] = mapped_column(Text, nullable=False)
    # Versión de la autorización que el usuario tenía aceptada al registrar el análisis
    consent_policy_version: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = created_at_col()
