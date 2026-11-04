from enum import StrEnum

from sqlalchemy import Enum as SAEnum


class UserRole(StrEnum):
    OWNER = "owner"
    VET = "vet"
    ADMIN = "admin"


class PetSex(StrEnum):
    MALE = "male"
    FEMALE = "female"
    UNKNOWN = "unknown"


class RiskLevel(StrEnum):
    GREEN = "green"
    YELLOW = "yellow"
    RED = "red"


class VetAssessment(StrEnum):
    SIN_SIGNOS = "sin_signos"
    CON_SIGNOS = "con_signos"
    NO_EVALUABLE = "no_evaluable"


def pg_enum(enum_cls: type[StrEnum], name: str) -> SAEnum:
    """Enum de Postgres que guarda el valor ("green"), no el nombre ("GREEN")."""
    return SAEnum(
        enum_cls,
        name=name,
        values_callable=lambda members: [m.value for m in members],
        create_type=False,
    )
