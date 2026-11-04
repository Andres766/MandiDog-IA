import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import distinct_on
from sqlalchemy.orm import Session

from app.core.errors import NotFoundError
from app.models import Analysis, Pet, RiskLevel, User


def get_owned_pet(db: Session, user: User, pet_id: uuid.UUID) -> Pet:
    pet = db.scalar(select(Pet).where(Pet.id == pet_id, Pet.owner_id == user.id))
    if pet is None:
        raise NotFoundError("pet_not_found", "No encontramos esa mascota.")
    return pet


def list_pets(db: Session, user: User) -> list[Pet]:
    return list(db.scalars(select(Pet).where(Pet.owner_id == user.id).order_by(Pet.created_at)))


def last_analyses(
    db: Session, pet_ids: list[uuid.UUID]
) -> dict[uuid.UUID, tuple[RiskLevel, datetime]]:
    """Nivel y fecha del análisis más reciente de cada mascota (una sola consulta)."""
    if not pet_ids:
        return {}
    rows = db.execute(
        select(Analysis.pet_id, Analysis.risk_level, Analysis.created_at)
        .where(Analysis.pet_id.in_(pet_ids))
        .ext(distinct_on(Analysis.pet_id))
        .order_by(Analysis.pet_id, Analysis.created_at.desc())
    ).all()
    return {pet_id: (level, created_at) for pet_id, level, created_at in rows}


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
