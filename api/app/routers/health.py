import logging

from fastapi import APIRouter, Request, Response
from sqlalchemy import text

from app import __version__
from app.schemas.health import HealthOut

logger = logging.getLogger("app.health")
router = APIRouter(tags=["salud"])


@router.get("/health", response_model=HealthOut)
def health(request: Request, response: Response) -> HealthOut:
    state = request.app.state
    database = "ok"
    try:
        with state.engine.connect() as connection:
            connection.execute(text("SELECT 1"))
    except Exception:
        logger.exception("La base de datos no responde")
        database = "error"

    if database != "ok":
        response.status_code = 503
    return HealthOut(
        status="ok" if database == "ok" else "degraded",
        version=__version__,
        environment=state.settings.env,
        analysis_provider="aiforpet",
        database=database,
    )
