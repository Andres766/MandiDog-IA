"""Punto de entrada. Uvicorn lo arranca como fábrica:
uvicorn app.main:create_app --factory
"""

import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import __version__
from app.core.auth import Authenticator, DevAuthenticator, FirebaseAuthenticator
from app.core.config import Settings, get_settings
from app.core.db import create_db_engine, create_session_factory
from app.core.errors import install_error_handlers
from app.core.logging import configure_logging
from app.routers import analysis, health, me, pets, validations

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
    settings: Settings | None = None, *, authenticator: Authenticator | None = None
) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    if settings.auth_mode == "dev":
        logger.warning(DEV_AUTH_BANNER)

    engine = create_db_engine(settings.database_url)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        yield
        engine.dispose()

    app = FastAPI(
        title="MandiDog IA API",
        version=__version__,
        description="Historial de escaneos dentales hechos con el SDK de AI for Pet. "
        "No es un diagnóstico: toda respuesta recomienda consultar al veterinario.",
        lifespan=lifespan,
    )
    app.state.settings = settings
    app.state.engine = engine
    app.state.session_factory = create_session_factory(engine)
    app.state.authenticator = authenticator or _build_authenticator(settings)

    if settings.cors_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origins,
            allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
            allow_headers=["Authorization", "Content-Type", "X-Dev-User"],
        )

    install_error_handlers(app)
    app.include_router(health.router)
    app.include_router(me.router)
    app.include_router(pets.router)
    app.include_router(analysis.router)
    app.include_router(validations.router)
    return app
