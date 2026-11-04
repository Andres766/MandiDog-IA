from app import __version__


def test_health_reporta_estado_y_version_del_modelo(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "version": __version__,
        "environment": "test",
        "model_version": "stub-1",
        "inference_backend": "stub",
        "database": "ok",
    }


def test_health_degradado_si_la_bd_no_responde(make_client):
    client = make_client(database_url="postgresql://nadie:nada@127.0.0.1:1/nada")
    response = client.get("/health")
    assert response.status_code == 503
    assert response.json()["status"] == "degraded"
    assert response.json()["database"] == "error"


def test_ruta_inexistente_usa_formato_de_error(client):
    response = client.get("/no-existe")
    assert response.status_code == 404
    assert "error" in response.json()
