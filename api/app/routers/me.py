from fastapi import APIRouter, Response, status

from app.deps import AppSettings, CurrentUser, DbSession
from app.schemas.user import ConsentIn, UserOut
from app.services.user_service import accept_consent, delete_account, revoke_consent

router = APIRouter(prefix="/api/v1/me", tags=["usuario"])


@router.get("", response_model=UserOut)
def me(user: CurrentUser, settings: AppSettings) -> UserOut:
    """Usuario autenticado (se crea en la primera llamada) y estado de su autorización.

    Si `consent.required` es true, la app debe mostrar el texto de autorización y no puede
    abrir la cámara del SDK hasta que el usuario lo acepte.
    """
    return UserOut.from_model(user, settings.consent_policy_version)


@router.put("/consent", response_model=UserOut)
def give_consent(
    body: ConsentIn, user: CurrentUser, db: DbSession, settings: AppSettings
) -> UserOut:
    """Registra que el usuario aceptó la versión vigente del texto de autorización."""
    accept_consent(db, settings, user, body.policy_version)
    return UserOut.from_model(user, settings.consent_policy_version)


@router.delete("/consent", status_code=status.HTTP_204_NO_CONTENT)
def withdraw_consent(user: CurrentUser, db: DbSession) -> Response:
    """Revoca la autorización. El historial se conserva; no se pueden hacer análisis nuevos."""
    revoke_consent(db, user)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(user: CurrentUser, db: DbSession) -> Response:
    """Elimina la cuenta con todas sus mascotas e historial."""
    delete_account(db, user)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
