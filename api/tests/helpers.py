"""Imágenes sintéticas y atajos para recorrer el flujo firma → PUT → análisis."""

from io import BytesIO
from typing import Any

import httpx2 as httpx
import numpy as np
from fastapi.testclient import TestClient
from PIL import Image

from tests.conftest import TEST_POLICY_VERSION


def auth(user: str = "ana") -> dict[str, str]:
    return {"X-Dev-User": user}


# ---------------------------------------------------------------- imágenes


def _noise(width: int, height: int, low: int, high: int, seed: int = 0) -> Image.Image:
    rng = np.random.default_rng(seed)
    pixels = rng.integers(low, high, size=(height, width, 3), dtype=np.uint8)
    return Image.fromarray(pixels, "RGB")


def encode(image: Image.Image, fmt: str = "JPEG", **kwargs: Any) -> bytes:
    buffer = BytesIO()
    if fmt == "JPEG":
        kwargs.setdefault("quality", 90)
    image.save(buffer, format=fmt, **kwargs)
    return buffer.getvalue()


def sharp_jpeg(seed: int = 0) -> bytes:
    """Textura con mucho detalle y luz media: pasa el control de calidad."""
    return encode(_noise(640, 480, 60, 200, seed))


def sharp_png() -> bytes:
    return encode(_noise(640, 480, 60, 200), "PNG")


def blurry_jpeg() -> bytes:
    """Degradado suave: sin bordes, varianza del laplaciano ≈ 0."""
    row = np.linspace(80, 180, 640, dtype=np.float32)
    gray = np.tile(row, (480, 1))
    pixels = np.stack([gray, gray, gray], axis=-1).astype(np.uint8)
    return encode(Image.fromarray(pixels, "RGB"))


def dark_jpeg() -> bytes:
    return encode(_noise(640, 480, 0, 30))


def bright_jpeg() -> bytes:
    return encode(_noise(640, 480, 235, 256))


def small_jpeg() -> bytes:
    return encode(_noise(120, 100, 60, 200))


# ------------------------------------------------------------------- flujo


def create_pet(client: TestClient, user: str = "ana", name: str = "Toby") -> dict[str, Any]:
    response = client.post("/api/v1/pets", json={"name": name}, headers=auth(user))
    assert response.status_code == 201, response.text
    return response.json()


def sign(
    client: TestClient,
    data: bytes,
    *,
    content_type: str = "image/jpeg",
    user: str = "ana",
    content_length: int | None = None,
) -> dict[str, Any]:
    response = client.post(
        "/api/v1/uploads/sign",
        json={
            "content_type": content_type,
            "content_length": content_length if content_length is not None else len(data),
        },
        headers=auth(user),
    )
    assert response.status_code == 201, response.text
    return response.json()


def put_signed(
    signed: dict[str, Any], data: bytes, headers: dict[str, str] | None = None
) -> httpx.Response:
    return httpx.put(signed["upload_url"], content=data, headers=headers or signed["headers"])


def upload(
    client: TestClient, data: bytes, *, content_type: str = "image/jpeg", user: str = "ana"
) -> str:
    signed = sign(client, data, content_type=content_type, user=user)
    response = put_signed(signed, data)
    assert response.status_code == 200, response.text
    return signed["object_key"]


def analyze(
    client: TestClient,
    pet_id: str,
    object_key: str,
    *,
    user: str = "ana",
    consent: bool = False,
    policy_version: str | None = TEST_POLICY_VERSION,
) -> httpx.Response:
    body: dict[str, Any] = {"pet_id": pet_id, "object_key": object_key, "image_consent": consent}
    if consent and policy_version is not None:
        body["consent_policy_version"] = policy_version
    return client.post("/api/v1/analysis", json=body, headers=auth(user))
