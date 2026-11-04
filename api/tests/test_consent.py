"""Consentimiento: restricciones de la BD (defensa ante bugs de la API) y revocación."""

import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from tests.conftest import list_keys
from tests.helpers import analyze, auth, create_pet, sharp_jpeg, upload

VALID_ANALYSIS = {
    "risk_level": "green",
    "confidence": 0.9,
    "probability_signs": 0.1,
    "model_version": "stub-1",
    "recommendation": "x",
    "blur_variance": 100.0,
    "luminance": 120.0,
    "image_width": 640,
    "image_height": 480,
    "inference_ms": 5,
    "image_consent": False,
    "consent_at": None,
    "consent_policy_version": None,
    "consent_revoked_at": None,
    "image_key": None,
}


@pytest.fixture
def pet_id(engine, clean_state):
    with engine.begin() as conn:
        user_id = conn.execute(
            text("INSERT INTO users (firebase_uid) VALUES ('dev:sql') RETURNING id")
        ).scalar_one()
        return conn.execute(
            text("INSERT INTO pets (owner_id, name) VALUES (:u, 'Toby') RETURNING id"),
            {"u": user_id},
        ).scalar_one()


def _insert_analysis(engine, pet_id, **overrides):
    values = {**VALID_ANALYSIS, **overrides, "pet_id": pet_id}
    columns = ", ".join(values)
    params = ", ".join(f":{c}" for c in values)
    with engine.begin() as conn:
        conn.execute(text(f"INSERT INTO analyses ({columns}) VALUES ({params})"), values)


def test_fila_valida_sin_consentimiento(engine, pet_id):
    _insert_analysis(engine, pet_id)


def test_fila_valida_con_consentimiento(engine, pet_id):
    _insert_analysis(
        engine,
        pet_id,
        image_consent=True,
        consent_at="2026-11-04T10:00:00Z",
        consent_policy_version="v1",
        image_key=f"permanent/{uuid.uuid4()}.jpg",
    )


@pytest.mark.parametrize(
    ("overrides", "constraint"),
    [
        (
            {"image_key": "permanent/x.jpg"},
            "ck_analyses_image_key_requires_consent",
        ),
        (
            # Viola dos CHECK; Postgres reporta el primero en orden alfabético.
            {"image_consent": True, "consent_policy_version": "v1", "image_key": "permanent/x.jpg"},
            "ck_analyses_consent_complete",
        ),
        (
            {"image_consent": True, "consent_at": "2026-11-04T10:00:00Z"},
            "ck_analyses_consent_complete",
        ),
        (
            {
                "image_consent": True,
                "consent_at": "2026-11-04T10:00:00Z",
                "consent_policy_version": "v1",
                "image_key": "tmp/x.jpg",
            },
            "ck_analyses_image_key_permanent",
        ),
        (
            {
                "image_consent": True,
                "consent_at": "2026-11-04T10:00:00Z",
                "consent_policy_version": "v1",
                "consent_revoked_at": "2026-11-05T10:00:00Z",
                "image_key": "permanent/x.jpg",
            },
            "ck_analyses_revoked_has_no_image",
        ),
        ({"confidence": 1.5}, "ck_analyses_confidence"),
    ],
    ids=[
        "imagen_sin_consentimiento",
        "consentimiento_sin_fecha",
        "consentimiento_sin_version",
        "imagen_fuera_de_permanent",
        "revocado_con_imagen",
        "confianza_mayor_a_1",
    ],
)
def test_la_bd_rechaza_estados_invalidos(engine, pet_id, overrides, constraint):
    with pytest.raises(IntegrityError) as exc_info:
        _insert_analysis(engine, pet_id, **overrides)
    assert exc_info.value.orig.diag.constraint_name == constraint


def test_revocar_borra_la_foto_y_deja_constancia(client, engine, s3, bucket):
    pet = create_pet(client)
    analysis_id = analyze(client, pet["id"], upload(client, sharp_jpeg()), consent=True).json()[
        "analysis_id"
    ]
    assert list_keys(s3, bucket, "permanent/")

    response = client.delete(f"/api/v1/analyses/{analysis_id}/image", headers=auth())

    assert response.status_code == 204
    assert list_keys(s3, bucket) == []
    with engine.connect() as conn:
        row = (
            conn.execute(
                text("SELECT image_key, consent_revoked_at FROM analyses WHERE id = :id"),
                {"id": analysis_id},
            )
            .mappings()
            .one()
        )
    assert row["image_key"] is None
    assert row["consent_revoked_at"] is not None

    history = client.get(f"/api/v1/pets/{pet['id']}/analyses", headers=auth()).json()
    assert history[0]["has_image"] is False

    # Idempotente
    again = client.delete(f"/api/v1/analyses/{analysis_id}/image", headers=auth())
    assert again.status_code == 204


def test_revocar_sin_consentimiento_previo_no_registra_revocacion(client, engine):
    pet = create_pet(client)
    analysis_id = analyze(client, pet["id"], upload(client, sharp_jpeg())).json()["analysis_id"]

    assert client.delete(f"/api/v1/analyses/{analysis_id}/image", headers=auth()).status_code == 204
    with engine.connect() as conn:
        revoked = conn.execute(
            text("SELECT consent_revoked_at FROM analyses WHERE id = :id"), {"id": analysis_id}
        ).scalar_one()
    assert revoked is None


def test_no_se_puede_revocar_un_analisis_ajeno(client, s3, bucket):
    pet = create_pet(client, user="ana")
    analysis_id = analyze(client, pet["id"], upload(client, sharp_jpeg()), consent=True).json()[
        "analysis_id"
    ]

    response = client.delete(f"/api/v1/analyses/{analysis_id}/image", headers=auth("beto"))

    assert response.status_code == 404
    assert list_keys(s3, bucket, "permanent/") == [f"permanent/{analysis_id}.jpg"]
