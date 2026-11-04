import uuid

from fastapi import APIRouter, Response, status

from app.deps import AppSettings, CurrentUser, DbSession, InferenceDep, StorageDep
from app.schemas.analysis import AnalysisCreateIn, AnalysisOut
from app.services.analysis_service import AnalysisRequest, AnalysisService
from app.services.pet_service import revoke_image_consent

router = APIRouter(prefix="/api/v1", tags=["análisis"])


@router.post("/analysis", response_model=AnalysisOut, status_code=status.HTTP_201_CREATED)
def create_analysis(
    body: AnalysisCreateIn,
    user: CurrentUser,
    db: DbSession,
    storage: StorageDep,
    inference: InferenceDep,
    settings: AppSettings,
) -> AnalysisOut:
    """Procesa una foto ya subida con la URL firmada.

    Errores relevantes para la app:
    - 404 `upload_not_found` / `pet_not_found` / `upload_missing`
    - 409 `upload_already_used` / `consent_policy_outdated`
    - 422 `image_quality` (details trae qué corregir) / `upload_mismatch`
    """
    service = AnalysisService(db, storage, inference, settings)
    analysis = service.create(
        user,
        AnalysisRequest(
            pet_id=body.pet_id,
            object_key=body.object_key,
            image_consent=body.image_consent,
            consent_policy_version=body.consent_policy_version,
        ),
    )
    return AnalysisOut.from_model(analysis)


@router.delete("/analyses/{analysis_id}/image", status_code=status.HTTP_204_NO_CONTENT)
def revoke_image(
    analysis_id: uuid.UUID, user: CurrentUser, db: DbSession, storage: StorageDep
) -> Response:
    """Revoca la autorización de uso de la foto: la borra y deja constancia de la fecha."""
    revoke_image_consent(db, storage, user, analysis_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
