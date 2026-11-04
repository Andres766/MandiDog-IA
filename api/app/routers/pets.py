import uuid
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.deps import CurrentUser, DbSession
from app.models import Pet
from app.schemas.analysis import AnalysisOut
from app.schemas.pet import LastAnalysisOut, PetCreateIn, PetOut, PetUpdateIn
from app.services import pet_service

router = APIRouter(prefix="/api/v1/pets", tags=["mascotas"])


def _with_last(db: DbSession, pets: list[Pet]) -> list[PetOut]:
    last = pet_service.last_analyses(db, [p.id for p in pets])
    return [
        PetOut.from_model(
            p,
            LastAnalysisOut(risk_level=last[p.id][0], created_at=last[p.id][1])
            if p.id in last
            else None,
        )
        for p in pets
    ]


@router.post("", response_model=PetOut, status_code=status.HTTP_201_CREATED)
def create_pet(body: PetCreateIn, user: CurrentUser, db: DbSession) -> PetOut:
    pet = pet_service.create_pet(db, user, body.model_dump())
    return PetOut.from_model(pet)


@router.get("", response_model=list[PetOut])
def list_pets(user: CurrentUser, db: DbSession) -> list[PetOut]:
    return _with_last(db, pet_service.list_pets(db, user))


@router.get("/{pet_id}", response_model=PetOut)
def get_pet(pet_id: uuid.UUID, user: CurrentUser, db: DbSession) -> PetOut:
    return _with_last(db, [pet_service.get_owned_pet(db, user, pet_id)])[0]


@router.patch("/{pet_id}", response_model=PetOut)
def update_pet(pet_id: uuid.UUID, body: PetUpdateIn, user: CurrentUser, db: DbSession) -> PetOut:
    pet = pet_service.update_pet(db, user, pet_id, body.model_dump(exclude_unset=True))
    return _with_last(db, [pet])[0]


@router.delete("/{pet_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_pet(pet_id: uuid.UUID, user: CurrentUser, db: DbSession) -> Response:
    """Borra la mascota y su historial."""
    pet_service.delete_pet(db, user, pet_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{pet_id}/analyses", response_model=list[AnalysisOut])
def history(
    pet_id: uuid.UUID,
    user: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[AnalysisOut]:
    """Historial de análisis de la mascota, del más reciente al más antiguo."""
    analyses = pet_service.list_analyses(db, user, pet_id, limit=limit, offset=offset)
    return [AnalysisOut.from_model(a) for a in analyses]
