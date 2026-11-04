"""Configuración de la API. Se lee únicamente de variables de entorno."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def normalize_database_url(url: str) -> str:
    """Railway entrega postgresql:// o postgres://; SQLAlchemy necesita el driver explícito."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix) :]
    return url


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=None, extra="ignore")

    env: Literal["development", "test", "staging", "production"]
    log_level: str = "INFO"

    auth_mode: Literal["firebase", "dev"]
    firebase_project_id: str | None = None

    database_url: str

    # Versión vigente del texto de autorización (docs/datos-y-consentimiento.md).
    consent_policy_version: str = Field(min_length=1, max_length=50)

    # Orígenes web autorizados, separados por coma. Solo para probar la app en el navegador;
    # la app Android no necesita CORS. Vacío = sin CORS.
    cors_allow_origins: str = ""

    @property
    def cors_origins(self) -> list[str]:
        return [o.strip().rstrip("/") for o in self.cors_allow_origins.split(",") if o.strip()]

    @field_validator("database_url")
    @classmethod
    def _driver_psycopg(cls, value: str) -> str:
        return normalize_database_url(value)

    @field_validator("firebase_project_id", mode="before")
    @classmethod
    def _vacio_es_none(cls, value: object) -> object:
        return None if value == "" else value

    @model_validator(mode="after")
    def _coherencia(self) -> "Settings":
        if self.env == "production" and self.auth_mode == "dev":
            raise ValueError("AUTH_MODE=dev no está permitido con ENV=production")
        if self.auth_mode == "firebase" and not self.firebase_project_id:
            raise ValueError("AUTH_MODE=firebase requiere FIREBASE_PROJECT_ID")
        for origin in self.cors_origins:
            if not origin.startswith(("http://", "https://")) or "*" in origin:
                raise ValueError(f"CORS_ALLOW_ORIGINS: origen inválido {origin!r} (sin comodines)")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
