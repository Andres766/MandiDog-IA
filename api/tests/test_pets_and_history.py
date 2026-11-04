from datetime import date, timedelta

import pytest
from sqlalchemy import text

from tests.helpers import auth, create_pet, ready_owner, submit_scan, tooth_result


def test_crear_mascota(client):
    response = client.post(
        "/api/v1/pets",
        json={
            "name": "  Luna ",
            "breed": "Bulldog francés",
            "sex": "female",
            "birth_date": "2021-05-10",
            "weight_kg": 11.5,
        },
        headers=auth(),
    )
    assert response.status_code == 201
    body = response.json()
    assert body["name"] == "Luna"
    assert body["sex"] == "female"
    assert body["weight_kg"] == 11.5
    assert body["birth_date"] == "2021-05-10"


@pytest.mark.parametrize(
    "payload",
    [
        {"name": ""},
        {"name": "Toby", "weight_kg": 0},
        {"name": "Toby", "weight_kg": 150},
        {"name": "Toby", "sex": "macho"},
        {"name": "Toby", "birth_date": (date.today() + timedelta(days=1)).isoformat()},
    ],
    ids=["nombre_vacio", "peso_cero", "peso_excesivo", "sexo_invalido", "nacimiento_futuro"],
)
def test_crear_mascota_con_datos_invalidos(client, payload):
    response = client.post("/api/v1/pets", json=payload, headers=auth())
    assert response.status_code == 422


def test_cada_usuario_solo_ve_sus_mascotas(client):
    create_pet(client, user="ana", name="Toby")
    create_pet(client, user="beto", name="Max")

    names = [p["name"] for p in client.get("/api/v1/pets", headers=auth("ana")).json()]
    assert names == ["Toby"]


def test_mascota_ajena_responde_404(client):
    pet = create_pet(client, user="beto")
    assert client.get(f"/api/v1/pets/{pet['id']}", headers=auth("ana")).status_code == 404
    assert (
        client.patch(f"/api/v1/pets/{pet['id']}", json={"name": "X"}, headers=auth("ana"))
    ).status_code == 404
    assert client.delete(f"/api/v1/pets/{pet['id']}", headers=auth("ana")).status_code == 404


def test_actualizar_mascota_parcialmente(client):
    pet = create_pet(client)
    response = client.patch(f"/api/v1/pets/{pet['id']}", json={"weight_kg": 20}, headers=auth())
    assert response.status_code == 200
    assert response.json()["weight_kg"] == 20
    assert response.json()["name"] == "Toby"

    null_name = client.patch(f"/api/v1/pets/{pet['id']}", json={"name": None}, headers=auth())
    assert null_name.status_code == 422


def test_borrar_mascota_borra_su_historial(client, engine):
    _, pet = ready_owner(client)
    submit_scan(client, pet["id"])
    submit_scan(client, pet["id"])

    response = client.delete(f"/api/v1/pets/{pet['id']}", headers=auth())

    assert response.status_code == 204
    with engine.connect() as conn:
        assert conn.execute(text("SELECT count(*) FROM analyses")).scalar_one() == 0
    assert client.get(f"/api/v1/pets/{pet['id']}", headers=auth()).status_code == 404


def test_historial_ordenado_del_mas_reciente_al_mas_antiguo(client):
    _, pet = ready_owner(client)
    ids = [
        submit_scan(client, pet["id"], tooth_result(status)).json()["analysis_id"]
        for status in ("NORMAL", "CAUTION", "WARNING")
    ]

    history = client.get(f"/api/v1/pets/{pet['id']}/analyses", headers=auth()).json()

    assert [h["analysis_id"] for h in history] == list(reversed(ids))
    assert [h["risk_level"] for h in history] == ["red", "yellow", "green"]
    assert all(h["findings"] for h in history)
    assert all("veterinario" in h["recommendation"] for h in history)

    page = client.get(
        f"/api/v1/pets/{pet['id']}/analyses", params={"limit": 1, "offset": 1}, headers=auth()
    ).json()
    assert [h["analysis_id"] for h in page] == [ids[1]]


def test_historial_de_mascota_ajena_responde_404(client):
    pet = create_pet(client, user="beto")
    response = client.get(f"/api/v1/pets/{pet['id']}/analyses", headers=auth("ana"))
    assert response.status_code == 404


def test_historial_vacio(client):
    pet = create_pet(client)
    assert client.get(f"/api/v1/pets/{pet['id']}/analyses", headers=auth()).json() == []


def test_lista_de_mascotas_trae_el_ultimo_resultado(client):
    _, toby = ready_owner(client)
    max_ = create_pet(client, name="Max")
    submit_scan(client, toby["id"], tooth_result("NORMAL"))
    submit_scan(client, toby["id"], tooth_result("WARNING"))

    pets = {p["name"]: p for p in client.get("/api/v1/pets", headers=auth()).json()}

    assert pets["Toby"]["last_analysis"]["risk_level"] == "red"
    assert pets["Max"]["last_analysis"] is None
    single = client.get(f"/api/v1/pets/{max_['id']}", headers=auth()).json()
    assert single["last_analysis"] is None
