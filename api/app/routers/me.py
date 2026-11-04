from fastapi import APIRouter

from app.deps import CurrentUser
from app.schemas.user import UserOut

router = APIRouter(prefix="/api/v1", tags=["usuario"])


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser) -> UserOut:
    """Devuelve el usuario autenticado. Lo crea en la primera llamada."""
    return UserOut.model_validate(user)
