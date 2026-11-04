import uuid
from datetime import date, datetime
from typing import Annotated

from pydantic import (
    AfterValidator,
    BaseModel,
    ConfigDict,
    Field,
    StringConstraints,
    field_validator,
)

from app.models import PetSex


def _not_in_future(value: date) -> date:
    if value > date.today():
        raise ValueError("La fecha de nacimiento no puede estar en el futuro")
    return value


Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
Breed = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=80)]
Weight = Annotated[float, Field(gt=0, lt=120)]
BirthDate = Annotated[date, AfterValidator(_not_in_future)]


class PetCreateIn(BaseModel):
    name: Name
    breed: Breed | None = None
    sex: PetSex = PetSex.UNKNOWN
    birth_date: BirthDate | None = None
    weight_kg: Weight | None = None


class PetUpdateIn(BaseModel):
    """Actualización parcial: solo se cambian los campos enviados."""

    name: Name | None = None
    breed: Breed | None = None
    sex: PetSex | None = None
    birth_date: BirthDate | None = None
    weight_kg: Weight | None = None

    @field_validator("name", "sex")
    @classmethod
    def _no_nulos(cls, value: object) -> object:
        if value is None:
            raise ValueError("No puede ser nulo")
        return value


class PetOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    name: str
    breed: str | None
    sex: PetSex
    birth_date: date | None
    weight_kg: float | None
    created_at: datetime
    updated_at: datetime
