# syntax=docker/dockerfile:1.7

# --- builder: resuelve dependencias con uv (ni uv ni su caché llegan a la imagen final) ---
FROM python:3.11-slim AS builder
COPY --from=ghcr.io/astral-sh/uv:0.11.3 /uv /usr/local/bin/uv
ENV UV_PROJECT_ENVIRONMENT=/opt/venv \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /srv
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev

FROM builder AS builder-dev
RUN uv sync --frozen

# --- base de ejecución ---
FROM python:3.11-slim AS runtime
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"
WORKDIR /srv
EXPOSE 8000

# --- dev: lo usa docker-compose (incluye pytest/ruff y monta el código) ---
FROM runtime AS dev
COPY --from=builder-dev /opt/venv /opt/venv
COPY . .
CMD ["sh", "docker/start.sh"]

# --- prod: la que construye Railway (última etapa) ---
FROM runtime AS prod
COPY --from=builder /opt/venv /opt/venv
COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app
COPY docker/start.sh ./docker/start.sh
RUN useradd --system --uid 10001 --no-create-home mandidog
USER mandidog
CMD ["sh", "docker/start.sh"]
