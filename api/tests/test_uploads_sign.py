import re
from datetime import UTC, datetime, timedelta
from urllib.parse import parse_qs, urlparse

import pytest
from sqlalchemy import text

from tests.conftest import list_keys
from tests.helpers import auth, put_signed, sharp_jpeg, sharp_png, sign

KEY_RE = re.compile(r"^tmp/[0-9a-f-]{36}\.(jpg|png)$")


def test_firmar_requiere_usuario_autenticado(client):
    response = client.post(
        "/api/v1/uploads/sign", json={"content_type": "image/jpeg", "content_length": 100}
    )
    assert response.status_code == 401


def test_firma_devuelve_url_clave_y_vencimiento(client, engine):
    data = sharp_jpeg()
    before = datetime.now(UTC)
    body = sign(client, data)

    assert KEY_RE.match(body["object_key"])
    assert body["object_key"].endswith(".jpg")
    assert body["method"] == "PUT"
    assert body["headers"] == {"Content-Type": "image/jpeg"}

    expires_at = datetime.fromisoformat(body["expires_at"])
    assert timedelta(seconds=295) <= expires_at - before <= timedelta(seconds=305)

    query = parse_qs(urlparse(body["upload_url"]).query)
    assert query["X-Amz-Expires"] == ["300"]
    signed_headers = query["X-Amz-SignedHeaders"][0].split(";")
    assert "content-length" in signed_headers
    assert "content-type" in signed_headers

    with engine.connect() as conn:
        row = conn.execute(
            text(
                "SELECT u.firebase_uid, up.content_type, up.content_length, up.consumed_at "
                "FROM uploads up JOIN users u ON u.id = up.user_id WHERE up.object_key = :k"
            ),
            {"k": body["object_key"]},
        ).one()
    assert row.firebase_uid == "dev:ana"
    assert row.content_type == "image/jpeg"
    assert row.content_length == len(data)
    assert row.consumed_at is None


def test_firma_png_usa_extension_png(client):
    assert sign(client, sharp_png(), content_type="image/png")["object_key"].endswith(".png")


@pytest.mark.parametrize(
    ("payload", "code"),
    [
        ({"content_type": "image/gif", "content_length": 100}, "validation_error"),
        ({"content_type": "image/jpeg", "content_length": 0}, "validation_error"),
        ({"content_type": "image/jpeg", "content_length": 10 * 1024 * 1024 + 1}, "file_too_large"),
    ],
    ids=["tipo_no_permitido", "tamano_cero", "mas_de_10MB"],
)
def test_firma_rechaza_tipo_o_tamano_invalido(client, payload, code):
    response = client.post("/api/v1/uploads/sign", json=payload, headers=auth())
    assert response.status_code == 422
    assert response.json()["error"]["code"] == code


def test_put_firmado_acepta_el_archivo_autorizado(client, s3, bucket):
    data = sharp_jpeg()
    signed = sign(client, data)
    assert put_signed(signed, data).status_code == 200

    head = s3.head_object(Bucket=bucket, Key=signed["object_key"])
    assert head["ContentLength"] == len(data)
    assert head["ContentType"] == "image/jpeg"


def test_put_con_otro_tamano_es_rechazado_por_la_firma(client, s3, bucket):
    data = sharp_jpeg()
    signed = sign(client, data, content_length=len(data) - 10)
    response = put_signed(signed, data)
    assert response.status_code == 403
    assert list_keys(s3, bucket) == []


def test_put_con_otro_content_type_es_rechazado_por_la_firma(client, s3, bucket):
    data = sharp_jpeg()
    signed = sign(client, data)
    response = put_signed(signed, data, headers={"Content-Type": "image/png"})
    assert response.status_code == 403
    assert list_keys(s3, bucket) == []
