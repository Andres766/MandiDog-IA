"""Verificación de pertenencia de la object_key."""

import uuid

import pytest
from sqlalchemy import text

from tests.helpers import analyze, create_pet, sharp_jpeg, upload


def test_clave_de_otro_usuario_responde_igual_que_una_inexistente(client):
    pet_beto = create_pet(client, user="beto")
    key_ana = upload(client, sharp_jpeg(), user="ana")
    fake_key = f"tmp/{uuid.uuid4()}.jpg"

    stolen = analyze(client, pet_beto["id"], key_ana, user="beto")
    missing = analyze(client, pet_beto["id"], fake_key, user="beto")

    assert stolen.status_code == missing.status_code == 404
    assert stolen.json() == missing.json()
    assert stolen.json()["error"]["code"] == "upload_not_found"


def test_intento_ajeno_no_consume_la_carga_del_duenio(client, engine):
    pet_ana = create_pet(client, user="ana")
    pet_beto = create_pet(client, user="beto")
    key = upload(client, sharp_jpeg(), user="ana")

    assert analyze(client, pet_beto["id"], key, user="beto").status_code == 404
    with engine.connect() as conn:
        consumed = conn.execute(
            text("SELECT consumed_at FROM uploads WHERE object_key = :k"), {"k": key}
        ).scalar_one()
    assert consumed is None
    assert analyze(client, pet_ana["id"], key, user="ana").status_code == 201


def test_una_carga_solo_se_procesa_una_vez(client):
    pet = create_pet(client)
    key = upload(client, sharp_jpeg())

    assert analyze(client, pet["id"], key).status_code == 201
    second = analyze(client, pet["id"], key)

    assert second.status_code == 409
    assert second.json()["error"]["code"] == "upload_already_used"


def test_mascota_de_otro_usuario_no_se_puede_usar(client, engine):
    pet_beto = create_pet(client, user="beto")
    key = upload(client, sharp_jpeg(), user="ana")

    response = analyze(client, pet_beto["id"], key, user="ana")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "pet_not_found"
    with engine.connect() as conn:
        consumed = conn.execute(
            text("SELECT consumed_at FROM uploads WHERE object_key = :k"), {"k": key}
        ).scalar_one()
    assert consumed is None


@pytest.mark.parametrize(
    "bad_key",
    [
        f"permanent/{uuid.uuid4()}.jpg",
        f"tmp/../permanent/{uuid.uuid4()}.jpg",
        f"tmp/{uuid.uuid4()}.gif",
        f"{uuid.uuid4()}.jpg",
        "tmp/no-es-un-uuid.jpg",
        f"tmp/{str(uuid.uuid4()).upper()}.jpg",
    ],
    ids=["permanent", "traversal", "extension", "sin_prefijo", "no_uuid", "mayusculas"],
)
def test_formato_de_clave_invalido(client, bad_key):
    pet = create_pet(client)
    response = analyze(client, pet["id"], bad_key)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
