import json

from fastapi import APIRouter, Response, status

from app.deps import AppSettings, CurrentUser, DbSession
from app.schemas.analysis import AnalysisCreateIn, AnalysisOut
from app.services.analysis_service import ScanSubmission, register_scan

router = APIRouter(prefix="/api/v1", tags=["análisis"])


@router.post(
    "/analysis",
    response_model=AnalysisOut,
    status_code=status.HTTP_201_CREATED,
    responses={200: {"model": AnalysisOut, "description": "Reintento: el escaneo ya existía"}},
)
def create_analysis(
    body: AnalysisCreateIn,
    response: Response,
    user: CurrentUser,
    db: DbSession,
    settings: AppSettings,
) -> AnalysisOut:
    """Guarda el resultado de un escaneo dental hecho con el SDK de AI for Pet.

    Errores relevantes para la app:
    - 404 `pet_not_found`
    - 409 `consent_required` / `scan_id_conflict`
    - 422 `scan_result_invalid` / `scan_result_mismatch`
    """
    registered = register_scan(
        db,
        settings,
        user,
        ScanSubmission(
            pet_id=body.pet_id,
            client_scan_id=body.client_scan_id,
            sdk_platform=body.sdk_platform,
            sdk_version=body.sdk_version,
            result=body.result,
            result_size=len(json.dumps(body.result)),
        ),
    )
    if not registered.created:
        response.status_code = status.HTTP_200_OK
    return AnalysisOut.from_model(registered.analysis)
