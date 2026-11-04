import uuid
from typing import Annotated

from fastapi import APIRouter, Query, Response, status

from app.deps import CurrentUser, DbSession
from app.schemas.analysis import AnalysisOut
from app.schemas.pet import PetCreateIn, PetOut, PetUpdateIn
from app.services import pet_service

router = APIRouter(prefix="/api/v1/pets", tags=["mascotas"])


@router.post("", response_model=PetOut, status_code=status.HTTP_201_CREATED)
def create_pet(body: PetCreateIn, user: CurrentUser, db: DbSession) -> PetOut:
    pet = pet_service.create_pet(db, user, body.model_dump())
    return PetOut.model_validate(pet)


@router.get("", response_model=list[PetOut])
def list_pets(user: CurrentUser, db: DbSession) -> list[PetOut]:
    return [PetOut.model_validate(p) for p in pet_service.list_pets(db, user)]


@router.get("/{pet_id}", response_model=PetOut)
def get_pet(pet_id: uuid.UUID, user: CurrentUser, db: DbSession) -> PetOut:
    return PetOut.model_validate(pet_service.get_owned_pet(db, user, pet_id))


@router.patch("/{pet_id}", response_model=PetOut)
def update_pet(pet_id: uuid.UUID, body: PetUpdateIn, user: CurrentUser, db: DbSession) -> PetOut:
    pet = pet_service.update_pet(db, user, pet_id, body.model_dump(exclude_unset=True))
    return PetOut.model_validate(pet)


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
