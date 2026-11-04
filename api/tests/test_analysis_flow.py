import uuid

import pytest
from sqlalchemy import text

from tests.helpers import auth, create_pet, ready_owner, submit_scan, tooth_result


def _row(engine, analysis_id):
    with engine.connect() as conn:
        return (
            conn.execute(text("SELECT * FROM analyses WHERE id = :id"), {"id": analysis_id})
            .mappings()
            .one()
        )


def test_registra_el_resultado_oficial_de_ejemplo(client, engine):
    user, pet = ready_owner(client)
    result = tooth_result("CAUTION", userId=user["id"], petId=pet["id"])

    response = submit_scan(client, pet["id"], result)

    assert response.status_code == 201, response.text
    body = response.json()
    assert body["risk_level"] == "yellow"
    assert body["provider_status"] == "CAUTION"
    assert body["sub_part"] == "TCENTER"
    assert body["model_version"] == "aiforpet-scansdk-android/2.2.3"
    assert body["findings"] == [
        {"code": "inflammation", "name": "Inflamación de encías", "status": "abnormal"},
        {"code": "calculus", "name": "Sarro (cálculo dental)", "status": "normal"},
    ]
    assert "consulta siempre a tu veterinario" in body["recommendation"]

    row = _row(engine, body["analysis_id"])
    assert row["provider_result"] == result  # JSON original intacto, para auditoría
    assert row["consent_policy_version"] == "test-v1"
    assert row["provider_analyzed_at"].year == 2026
    assert row["part"] == "TOOTH"


@pytest.mark.parametrize(
    ("status", "level"), [("NORMAL", "green"), ("CAUTION", "yellow"), ("WARNING", "red")]
)
def test_semaforo_segun_estado_de_aiforpet(client, status, level):
    _, pet = ready_owner(client)
    response = submit_scan(client, pet["id"], tooth_result(status))
    assert response.status_code == 201
    assert response.json()["risk_level"] == level
    assert "consulta siempre a tu veterinario" in response.json()["recommendation"]


def test_reintento_con_el_mismo_escaneo_no_duplica(client, engine):
    _, pet = ready_owner(client)
    scan_id = str(uuid.uuid4())

    first = submit_scan(client, pet["id"], client_scan_id=scan_id)
    retry = submit_scan(client, pet["id"], client_scan_id=scan_id)

    assert first.status_code == 201
    assert retry.status_code == 200
    assert retry.json() == first.json()
    with engine.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM analyses")).scalar_one() == 1


def test_escaneo_de_otro_usuario_no_se_puede_reutilizar(client):
    _, pet_ana = ready_owner(client, "ana")
    _, pet_beto = ready_owner(client, "beto")
    scan_id = str(uuid.uuid4())
    assert submit_scan(client, pet_ana["id"], client_scan_id=scan_id).status_code == 201

    response = submit_scan(client, pet_beto["id"], user="beto", client_scan_id=scan_id)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "scan_id_conflict"


def test_mismo_escaneo_con_otra_mascota_es_conflicto(client):
    _, pet = ready_owner(client)
    other = create_pet(client, name="Max")
    scan_id = str(uuid.uuid4())
    assert submit_scan(client, pet["id"], client_scan_id=scan_id).status_code == 201

    response = submit_scan(client, other["id"], client_scan_id=scan_id)
    assert response.status_code == 409


def test_mascota_ajena_responde_404(client):
    ready_owner(client, "ana")
    pet_beto = create_pet(client, user="beto")
    response = submit_scan(client, pet_beto["id"], user="ana")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "pet_not_found"


@pytest.mark.parametrize("field", ["userId", "petId"])
@pytest.mark.parametrize("value", [lambda: str(uuid.uuid4()), lambda: "no-es-un-uuid"])
def test_resultado_de_otro_usuario_o_mascota_se_rechaza(client, field, value):
    _, pet = ready_owner(client)
    response = submit_scan(client, pet["id"], tooth_result(**{field: value()}))
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "scan_result_mismatch"


@pytest.mark.parametrize(
    "result",
    [
        tooth_result(status="FAIL"),
        tooth_result(part="EYE"),
        tooth_result(petType="CAT"),
        tooth_result(subPart="EYEL"),
        tooth_result("DESCONOCIDO"),
        {"status": "SUCCESS", "petType": "DOG", "part": "TOOTH"},
        {},
    ],
    ids=[
        "no_success",
        "parte_ojo",
        "gato",
        "posicion_de_ojo",
        "estado_desconocido",
        "sin_response",
        "vacio",
    ],
)
def test_resultado_que_no_es_un_escaneo_dental_valido(client, result):
    _, pet = ready_owner(client)
    response = submit_scan(client, pet["id"], result)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "scan_result_invalid"
    assert response.json()["error"]["details"]


def test_resultado_demasiado_grande(client):
    _, pet = ready_owner(client)
    result = tooth_result(relleno="x" * 70_000)
    response = submit_scan(client, pet["id"], result)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "scan_result_invalid"


def test_campos_nuevos_de_aiforpet_se_aceptan_y_se_guardan(client, engine):
    _, pet = ready_owner(client)
    result = tooth_result(campoNuevo={"version": 3})
    response = submit_scan(client, pet["id"], result)
    assert response.status_code == 201
    assert _row(engine, response.json()["analysis_id"])["provider_result"]["campoNuevo"] == {
        "version": 3
    }


def test_version_del_sdk_con_formato_invalido(client):
    _, pet = ready_owner(client)
    response = client.post(
        "/api/v1/analysis",
        json={
            "pet_id": pet["id"],
            "client_scan_id": str(uuid.uuid4()),
            "sdk_platform": "android",
            "sdk_version": "latest; DROP TABLE",
            "result": tooth_result(),
        },
        headers=auth(),
    )
    assert response.status_code == 422
