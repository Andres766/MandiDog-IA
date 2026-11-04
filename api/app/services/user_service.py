from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.auth import Principal
from app.core.config import Settings
from app.core.errors import ConflictError
from app.models import User


def get_or_create_user(db: Session, principal: Principal) -> User:
    """El usuario se crea en la primera petición autenticada (no hay registro aparte)."""
    user = db.scalar(select(User).where(User.firebase_uid == principal.firebase_uid))
    if user is None:
        db.execute(
            insert(User)
            .values(
                firebase_uid=principal.firebase_uid,
                email=principal.email,
                display_name=principal.display_name,
            )
            .on_conflict_do_nothing(index_elements=[User.firebase_uid])
        )
        db.commit()
        user = db.scalar(select(User).where(User.firebase_uid == principal.firebase_uid))
        assert user is not None
    elif principal.email and principal.email != user.email:
        user.email = principal.email
        db.commit()
    return user


def accept_consent(db: Session, settings: Settings, user: User, policy_version: str) -> User:
    """Registra la autorización. Debe ser la versión vigente que la app mostró."""
    if policy_version != settings.consent_policy_version:
        raise ConflictError(
            "consent_policy_outdated",
            "El texto de autorización cambió. Actualiza la app y vuelve a leerlo.",
        )
    if user.consent_policy_version != policy_version:
        user.consent_policy_version = policy_version
        user.consent_at = datetime.now(UTC)
        db.commit()
    return user


def revoke_consent(db: Session, user: User) -> None:
    """Revocación (Ley 1581): desde ahora la app no puede enviar fotos a AI for Pet."""
    user.consent_policy_version = None
    user.consent_at = None
    db.commit()


def delete_account(db: Session, user: User) -> None:
    """Supresión: borra la cuenta, sus mascotas y su historial (CASCADE en la BD)."""
    db.delete(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        # Un veterinario con validaciones registradas no se borra sin revisar esos datos.
        raise ConflictError(
            "account_has_validations",
            "Esta cuenta tiene validaciones clínicas registradas. Escríbenos para eliminarla.",
        ) from exc
