import logging

import pytest
from pydantic import ValidationError

from app.core.config import get_settings, normalize_database_url
from app.main import create_app


def test_modo_dev_prohibido_en_produccion(settings_factory):
    with pytest.raises(ValidationError, match="AUTH_MODE=dev no está permitido"):
        settings_factory(env="production")


def test_la_api_no_arranca_en_dev_con_env_production(monkeypatch):
    """Arranque real desde variables de entorno, como lo hace uvicorn --factory."""
    monkeypatch.setenv("ENV", "production")
    monkeypatch.setenv("AUTH_MODE", "dev")
    get_settings.cache_clear()
    try:
        with pytest.raises(ValidationError, match="AUTH_MODE=dev"):
            create_app()
    finally:
        get_settings.cache_clear()


def test_produccion_con_firebase_si_arranca(settings_factory):
    settings = settings_factory(env="production", auth_mode="firebase", firebase_project_id="p")
    assert settings.env == "production"


def test_modo_dev_escribe_advertencia_visible(settings_factory, caplog):
    caplog.set_level(logging.WARNING, logger="app")
    create_app(settings_factory())
    assert "ADVERTENCIA: AUTH_MODE=dev" in caplog.text
    assert "X-Dev-User SIN verificar" in caplog.text


def test_firebase_requiere_project_id(settings_factory):
    with pytest.raises(ValidationError, match="FIREBASE_PROJECT_ID"):
        settings_factory(auth_mode="firebase", firebase_project_id=None)


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("postgres://u:p@h:5432/db", "postgresql+psycopg://u:p@h:5432/db"),
        ("postgresql://u:p@h:5432/db", "postgresql+psycopg://u:p@h:5432/db"),
        ("postgresql+psycopg://u:p@h/db", "postgresql+psycopg://u:p@h/db"),
    ],
)
def test_url_de_railway_se_normaliza(raw, expected):
    assert normalize_database_url(raw) == expected
