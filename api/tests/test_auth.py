import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.core.auth import FirebaseAuthenticator

PROJECT = "mandidog-test"


@pytest.fixture(scope="module")
def keys():
    private = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    other = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    return private, other


def make_token(private_key, **overrides) -> str:
    now = int(time.time())
    claims = {
        "iss": f"https://securetoken.google.com/{PROJECT}",
        "aud": PROJECT,
        "sub": "firebase-uid-123",
        "iat": now,
        "exp": now + 3600,
        "auth_time": now,
        "email": "ana@example.com",
        "name": "Ana",
    }
    for key, value in overrides.items():
        if value is None:
            claims.pop(key, None)
        else:
            claims[key] = value
    return jwt.encode(claims, private_key, algorithm="RS256", headers={"kid": "k1"})


@pytest.fixture
def firebase_client(make_client, keys):
    private, _ = keys
    authenticator = FirebaseAuthenticator(
        PROJECT, signing_key_for=lambda _token: private.public_key()
    )
    return make_client(
        auth_mode="firebase", firebase_project_id=PROJECT, authenticator=authenticator
    )


def bearer(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_token_valido_crea_el_usuario(firebase_client, keys):
    response = firebase_client.get("/api/v1/me", headers=bearer(make_token(keys[0])))
    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "ana@example.com"
    assert body["role"] == "owner"


def test_mismo_token_no_duplica_el_usuario(firebase_client, keys):
    token = make_token(keys[0])
    first = firebase_client.get("/api/v1/me", headers=bearer(token)).json()
    second = firebase_client.get("/api/v1/me", headers=bearer(token)).json()
    assert first["id"] == second["id"]


def test_sin_token_responde_401(firebase_client):
    response = firebase_client.get("/api/v1/me")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "missing_credentials"


def test_header_dev_se_ignora_en_modo_firebase(firebase_client):
    response = firebase_client.get("/api/v1/me", headers={"X-Dev-User": "ana"})
    assert response.status_code == 401


@pytest.mark.parametrize(
    "overrides",
    [
        {"aud": "otro-proyecto"},
        {"iss": "https://securetoken.google.com/otro-proyecto"},
        {"exp": int(time.time()) - 3600, "iat": int(time.time()) - 7200},
        {"auth_time": int(time.time()) + 3600},
        {"sub": ""},
        {"auth_time": None},
    ],
    ids=["audiencia", "emisor", "vencido", "auth_time_futuro", "sub_vacio", "sin_auth_time"],
)
def test_token_invalido_responde_401(firebase_client, keys, overrides):
    response = firebase_client.get("/api/v1/me", headers=bearer(make_token(keys[0], **overrides)))
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_token"


def test_token_firmado_con_otra_llave_responde_401(firebase_client, keys):
    response = firebase_client.get("/api/v1/me", headers=bearer(make_token(keys[1])))
    assert response.status_code == 401


@pytest.mark.parametrize("value", [None, "", "con espacio", "a" * 65, "ana/../x"])
def test_modo_dev_exige_header_valido(client, value):
    headers = {} if value is None else {"X-Dev-User": value}
    response = client.get("/api/v1/me", headers=headers)
    assert response.status_code == 401


def test_modo_dev_usa_prefijo_para_no_chocar_con_firebase(client, engine):
    from sqlalchemy import text

    assert client.get("/api/v1/me", headers={"X-Dev-User": "ana"}).status_code == 200
    with engine.connect() as conn:
        uid = conn.execute(text("SELECT firebase_uid FROM users")).scalar_one()
    assert uid == "dev:ana"
