"""Configuración de la API. Se lee únicamente de variables de entorno."""

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def normalize_database_url(url: str) -> str:
    """Railway entrega postgresql:// o postgres://; SQLAlchemy necesita el driver explícito."""
    for prefix in ("postgres://", "postgresql://"):
        if url.startswith(prefix):
            return "postgresql+psycopg://" + url[len(prefix) :]
    return url


class StorageSettings(BaseSettings):
    """Solo lo necesario para hablar con R2/MinIO. La usa también scripts/init_storage.py."""

    model_config = SettingsConfigDict(env_file=None, extra="ignore")

    s3_endpoint_url: str | None = None
    s3_public_endpoint_url: str | None = None
    s3_region: str
    s3_access_key_id: SecretStr
    s3_secret_access_key: SecretStr
    s3_bucket: str


class Settings(StorageSettings):
    env: Literal["development", "test", "staging", "production"]
    log_level: str = "INFO"

    auth_mode: Literal["firebase", "dev"]
    firebase_project_id: str | None = None

    database_url: str

    upload_url_expires_seconds: int = Field(300, ge=30, le=3600)
    upload_max_bytes: int = Field(10 * 1024 * 1024, gt=0)

    inference_backend: Literal["stub", "keras"]
    inference_stub_probability: float = Field(0.15, ge=0, le=1)
    inference_model_path: str | None = None

    # Provisionales: el valor definitivo sale de la validación cruzada de ml/.
    risk_threshold_yellow: float = Field(0.30, gt=0, lt=1)
    risk_threshold_red: float = Field(0.60, gt=0, lt=1)

    quality_min_side_px: int = Field(224, gt=0)
    quality_min_blur_variance: float = Field(60.0, ge=0)
    quality_min_luminance: float = Field(40.0, ge=0, le=255)
    quality_max_luminance: float = Field(225.0, ge=0, le=255)

    consent_policy_version: str = Field(min_length=1, max_length=50)

    @field_validator("database_url")
    @classmethod
    def _driver_psycopg(cls, value: str) -> str:
        return normalize_database_url(value)

    @field_validator("firebase_project_id", "inference_model_path", mode="before")
    @classmethod
    def _vacio_es_none(cls, value: object) -> object:
        return None if value == "" else value

    @model_validator(mode="after")
    def _coherencia(self) -> "Settings":
        if self.env == "production" and self.auth_mode == "dev":
            raise ValueError("AUTH_MODE=dev no está permitido con ENV=production")
        if self.env == "production" and self.inference_backend == "stub":
            raise ValueError(
                "INFERENCE_BACKEND=stub no está permitido con ENV=production: "
                "devolvería resultados fijos a usuarios reales"
            )
        if self.auth_mode == "firebase" and not self.firebase_project_id:
            raise ValueError("AUTH_MODE=firebase requiere FIREBASE_PROJECT_ID")
        if self.inference_backend == "keras" and not self.inference_model_path:
            raise ValueError("INFERENCE_BACKEND=keras requiere INFERENCE_MODEL_PATH")
        if self.risk_threshold_yellow >= self.risk_threshold_red:
            raise ValueError("RISK_THRESHOLD_YELLOW debe ser menor que RISK_THRESHOLD_RED")
        if self.quality_min_luminance >= self.quality_max_luminance:
            raise ValueError("QUALITY_MIN_LUMINANCE debe ser menor que QUALITY_MAX_LUMINANCE")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
