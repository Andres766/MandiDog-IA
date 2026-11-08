"""Validación clínica ciega."""

import pytest
from sqlalchemy import text

from app.cli import main as cli_main
from app.services.validation_service import cephalic_group
from tests.helpers import auth, create_pet, me, ready_owner, submit_scan, tooth_result


def make_vet(client, engine, user="vet"):
    me(client, user)
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE users SET role = 'vet' WHERE firebase_uid = :uid"),
            {"uid": f"dev:{user}"},
        )


def scan(client, pet, status="WARNING", user="ana"):
    return submit_scan(client, pet["id"], tooth_result(status), user=user).json()["analysis_id"]


def validate(client, analysis_id, assessment, user="vet"):
    return client.post(
        f"/api/v1/analyses/{analysis_id}/validation",
        json={"vet_assessment": assessment, "notes": "Revisado en consulta"},
        headers=auth(user),
    )


def test_solo_veterinarios(client):
    _, pet = ready_owner(client)
    analysis_id = scan(client, pet)
    for response in (
        client.get("/api/v1/validations/pending", headers=auth()),
        client.get("/api/v1/validations/summary", headers=auth()),
        validate(client, analysis_id, "con_signos", user="ana"),
    ):
        assert response.status_code == 403
        assert response.json()["error"]["code"] == "vet_only"


def test_los_casos_pendientes_no_revelan_el_resultado(client, engine):
    _, pet = ready_owner(client)
    analysis_id = scan(client, pet, "WARNING")
    make_vet(client, engine)

    pending = client.get("/api/v1/validations/pending", headers=auth("vet")).json()

    assert [c["analysis_id"] for c in pending] == [analysis_id]
    case = pending[0]
    assert case["pet_name"] == "Toby"
    assert case["sub_part"] == "TCENTER"
    for leaked in ("risk_level", "provider_status", "findings", "recommendation"):
        assert leaked not in case
    # Solo recortes: los mapas de calor delatarían la predicción.
    assert case["photo_urls"] == [
        "https://example.invalid/inflammation-crop.jpg",
        "https://example.invalid/calculus-crop.jpg",
    ]


def test_valorar_revela_la_ia_y_saca_el_caso_de_pendientes(client, engine):
    _, pet = ready_owner(client)
    analysis_id = scan(client, pet, "WARNING")
    make_vet(client, engine)

    response = validate(client, analysis_id, "sin_signos")

    assert response.status_code == 201
    body = response.json()
    assert body["ai_risk_level"] == "red"
    assert body["ai_sees_signs"] is True
    assert body["agreement"] is False
    assert client.get("/api/v1/validations/pending", headers=auth("vet")).json() == []


def test_cada_veterinario_valora_un_caso_una_sola_vez(client, engine):
    _, pet = ready_owner(client)
    analysis_id = scan(client, pet)
    make_vet(client, engine)
    make_vet(client, engine, "vet2")

    assert validate(client, analysis_id, "con_signos").status_code == 201
    again = validate(client, analysis_id, "sin_signos")
    assert again.status_code == 409
    assert again.json()["error"]["code"] == "already_validated"
    # Otro veterinario sí puede valorar el mismo caso.
    assert validate(client, analysis_id, "con_signos", user="vet2").status_code == 201


def test_caso_inexistente(client, engine):
    make_vet(client, engine)
    response = validate(client, "00000000-0000-4000-8000-000000000999", "con_signos")
    assert response.status_code == 404


def test_resumen_de_concordancia(client, engine):
    _, pug = ready_owner(client)
    client.patch(f"/api/v1/pets/{pug['id']}", json={"breed": "Pug"}, headers=auth())
    criollo = create_pet(client, name="Max")
    client.patch(f"/api/v1/pets/{criollo['id']}", json={"breed": "Criollo"}, headers=auth())
    make_vet(client, engine)

    # pug: IA con signos / vet con signos (VP) y IA normal / vet con signos (FN)
    validate(client, scan(client, pug, "WARNING"), "con_signos")
    validate(client, scan(client, pug, "NORMAL"), "con_signos")
    # criollo: IA normal / vet sin signos (VN), IA con signos / vet sin signos (FP)
    validate(client, scan(client, criollo, "NORMAL"), "sin_signos")
    validate(client, scan(client, criollo, "CAUTION"), "sin_signos")
    # no evaluable: no entra en la matriz
    validate(client, scan(client, criollo, "WARNING"), "no_evaluable")

    summary = client.get("/api/v1/validations/summary", headers=auth("vet")).json()

    assert summary["validations"] == 5
    assert summary["not_evaluable"] == 1
    assert summary["overall"] == {
        "n": 4,
        "true_positive": 1,
        "false_positive": 1,
        "false_negative": 1,
        "true_negative": 1,
        "sensitivity": 0.5,
        "specificity": 0.5,
        "accuracy": 0.5,
    }
    groups = summary["by_cephalic_group"]
    assert groups["Braquicéfalo"]["n"] == 2
    assert groups["Braquicéfalo"]["sensitivity"] == 0.5
    assert groups["Braquicéfalo"]["specificity"] is None
    assert groups["No braquicéfalo o sin clasificar"]["specificity"] == 0.5
    assert set(summary["by_breed"]) == {"Pug", "Criollo"}


@pytest.mark.parametrize(
    ("breed", "group"),
    [
        ("Pug", "Braquicéfalo"),
        ("bulldog francés", "Braquicéfalo"),
        ("Shih Tzu", "Braquicéfalo"),
        ("Pekinés", "Braquicéfalo"),
        ("Golden retriever", "No braquicéfalo o sin clasificar"),
        (None, "Sin raza registrada"),
        ("  ", "Sin raza registrada"),
    ],
)
def test_biotipo_cefalico_por_raza(breed, group):
    assert cephalic_group(breed) == group


def test_cli_asigna_el_rol_de_veterinario(client, engine, monkeypatch, settings_factory):
    me(client, "vet")
    monkeypatch.setenv("DATABASE_URL", settings_factory().database_url)
    from app.core.config import get_settings

    get_settings.cache_clear()
    try:
        assert cli_main(["set-role", "--uid", "dev:vet", "--role", "vet"]) == 0
        assert cli_main(["set-role", "--uid", "dev:nadie", "--role", "vet"]) == 1
    finally:
        get_settings.cache_clear()
    with engine.connect() as conn:
        role = conn.execute(
            text("SELECT role FROM users WHERE firebase_uid = 'dev:vet'")
        ).scalar_one()
    assert role == "vet"
