"""Firma de cargas y verificación de pertenencia de la object_key."""

import uuid
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.core.config import Settings
from app.core.errors import ConflictError, NotFoundError, UnprocessableError
from app.models import Upload, User
from app.services.storage import TMP_PREFIX, Storage

EXTENSIONS = {"image/jpeg": "jpg", "image/png": "png"}
OBJECT_KEY_PATTERN = (
    r"^tmp/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png)$"
)


@dataclass(frozen=True)
class SignedUpload:
    upload_url: str
    object_key: str
    expires_at: datetime
    headers: dict[str, str]


def sign_upload(
    db: Session,
    storage: Storage,
    settings: Settings,
    user: User,
    *,
    content_type: str,
    content_length: int,
) -> SignedUpload:
    if content_length > settings.upload_max_bytes:
        max_mb = settings.upload_max_bytes / (1024 * 1024)
        raise UnprocessableError(
            "file_too_large",
            f"La imagen pesa más de {max_mb:g} MB. Tómala de nuevo con la cámara de la app.",
        )

    # La clave la genera el servidor; el cliente nunca la elige.
    object_key = f"{TMP_PREFIX}{uuid.uuid4()}.{EXTENSIONS[content_type]}"
    expires_in = settings.upload_url_expires_seconds
    expires_at = datetime.now(UTC) + timedelta(seconds=expires_in)

    upload_url = storage.presign_put(
        object_key,
        content_type=content_type,
        content_length=content_length,
        expires_in=expires_in,
    )
    db.add(
        Upload(
            object_key=object_key,
            user_id=user.id,
            content_type=content_type,
            content_length=content_length,
            expires_at=expires_at,
        )
    )
    db.commit()
    return SignedUpload(
        upload_url=upload_url,
        object_key=object_key,
        expires_at=expires_at,
        headers={"Content-Type": content_type},
    )


def claim_upload(db: Session, user: User, object_key: str) -> Upload:
    """Marca la carga como consumida si pertenece al usuario y no se ha usado.

    No hace commit: el reclamo queda en la transacción del análisis. Si el análisis falla
    por un error inesperado, el rollback lo deshace y la carga se puede reintentar.
    """
    claimed = db.scalars(
        update(Upload)
        .where(
            Upload.object_key == object_key,
            Upload.user_id == user.id,
            Upload.consumed_at.is_(None),
        )
        .values(consumed_at=func.now())
        .returning(Upload),
        execution_options={"synchronize_session": False},
    ).one_or_none()
    if claimed is not None:
        return claimed

    already_used = db.scalar(
        select(Upload.object_key).where(Upload.object_key == object_key, Upload.user_id == user.id)
    )
    if already_used:
        raise ConflictError(
            "upload_already_used", "Esta foto ya fue analizada. Toma una foto nueva."
        )
    # Mismo error si no existe o si es de otro usuario: no revela claves ajenas.
    raise NotFoundError("upload_not_found", "No encontramos esa foto. Vuelve a tomarla.")
