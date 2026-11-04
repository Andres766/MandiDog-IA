#!/bin/sh
set -e

# Railway define PORT; en local se usa 8000.
if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  alembic upgrade head
fi

# shellcheck disable=SC2086
exec uvicorn app.main:create_app --factory \
  --host 0.0.0.0 --port "${PORT:-8000}" \
  --proxy-headers --forwarded-allow-ips="*" \
  ${UVICORN_EXTRA_ARGS:-}
