"""Fixtures de pruebas.

Los tests de integración usan PostgreSQL y MinIO reales (los de docker-compose): los CHECK y
enums son de Postgres y la firma con Content-Length solo se prueba contra un servidor S3.
    docker compose run --rm api pytest
"""

import os
from collections.abc import Callable, Iterator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from botocore.client import BaseClient
from botocore.exceptions import ClientError
from fastapi.testclient import TestClient
from sqlalchemy import Engine, create_engine, text

from app.core.config import Settings
from app.inference.stub import StubInference
from app.main import create_app
from app.services.storage import build_s3_client

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
        "s3_endpoint_url": _require_env("S3_ENDPOINT_URL"),
        # En los tests la URL firmada se usa desde el mismo contenedor que la API.
        "s3_public_endpoint_url": None,
        "s3_region": os.environ.get("S3_REGION", "us-east-1"),
        "s3_access_key_id": _require_env("S3_ACCESS_KEY_ID"),
        "s3_secret_access_key": _require_env("S3_SECRET_ACCESS_KEY"),
        "s3_bucket": f"{_require_env('S3_BUCKET')}-test",
        "upload_url_expires_seconds": 300,
        "upload_max_bytes": 10 * 1024 * 1024,
        "inference_backend": "stub",
        "inference_stub_probability": 0.15,
        "inference_model_path": None,
        "risk_threshold_yellow": 0.30,
        "risk_threshold_red": 0.60,
        "quality_min_side_px": 224,
        "quality_min_blur_variance": 60.0,
        "quality_min_luminance": 40.0,
        "quality_max_luminance": 225.0,
        "consent_policy_version": TEST_POLICY_VERSION,
    }

    def make(**overrides: object) -> Settings:
        return Settings(**{**base, **overrides})

    return make


@pytest.fixture(scope="session")
def engine(settings_factory: SettingsFactory) -> Iterator[Engine]:
    """BD de pruebas desde cero, aplicando la migración real (ida, vuelta e ida)."""
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


@pytest.fixture(scope="session")
def bucket(settings_factory: SettingsFactory) -> str:
    return settings_factory().s3_bucket


@pytest.fixture(scope="session")
def s3(settings_factory: SettingsFactory, bucket: str) -> BaseClient:
    """Cliente S3 "administrador" para inspeccionar el bucket desde los tests."""
    settings = settings_factory()
    client = build_s3_client(settings, endpoint_url=settings.s3_endpoint_url)
    try:
        client.head_bucket(Bucket=bucket)
    except ClientError:
        client.create_bucket(Bucket=bucket)
    return client


def list_keys(s3: BaseClient, bucket: str, prefix: str = "") -> list[str]:
    response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
    return sorted(obj["Key"] for obj in response.get("Contents", []))


@pytest.fixture
def clean_state(engine: Engine, s3: BaseClient, bucket: str) -> None:
    with engine.begin() as conn:
        conn.execute(text("TRUNCATE validations, analyses, uploads, pets, users CASCADE"))
    for key in list_keys(s3, bucket):
        s3.delete_object(Bucket=bucket, Key=key)


@pytest.fixture
def make_client(
    settings_factory: SettingsFactory, clean_state: None
) -> Iterator[Callable[..., TestClient]]:
    clients: list[TestClient] = []

    def make(*, probability: float = 0.15, authenticator=None, **overrides: object) -> TestClient:
        app = create_app(
            settings_factory(**overrides),
            inference=StubInference(probability),
            authenticator=authenticator,
        )
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
