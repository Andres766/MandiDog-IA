import uuid
from datetime import datetime

from pydantic import BaseModel, Field

from app.models import User, UserRole


class ConsentIn(BaseModel):
    policy_version: str = Field(min_length=1, max_length=50)


class ConsentOut(BaseModel):
    current_version: str
    accepted_version: str | None
    accepted_at: datetime | None
    required: bool = Field(
        description="true si la app debe mostrar la autorización antes de permitir escanear"
    )


class UserOut(BaseModel):
    id: uuid.UUID
    email: str | None
    display_name: str | None
    role: UserRole
    consent: ConsentOut

    @classmethod
    def from_model(cls, user: User, current_policy_version: str) -> "UserOut":
        return cls(
            id=user.id,
            email=user.email,
            display_name=user.display_name,
            role=user.role,
            consent=ConsentOut(
                current_version=current_policy_version,
                accepted_version=user.consent_policy_version,
                accepted_at=user.consent_at,
                required=user.consent_policy_version != current_policy_version,
            ),
        )
