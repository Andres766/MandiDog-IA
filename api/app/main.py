"""Punto de entrada. Uvicorn lo arranca como fábrica:
uvicorn app.main:create_app --factory
"""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from app import __version__
from app.core.auth import Authenticator, DevAuthenticator, FirebaseAuthenticator
from app.core.config import Settings, get_settings
from app.core.db import create_db_engine, create_session_factory
from app.core.errors import error_body, install_error_handlers
from app.core.logging import configure_logging
from app.inference import InferenceBackend, build_inference
from app.routers import analysis, health, me, pets, uploads
from app.services.storage import S3Storage, Storage, StorageError

logger = logging.getLogger("app")

DEV_AUTH_BANNER = """
==============================================================================
 ADVERTENCIA: AUTH_MODE=dev
 La API acepta el header X-Dev-User SIN verificar la identidad del usuario.
 Úsalo solo en desarrollo local. Con ENV=production la API no arranca así.
==============================================================================""".rstrip()


def _build_authenticator(settings: Settings) -> Authenticator:
    if settings.auth_mode == "dev":
        return DevAuthenticator()
    assert settings.firebase_project_id  # garantizado por Settings
    return FirebaseAuthenticator(settings.firebase_project_id)


def create_app(
    settings: Settings | None = None,
    *,
    authenticator: Authenticator | None = None,
    storage: Storage | None = None,
    inference: InferenceBackend | None = None,
) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)

    if settings.auth_mode == "dev":
        logger.warning(DEV_AUTH_BANNER)
    if settings.inference_backend == "stub":
        logger.warning(
            "INFERENCE_BACKEND=stub: los resultados son fijos (p=%.2f), no vienen de un modelo",
            settings.inference_stub_probability,
        )

    engine = create_db_engine(settings.database_url)
    inference = inference or build_inference(settings)
    logger.info("Modelo cargado: %s", inference.version)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        yield
        engine.dispose()

    app = FastAPI(
        title="MandiDog IA API",
        version=__version__,
        description="Tamizaje orientativo de patologías mandibulares en perros. "
        "No es un diagnóstico: toda respuesta recomienda consultar al veterinario.",
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.engine = engine
    app.state.session_factory = create_session_factory(engine)
    app.state.storage = storage or S3Storage(settings)
    app.state.inference = inference
    app.state.authenticator = authenticator or _build_authenticator(settings)

    install_error_handlers(app)

    @app.exception_handler(StorageError)
    async def _storage_error(_: Request, exc: StorageError) -> JSONResponse:
        logger.error("Fallo del almacenamiento: %s", exc, exc_info=exc)
        return JSONResponse(
            status_code=503,
            content=error_body(
                "storage_unavailable",
                "El servicio de imágenes no está disponible. Intenta de nuevo en unos minutos.",
            ),
        )

    app.include_router(health.router)
    app.include_router(me.router)
    app.include_router(pets.router)
    app.include_router(uploads.router)
    app.include_router(analysis.router)
    return app
