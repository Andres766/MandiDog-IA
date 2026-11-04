import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Double, ForeignKey, Integer, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, created_at_col, uuid_pk
from app.models.enums import RiskLevel, pg_enum


class Analysis(Base):
    __tablename__ = "analyses"

    id: Mapped[uuid.UUID] = uuid_pk()
    pet_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("pets.id", ondelete="CASCADE"), nullable=False
    )
    risk_level: Mapped[RiskLevel] = mapped_column(pg_enum(RiskLevel, "risk_level"), nullable=False)
    # max(p, 1 - p) del clasificador binario
    confidence: Mapped[float] = mapped_column(Numeric(5, 4, asdecimal=False), nullable=False)
    # p(con_signos) que devuelve el modelo
    probability_signs: Mapped[float] = mapped_column(Numeric(5, 4, asdecimal=False), nullable=False)
    model_version: Mapped[str] = mapped_column(Text, nullable=False)
    recommendation: Mapped[str] = mapped_column(Text, nullable=False)
    blur_variance: Mapped[float] = mapped_column(Double, nullable=False)
    luminance: Mapped[float] = mapped_column(Double, nullable=False)
    image_width: Mapped[int] = mapped_column(Integer, nullable=False)
    image_height: Mapped[int] = mapped_column(Integer, nullable=False)
    inference_ms: Mapped[int] = mapped_column(Integer, nullable=False)
    image_consent: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    consent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    consent_policy_version: Mapped[str | None] = mapped_column(Text)
    consent_revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    image_key: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_col()
