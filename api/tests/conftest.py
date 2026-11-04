"""Fixtures de pruebas.

Las pruebas de integración usan el PostgreSQL de docker-compose (base `*_test`): los CHECK,
los enums y JSONB son de Postgres.
    docker compose run --rm api pytest
"""

import os
from collections.abc import Callable, Iterator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine, text

from app.core.config import Settings
from app.main import create_app

API_DIR = Path(__file__).resolve().parents[1]
TEST_POLICY_VERSION = "test-v1"


def _require_env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        pytest.exit(
            f"Falta la variable {name}. Corre los tests con: docker compose run --rm api pytest",
            returncode=2,
        )
    return value


SettingsFactory = Callable[..., Settings]


@pytest.fixture(scope="session")
def settings_factory() -> SettingsFactory:
    base = {
        "env": "test",
        "log_level": "WARNING",
        "auth_mode": "dev",
        "firebase_project_id": None,
        "database_url": _require_env("TEST_DATABASE_URL"),
        "consent_policy_version": TEST_POLICY_VERSION,
    }

    def make(**overrides: object) -> Settings:
        return Settings(**{**base, **overrides})

    return make


@pytest.fixture(scope="session")
def engine(settings_factory: SettingsFactory) -> Iterator[Engine]:
    """BD de pruebas desde cero, aplicando las migraciones reales (ida, vuelta e ida)."""
    url = settings_factory().database_url
    eng = create_engine(url)
    with eng.begin() as conn:
        conn.execute(text("DROP SCHEMA public CASCADE"))
        conn.execute(text("CREATE SCHEMA public"))

    cfg = Config(str(API_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(API_DIR / "alembic"))
    cfg.set_main_option("sqlalchemy.url", url)
    cfg.attributes["configure_logger"] = False
    command.upgrade(cfg, "head")
    command.downgrade(cfg, "base")
    command.upgrade(cfg, "head")

    yield eng
    eng.dispose()


@pytest.fixture
def clean_state(engine: Engine) -> None:
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE validations, analyses, pets, users CASCADE"))


@pytest.fixture
def make_client(
    settings_factory: SettingsFactory, clean_state: None
) -> Iterator[Callable[..., TestClient]]:
    clients: list[TestClient] = []

    def make(*, authenticator=None, **overrides: object) -> TestClient:
        app = create_app(settings_factory(**overrides), authenticator=authenticator)
        client = TestClient(app)
        client.__enter__()
        clients.append(client)
        return client

    yield make
    for client in clients:
        client.__exit__(None, None, None)


@pytest.fixture
def client(make_client: Callable[..., TestClient]) -> TestClient:
    return make_client()
