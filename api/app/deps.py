from collections.abc import Iterator
from typing import Annotated

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import ForbiddenError
from app.models import User, UserRole
from app.services.user_service import get_or_create_user


def get_settings_dep(request: Request) -> Settings:
    return request.app.state.settings


def get_db(request: Request) -> Iterator[Session]:
    session: Session = request.app.state.session_factory()
    try:
        yield session
    finally:
        session.close()


DbSession = Annotated[Session, Depends(get_db)]
AppSettings = Annotated[Settings, Depends(get_settings_dep)]


def get_current_user(request: Request, db: DbSession) -> User:
    principal = request.app.state.authenticator.authenticate(request)
    return get_or_create_user(db, principal)


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_current_vet(user: CurrentUser) -> User:
    """Solo veterinarios (o administradores) participan en la validación clínica."""
    if user.role not in (UserRole.VET, UserRole.ADMIN):
        raise ForbiddenError(
            "vet_only", "Esta sección es solo para veterinarios del estudio de validación."
        )
    return user


CurrentVet = Annotated[User, Depends(get_current_vet)]
