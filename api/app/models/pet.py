import uuid
from datetime import date, datetime

from sqlalchemy import Date, ForeignKey, Numeric, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, created_at_col, updated_at_col, uuid_pk
from app.models.enums import PetSex, pg_enum


class Pet(Base):
    __tablename__ = "pets"

    id: Mapped[uuid.UUID] = uuid_pk()
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False
    )
    name: Mapped[str] = mapped_column(Text, nullable=False)
    breed: Mapped[str | None] = mapped_column(Text)
    sex: Mapped[PetSex] = mapped_column(
        pg_enum(PetSex, "pet_sex"), nullable=False, default=PetSex.UNKNOWN
    )
    birth_date: Mapped[date | None] = mapped_column(Date)
    weight_kg: Mapped[float | None] = mapped_column(Numeric(5, 2, asdecimal=False))
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()
