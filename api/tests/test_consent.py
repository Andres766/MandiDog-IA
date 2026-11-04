"""Autorización de tratamiento de datos (Ley 1581) y restricciones de la BD."""

import json
import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import IntegrityError

from tests.helpers import accept_consent, auth, create_pet, me, submit_scan


def test_usuario_nuevo_debe_aceptar_la_autorizacion(client):
    consent = me(client)["consent"]
    assert consent == {
        "current_version": "test-v1",
        "accepted_version": None,
        "accepted_at": None,
        "required": True,
    }


def test_aceptar_la_version_vigente(client):
    response = accept_consent(client)
    assert response.status_code == 200
    consent = response.json()["consent"]
    assert consent["accepted_version"] == "test-v1"
    assert consent["accepted_at"] is not None
    assert consent["required"] is False


def test_aceptar_una_version_desactualizada(client):
    response = accept_consent(client, version="2020-01-v0")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "consent_policy_outdated"
    assert me(client)["consent"]["required"] is True


def test_sin_autorizacion_no_se_registran_analisis(client, engine):
    pet = create_pet(client)
    response = submit_scan(client, pet["id"])
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "consent_required"
    with engine.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM analyses")).scalar_one() == 0


def test_cambio_de_version_exige_aceptar_de_nuevo(make_client):
    client_v1 = make_client()
    accept_consent(client_v1)
    pet = create_pet(client_v1)

    client_v2 = make_client(consent_policy_version="test-v2")
    assert me(client_v2)["consent"]["required"] is True
    assert submit_scan(client_v2, pet["id"]).status_code == 409


def test_revocar_bloquea_nuevos_analisis_y_conserva_historial(client):
    accept_consent(client)
    pet = create_pet(client)
    assert submit_scan(client, pet["id"]).status_code == 201

    assert client.delete("/api/v1/me/consent", headers=auth()).status_code == 204

    assert me(client)["consent"]["required"] is True
    assert submit_scan(client, pet["id"]).status_code == 409
    history = client.get(f"/api/v1/pets/{pet['id']}/analyses", headers=auth()).json()
    assert len(history) == 1


def test_eliminar_la_cuenta_borra_mascotas_e_historial(client, engine):
    accept_consent(client)
    pet = create_pet(client)
    submit_scan(client, pet["id"])
    create_pet(client, user="beto")

    assert client.delete("/api/v1/me", headers=auth()).status_code == 204

    with engine.connect() as conn:
        uids = conn.execute(text("SELECT firebase_uid FROM users")).scalars().all()
        assert uids == ["dev:beto"]
        assert conn.execute(text("SELECT count(*) FROM analyses")).scalar_one() == 0
        assert conn.execute(text("SELECT count(*) FROM pets")).scalar_one() == 1


def test_veterinario_con_validaciones_no_se_borra_sin_revision(client, engine):
    accept_consent(client)
    pet = create_pet(client)
    analysis_id = submit_scan(client, pet["id"]).json()["analysis_id"]
    me(client, "vet")
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO validations (analysis_id, vet_user_id, vet_assessment) "
                "SELECT :a, id, 'con_signos' FROM users WHERE firebase_uid = 'dev:vet'"
            ),
            {"a": analysis_id},
        )

    response = client.delete("/api/v1/me", headers=auth("vet"))

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "account_has_validations"


# ------------------------------------------- restricciones de la base de datos


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


VALID_ANALYSIS = {
    "risk_level": "yellow",
    "provider_status": "CAUTION",
    "part": "TOOTH",
    "sub_part": "TCENTER",
    "findings": "[]",
    "provider_result": "{}",
    "model_version": "aiforpet-scansdk-android/2.2.3",
    "recommendation": "x",
    "consent_policy_version": "v1",
}


def _insert_analysis(engine, pet_id, **overrides):
    values = {**VALID_ANALYSIS, **overrides, "pet_id": pet_id, "client_scan_id": uuid.uuid4()}
    columns = ", ".join(values)
    params = ", ".join(
        f"CAST(:{c} AS jsonb)" if c in ("findings", "provider_result") else f":{c}" for c in values
    )
    with engine.begin() as conn:
        conn.execute(text(f"INSERT INTO analyses ({columns}) VALUES ({params})"), values)


def test_fila_valida(engine, pet_id):
    _insert_analysis(engine, pet_id)


@pytest.mark.parametrize(
    ("overrides", "constraint"),
    [
        ({"risk_level": "green"}, "ck_analyses_risk_matches_status"),
        ({"provider_status": "OK"}, "ck_analyses_provider_status"),
        ({"part": "EYE"}, "ck_analyses_part"),
        ({"sub_part": "EYEL"}, "ck_analyses_sub_part"),
        ({"findings": json.dumps({"a": 1})}, "ck_analyses_findings_array"),
        ({"provider_result": "[]"}, "ck_analyses_provider_result_object"),
        ({"consent_policy_version": ""}, "ck_analyses_consent_policy_version"),
    ],
    ids=[
        "semaforo_no_coincide_con_estado",
        "estado_desconocido",
        "parte_no_dental",
        "posicion_no_dental",
        "hallazgos_no_lista",
        "resultado_no_objeto",
        "sin_version_de_autorizacion",
    ],
)
def test_la_bd_rechaza_estados_invalidos(engine, pet_id, overrides, constraint):
    with pytest.raises(IntegrityError) as exc_info:
        _insert_analysis(engine, pet_id, **overrides)
    assert exc_info.value.orig.diag.constraint_name == constraint


def test_la_bd_exige_version_y_fecha_de_autorizacion_juntas(engine, clean_state):
    with pytest.raises(IntegrityError) as exc_info, engine.begin() as conn:
        conn.execute(
            text("INSERT INTO users (firebase_uid, consent_policy_version) VALUES ('x', 'v1')")
        )
    assert exc_info.value.orig.diag.constraint_name == "ck_users_consent_complete"
