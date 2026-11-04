import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models import Analysis, Pet, User


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


def delete_pet(db: Session, user: User, pet_id: uuid.UUID) -> None:
    """Borra la mascota y su historial (CASCADE en la BD)."""
    pet = get_owned_pet(db, user, pet_id)
    db.delete(pet)
    db.commit()


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
