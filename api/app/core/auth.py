"""Autenticación: Firebase (producción) o modo dev con el header X-Dev-User.

El token de Firebase se verifica con PyJWT contra las llaves públicas de Google, como
describe la documentación de Firebase para librerías JWT de terceros. Así no hace falta
subir una cuenta de servicio a Railway: basta con FIREBASE_PROJECT_ID.
"""

import re
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any, Protocol

import jwt
from fastapi import Request

from app.core.errors import ServiceUnavailableError, UnauthorizedError

DEV_USER_HEADER = "X-Dev-User"
FIREBASE_JWKS_URL = (
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com"
)
_DEV_USER_RE = re.compile(r"^[A-Za-z0-9_.-]{1,64}$")
_CLOCK_SKEW_SECONDS = 30

SESSION_INVALID = "Tu sesión no es válida o venció. Vuelve a iniciar sesión."


@dataclass(frozen=True)
class Principal:
    firebase_uid: str
    email: str | None = None
    display_name: str | None = None


class Authenticator(Protocol):
    def authenticate(self, request: Request) -> Principal: ...


class DevAuthenticator:
    """Solo desarrollo: confía en el header X-Dev-User sin verificar nada."""

    def authenticate(self, request: Request) -> Principal:
        value = request.headers.get(DEV_USER_HEADER, "")
        if not _DEV_USER_RE.fullmatch(value):
            raise UnauthorizedError(
                "missing_credentials",
                f"Modo dev: envía el header {DEV_USER_HEADER} con un identificador "
                "(letras, números, punto, guion o guion bajo).",
            )
        # El prefijo evita choques con uids reales de Firebase si se comparte la BD.
        return Principal(firebase_uid=f"dev:{value}", email=None, display_name=value)


def _jwks_key_resolver() -> Callable[[str], Any]:
    client = jwt.PyJWKClient(FIREBASE_JWKS_URL, cache_jwk_set=True, lifespan=3600, timeout=5)
    return lambda token: client.get_signing_key_from_jwt(token).key


class FirebaseAuthenticator:
    def __init__(
        self, project_id: str, *, signing_key_for: Callable[[str], Any] | None = None
    ) -> None:
        self._project_id = project_id
        self._issuer = f"https://securetoken.google.com/{project_id}"
        self._signing_key_for = signing_key_for or _jwks_key_resolver()

    def authenticate(self, request: Request) -> Principal:
        scheme, _, token = request.headers.get("Authorization", "").partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise UnauthorizedError("missing_credentials", "Inicia sesión para continuar.")
        try:
            key = self._signing_key_for(token)
            claims = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                audience=self._project_id,
                issuer=self._issuer,
                leeway=_CLOCK_SKEW_SECONDS,
                options={"require": ["exp", "iat", "aud", "iss", "sub", "auth_time"]},
            )
        except jwt.PyJWKClientConnectionError as exc:
            raise ServiceUnavailableError(
                "auth_unavailable",
                "No pudimos verificar tu sesión en este momento. Intenta de nuevo.",
            ) from exc
        except jwt.PyJWTError as exc:
            raise UnauthorizedError("invalid_token", SESSION_INVALID) from exc

        uid = claims["sub"]
        if not isinstance(uid, str) or not 0 < len(uid) <= 128:
            raise UnauthorizedError("invalid_token", SESSION_INVALID)
        if claims["auth_time"] > time.time() + _CLOCK_SKEW_SECONDS:
            raise UnauthorizedError("invalid_token", SESSION_INVALID)
        return Principal(
            firebase_uid=uid, email=claims.get("email"), display_name=claims.get("name")
        )
