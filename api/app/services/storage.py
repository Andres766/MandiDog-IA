"""Almacenamiento de imágenes: interfaz + implementación S3 (Cloudflare R2 / MinIO)."""

from dataclasses import dataclass
from typing import Protocol

import boto3
from botocore.client import BaseClient
from botocore.config import Config
from botocore.exceptions import BotoCoreError, ClientError

from app.core.config import StorageSettings

TMP_PREFIX = "tmp/"
PERMANENT_PREFIX = "permanent/"

# Regla de ciclo de vida: borra tmp/ al día siguiente. Es la red de seguridad para
# cargas abandonadas; la API borra el temporal apenas termina de procesarlo.
TMP_LIFECYCLE = {
    "Rules": [
        {
            "ID": "borrar-tmp-24h",
            "Status": "Enabled",
            "Filter": {"Prefix": TMP_PREFIX},
            "Expiration": {"Days": 1},
        }
    ]
}


class StorageError(Exception):
    """El almacenamiento no respondió como se esperaba."""


@dataclass(frozen=True)
class ObjectInfo:
    size: int
    content_type: str | None


class Storage(Protocol):
    def presign_put(
        self, key: str, *, content_type: str, content_length: int, expires_in: int
    ) -> str: ...

    def head(self, key: str) -> ObjectInfo | None: ...

    def download(self, key: str, *, max_bytes: int) -> bytes: ...

    def copy(self, source_key: str, dest_key: str) -> None: ...

    def delete(self, key: str) -> None: ...


def _client_config() -> Config:
    return Config(
        signature_version="s3v4",
        s3={"addressing_style": "path"},
        retries={"max_attempts": 3, "mode": "standard"},
        connect_timeout=5,
        read_timeout=20,
        # Desde boto3 1.36 se añaden checksums CRC32 por defecto; R2 y las URLs firmadas
        # no los necesitan y rompen la compatibilidad.
        request_checksum_calculation="when_required",
        response_checksum_validation="when_required",
    )


def build_s3_client(settings: StorageSettings, *, endpoint_url: str | None) -> BaseClient:
    return boto3.client(
        "s3",
        endpoint_url=endpoint_url,
        region_name=settings.s3_region,
        aws_access_key_id=settings.s3_access_key_id.get_secret_value(),
        aws_secret_access_key=settings.s3_secret_access_key.get_secret_value(),
        config=_client_config(),
    )


def _is_not_found(exc: ClientError) -> bool:
    return exc.response.get("Error", {}).get("Code") in {"404", "NoSuchKey", "NotFound"}


class S3Storage:
    """Usa dos clientes: uno interno para operar sobre el bucket y otro solo para firmar
    con el host público (en local la API ve `minio:9000` pero la app ve `localhost:9000`;
    la firma incluye el host, así que no se puede reescribir después)."""

    def __init__(self, settings: StorageSettings) -> None:
        self._bucket = settings.s3_bucket
        self._client = build_s3_client(settings, endpoint_url=settings.s3_endpoint_url)
        self._presign_client = build_s3_client(
            settings, endpoint_url=settings.s3_public_endpoint_url or settings.s3_endpoint_url
        )

    def presign_put(
        self, key: str, *, content_type: str, content_length: int, expires_in: int
    ) -> str:
        # Content-Type y Content-Length quedan como cabeceras firmadas: si la app sube
        # otro tipo u otro tamaño, R2/MinIO rechazan la firma. Es la forma de limitar
        # el tamaño con PUT, porque R2 no soporta POST firmado con content-length-range.
        return self._presign_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": self._bucket,
                "Key": key,
                "ContentType": content_type,
                "ContentLength": content_length,
            },
            ExpiresIn=expires_in,
            HttpMethod="PUT",
        )

    def head(self, key: str) -> ObjectInfo | None:
        try:
            response = self._client.head_object(Bucket=self._bucket, Key=key)
        except ClientError as exc:
            if _is_not_found(exc):
                return None
            raise StorageError(f"head_object falló para {key}") from exc
        except BotoCoreError as exc:
            raise StorageError(f"head_object falló para {key}") from exc
        return ObjectInfo(size=response["ContentLength"], content_type=response.get("ContentType"))

    def download(self, key: str, *, max_bytes: int) -> bytes:
        try:
            response = self._client.get_object(Bucket=self._bucket, Key=key)
            body = response["Body"]
            try:
                data = body.read(max_bytes + 1)
            finally:
                body.close()
        except (BotoCoreError, ClientError) as exc:
            raise StorageError(f"get_object falló para {key}") from exc
        if len(data) > max_bytes:
            raise StorageError(f"{key} supera {max_bytes} bytes")
        return data

    def copy(self, source_key: str, dest_key: str) -> None:
        try:
            self._client.copy_object(
                Bucket=self._bucket,
                Key=dest_key,
                CopySource={"Bucket": self._bucket, "Key": source_key},
                MetadataDirective="COPY",
            )
        except (BotoCoreError, ClientError) as exc:
            raise StorageError(f"copy_object falló {source_key} -> {dest_key}") from exc

    def delete(self, key: str) -> None:
        try:
            self._client.delete_object(Bucket=self._bucket, Key=key)
        except (BotoCoreError, ClientError) as exc:
            raise StorageError(f"delete_object falló para {key}") from exc
