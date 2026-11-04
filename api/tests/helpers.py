"""Resultados de ejemplo del SDK de AI for Pet y atajos para el flujo de la app."""

import copy
import uuid
from typing import Any

from fastapi.testclient import TestClient
from httpx2 import Response

from tests.conftest import TEST_POLICY_VERSION

# Basado en el ejemplo oficial sdk-callback-single.json (escaneo de dientes).
OFFICIAL_TOOTH_RESULT: dict[str, Any] = {
    "status": "SUCCESS",
    "petType": "DOG",
    "part": "TOOTH",
    "subPart": "TCENTER",
    "createdAt": 1781485248231,
    "response": {
        "status": "CAUTION",
        "title": "Observation is recommended.",
        "symptoms": [
            {
                "code": "inflammation",
                "name": "Inflammation",
                "abnormLevel": 1,
                "isAbnormal": True,
                "resultLabel": "abnormal",
                "cropImageUrl": "https://example.invalid/inflammation-crop.jpg",
                "heatmapUrl": "https://example.invalid/inflammation.jpg",
            },
            {
                "code": "calculus",
                "name": "Tartar",
                "abnormLevel": 0,
                "isAbnormal": False,
                "resultLabel": "normal",
                "cropImageUrl": "https://example.invalid/calculus-crop.jpg",
                "heatmapUrl": "https://example.invalid/calculus.jpg",
            },
        ],
    },
}


def auth(user: str = "ana") -> dict[str, str]:
    return {"X-Dev-User": user}


def tooth_result(response_status: str = "CAUTION", **root: Any) -> dict[str, Any]:
    """Copia del ejemplo oficial con otro `response.status`; `root` cambia campos de la raíz."""
    result = copy.deepcopy(OFFICIAL_TOOTH_RESULT)
    result["response"]["status"] = response_status
    result.update(root)
    return result


def me(client: TestClient, user: str = "ana") -> dict[str, Any]:
    response = client.get("/api/v1/me", headers=auth(user))
    assert response.status_code == 200, response.text
    return response.json()


def accept_consent(
    client: TestClient, user: str = "ana", version: str = TEST_POLICY_VERSION
) -> Response:
    return client.put("/api/v1/me/consent", json={"policy_version": version}, headers=auth(user))


def create_pet(client: TestClient, user: str = "ana", name: str = "Toby") -> dict[str, Any]:
    response = client.post("/api/v1/pets", json={"name": name}, headers=auth(user))
    assert response.status_code == 201, response.text
    return response.json()


def ready_owner(client: TestClient, user: str = "ana") -> tuple[dict[str, Any], dict[str, Any]]:
    """Usuario con autorización aceptada y una mascota: lo que la app tiene antes de escanear."""
    assert accept_consent(client, user).status_code == 200
    return me(client, user), create_pet(client, user)


def submit_scan(
    client: TestClient,
    pet_id: str,
    result: dict[str, Any] | None = None,
    *,
    user: str = "ana",
    client_scan_id: str | None = None,
) -> Response:
    return client.post(
        "/api/v1/analysis",
        json={
            "pet_id": pet_id,
            "client_scan_id": client_scan_id or str(uuid.uuid4()),
            "sdk_platform": "android",
            "sdk_version": "2.2.3",
            "result": result if result is not None else tooth_result(),
        },
        headers=auth(user),
    )
