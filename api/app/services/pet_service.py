import logging
import uuid
from datetime import UTC, datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models import Analysis, Pet, User
from app.services.storage import Storage

logger = logging.getLogger("app.pets")


def get_owned_pet(db: Session, user: User, pet_id: uuid.UUID) -> Pet:
    pet = db.scalar(select(Pet).where(Pet.id == pet_id, Pet.owner_id == user.id))
    if pet is None:
        raise NotFoundError("pet_not_found", "No encontramos esa mascota.")
    return pet


def list_pets(db: Session, user: User) -> list[Pet]:
    return list(db.scalars(select(Pet).where(Pet.owner_id == user.id).order_by(Pet.created_at)))


def create_pet(db: Session, user: User, data: dict[str, Any]) -> Pet:
    pet = Pet(owner_id=user.id, **data)
    db.add(pet)
    db.commit()
    db.refresh(pet)
    return pet


def update_pet(db: Session, user: User, pet_id: uuid.UUID, changes: dict[str, Any]) -> Pet:
    pet = get_owned_pet(db, user, pet_id)
    for field, value in changes.items():
        setattr(pet, field, value)
    db.commit()
    db.refresh(pet)
    return pet


def delete_pet(db: Session, storage: Storage, user: User, pet_id: uuid.UUID) -> None:
    """Borra la mascota, su historial y sus fotos conservadas.

    El CASCADE de Postgres no llega a R2: primero se borran los objetos y después las filas.
    Si R2 falla, no se toca la BD y la operación se puede reintentar.
    """
    pet = get_owned_pet(db, user, pet_id)
    image_keys = db.scalars(
        select(Analysis.image_key).where(Analysis.pet_id == pet.id, Analysis.image_key.is_not(None))
    ).all()
    for key in image_keys:
        storage.delete(key)
    db.delete(pet)
    db.commit()
    logger.info("Mascota %s eliminada con %d imágenes", pet_id, len(image_keys))


def list_analyses(
    db: Session, user: User, pet_id: uuid.UUID, *, limit: int, offset: int
) -> list[Analysis]:
    pet = get_owned_pet(db, user, pet_id)
    return list(
        db.scalars(
            select(Analysis)
            .where(Analysis.pet_id == pet.id)
            .order_by(Analysis.created_at.desc())
            .limit(limit)
            .offset(offset)
        )
    )


def revoke_image_consent(db: Session, storage: Storage, user: User, analysis_id: uuid.UUID) -> None:
    """Revocación de la autorización (Ley 1581): borra la foto y deja constancia."""
    analysis = db.scalar(
        select(Analysis)
        .join(Pet, Pet.id == Analysis.pet_id)
        .where(Analysis.id == analysis_id, Pet.owner_id == user.id)
    )
    if analysis is None:
        raise NotFoundError("analysis_not_found", "No encontramos ese análisis.")

    if analysis.image_key:
        storage.delete(analysis.image_key)
        analysis.image_key = None
    if analysis.image_consent and analysis.consent_revoked_at is None:
        analysis.consent_revoked_at = datetime.now(UTC)
    db.commit()
