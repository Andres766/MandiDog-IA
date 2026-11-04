from fastapi import APIRouter, status

from app.deps import AppSettings, CurrentUser, DbSession, StorageDep
from app.schemas.upload import SignUploadIn, SignUploadOut
from app.services.upload_service import sign_upload

router = APIRouter(prefix="/api/v1/uploads", tags=["cargas"])


@router.post("/sign", response_model=SignUploadOut, status_code=status.HTTP_201_CREATED)
def sign(
    body: SignUploadIn,
    user: CurrentUser,
    db: DbSession,
    storage: StorageDep,
    settings: AppSettings,
) -> SignUploadOut:
    """Entrega una URL firmada (PUT, 5 min) para subir la foto directo al almacenamiento.

    La app debe enviar el PUT con el Content-Type indicado en `headers` y exactamente
    `content_length` bytes; cualquier diferencia invalida la firma.
    """
    signed = sign_upload(
        db,
        storage,
        settings,
        user,
        content_type=body.content_type,
        content_length=body.content_length,
    )
    return SignUploadOut(
        upload_url=signed.upload_url,
        object_key=signed.object_key,
        expires_at=signed.expires_at,
        headers=signed.headers,
    )
