import time

import pytest
from sqlalchemy import text

from tests.conftest import list_keys
from tests.helpers import (
    analyze,
    blurry_jpeg,
    bright_jpeg,
    create_pet,
    dark_jpeg,
    put_signed,
    sharp_jpeg,
    sharp_png,
    sign,
    small_jpeg,
    upload,
)


def _analysis_row(engine, analysis_id):
    with engine.connect() as conn:
        return (
            conn.execute(text("SELECT * FROM analyses WHERE id = :id"), {"id": analysis_id})
            .mappings()
            .one()
        )


def _consumed_at(engine, key):
    with engine.connect() as conn:
        return conn.execute(
            text("SELECT consumed_at FROM uploads WHERE object_key = :k"), {"k": key}
        ).scalar_one()


def test_flujo_completo_sin_consentimiento(client, engine, s3, bucket):
    pet = create_pet(client)
    key = upload(client, sharp_jpeg())

    started = time.perf_counter()
    response = analyze(client, pet["id"], key, consent=False)
    elapsed = time.perf_counter() - started

    assert response.status_code == 201, response.text
    body = response.json()
    assert set(body) == {
        "analysis_id",
        "risk_level",
        "confidence",
        "model_version",
        "recommendation",
        "created_at",
    }
    assert body["risk_level"] == "green"
    assert body["confidence"] == pytest.approx(0.85)
    assert body["model_version"] == "stub-1"
    assert "veterinario" in body["recommendation"]
    assert elapsed < 10

    # image_consent=false: el temporal se borra y no se conserva nada.
    assert list_keys(s3, bucket) == []
    row = _analysis_row(engine, body["analysis_id"])
    assert row["image_consent"] is False
    assert row["image_key"] is None
    assert row["consent_at"] is None
    assert row["consent_policy_version"] is None
    assert float(row["probability_signs"]) == pytest.approx(0.15)
    assert row["image_width"] == 640 and row["image_height"] == 480
    assert row["blur_variance"] > 60
    assert row["inference_ms"] >= 0
    assert _consumed_at(engine, key) is not None


def test_flujo_completo_con_consentimiento_copia_a_permanent(client, engine, s3, bucket):
    pet = create_pet(client)
    key = upload(client, sharp_jpeg())

    response = analyze(client, pet["id"], key, consent=True)

    assert response.status_code == 201, response.text
    analysis_id = response.json()["analysis_id"]
    assert list_keys(s3, bucket) == [f"permanent/{analysis_id}.jpg"]
    row = _analysis_row(engine, analysis_id)
    assert row["image_consent"] is True
    assert row["image_key"] == f"permanent/{analysis_id}.jpg"
    assert row["consent_at"] is not None
    assert row["consent_policy_version"] == "test-v1"


def test_png_con_consentimiento_conserva_extension(client, s3, bucket):
    pet = create_pet(client)
    key = upload(client, sharp_png(), content_type="image/png")
    response = analyze(client, pet["id"], key, consent=True)
    assert response.status_code == 201, response.text
    assert list_keys(s3, bucket) == [f"permanent/{response.json()['analysis_id']}.png"]


@pytest.mark.parametrize(
    ("probability", "level"),
    [(0.15, "green"), (0.45, "yellow"), (0.75, "red")],
)
def test_nivel_de_riesgo_segun_probabilidad(make_client, probability, level):
    client = make_client(probability=probability)
    pet = create_pet(client)
    response = analyze(client, pet["id"], upload(client, sharp_jpeg()))
    assert response.status_code == 201
    assert response.json()["risk_level"] == level
    assert "consulta siempre a tu veterinario" in response.json()["recommendation"]


@pytest.mark.parametrize(
    ("image", "expected_code"),
    [
        (blurry_jpeg, "blurry"),
        (dark_jpeg, "too_dark"),
        (bright_jpeg, "too_bright"),
        (small_jpeg, "too_small"),
    ],
)
def test_calidad_insuficiente_rechaza_y_borra_el_temporal(
    client, engine, s3, bucket, image, expected_code
):
    pet = create_pet(client)
    key = upload(client, image())

    response = analyze(client, pet["id"], key, consent=True)

    assert response.status_code == 422
    error = response.json()["error"]
    assert error["code"] == "image_quality"
    codes = [issue["code"] for issue in error["details"]]
    assert expected_code in codes
    assert all(issue["message"] for issue in error["details"])
    assert list_keys(s3, bucket) == []
    with engine.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM analyses")).scalar_one() == 0
    assert _consumed_at(engine, key) is not None


def test_archivo_que_no_corresponde_al_tipo_declarado(client, s3, bucket):
    """Firma y PUT como JPEG, pero el contenido real es PNG."""
    pet = create_pet(client)
    data = sharp_png()
    signed = sign(client, data, content_type="image/jpeg")
    assert put_signed(signed, data).status_code == 200

    response = analyze(client, pet["id"], signed["object_key"])

    assert response.status_code == 422
    assert response.json()["error"]["details"][0]["code"] == "format_mismatch"
    assert list_keys(s3, bucket) == []


def test_objeto_que_no_coincide_con_lo_firmado_se_rechaza(client, engine, s3, bucket):
    """head_object detecta un objeto con otro tamaño antes de descargarlo."""
    pet = create_pet(client)
    data = sharp_jpeg()
    signed = sign(client, data)
    s3.put_object(
        Bucket=bucket, Key=signed["object_key"], Body=data + b"extra", ContentType="image/jpeg"
    )

    response = analyze(client, pet["id"], signed["object_key"])

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "upload_mismatch"
    assert list_keys(s3, bucket) == []
    assert _consumed_at(engine, signed["object_key"]) is not None


def test_si_la_foto_no_se_subio_la_carga_queda_disponible(client, engine):
    pet = create_pet(client)
    data = sharp_jpeg()
    signed = sign(client, data)

    response = analyze(client, pet["id"], signed["object_key"])
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "upload_missing"
    assert _consumed_at(engine, signed["object_key"]) is None

    # La app reintenta el PUT y vuelve a notificar.
    assert put_signed(signed, data).status_code == 200
    assert analyze(client, pet["id"], signed["object_key"]).status_code == 201


def test_politica_de_consentimiento_desactualizada(client, engine, s3, bucket):
    pet = create_pet(client)
    key = upload(client, sharp_jpeg())

    response = analyze(client, pet["id"], key, consent=True, policy_version="2020-01-v0")

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "consent_policy_outdated"
    assert _consumed_at(engine, key) is None
    assert list_keys(s3, bucket) == [key]


def test_consentimiento_sin_version_de_politica_es_invalido(client):
    pet = create_pet(client)
    key = upload(client, sharp_jpeg())
    response = analyze(client, pet["id"], key, consent=True, policy_version=None)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
