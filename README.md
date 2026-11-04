# MandiDog IA

Plataforma móvil que analiza una foto de la boca de un perro y devuelve un nivel de riesgo
orientativo (**verde / amarillo / rojo**) sobre posibles patologías mandibulares.
Proyecto de grado de Ingeniería de Software, Universidad Cooperativa de Colombia, sede Pasto.

> **MandiDog IA no diagnostica.** Es una herramienta de tamizaje orientativo. Todo
> resultado incluye la recomendación de consultar al veterinario.

## Estado

| Etapa | Carpeta | Estado |
|---|---|---|
| 1. API | `api/` | ✅ Lista en local: 119 pruebas, 96 % de cobertura |
| 2. Modelo | `ml/` | Pendiente |
| 3. App | `app/` | Esqueleto creado (`co.edu.ucc.mandidog`); funcionalidades pendientes |
| Despliegue | Railway + R2 | Pendiente |

## Estructura

```
├── api/            FastAPI + SQLAlchemy + Alembic (Python 3.11)
├── ml/             Entrenamiento: transfer learning MobileNetV2 / ResNet50   (etapa 2)
├── app/            Flutter, Android primero                                 (etapa 3)
├── docs/
│   ├── arquitectura.md               flujo, endpoints, errores, umbrales, decisiones
│   └── datos-y-consentimiento.md     Ley 1581: ciclo de vida de las fotos y autorización
├── docker-compose.yml               api + postgres + minio (simula R2)
└── .env.example
```

---

## Etapa 1 · API

### Requisitos

- Docker Desktop (con Docker Compose v2)
- [uv](https://docs.astral.sh/uv/) solo si vas a editar código de la API fuera de Docker

### Levantar el entorno

```bash
cp .env.example .env
docker compose up -d --build
```

Esto levanta:

| Servicio | URL en tu máquina | Notas |
|---|---|---|
| API | http://localhost:8008 | `/docs` tiene la documentación interactiva (OpenAPI) |
| PostgreSQL | `localhost:5436` | bases `mandidog` y `mandidog_test` |
| MinIO (API S3) | http://localhost:9000 | simula Cloudflare R2 |
| Consola de MinIO | http://localhost:9001 | usuario y clave: `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY` |

Al arrancar, `storage-init` crea el bucket y la regla que borra `tmp/` al día siguiente, y
la API aplica las migraciones. Para comprobarlo:

```bash
curl http://localhost:8008/health
# {"status":"ok","version":"0.1.0","environment":"development","model_version":"stub-1",...}
```

> Los puertos se cambian en `.env` (`API_HOST_PORT`, `POSTGRES_HOST_PORT`, …). Los
> predeterminados evitan el 5432 y el 8000, que suelen estar ocupados.

### Correr las pruebas

```bash
docker compose run --rm api pytest                       # 119 pruebas
docker compose run --rm api pytest --cov=app             # con cobertura
docker compose run --rm api ruff check . && docker compose run --rm api ruff format --check .
```

Las pruebas usan PostgreSQL y MinIO reales (base `mandidog_test` y bucket
`mandidog-images-test`), no simulaciones: los CHECK son de Postgres y la firma de las URLs
solo se puede probar contra un servidor S3.

### Probar el flujo a mano (modo dev)

En desarrollo `AUTH_MODE=dev`: el usuario se identifica con el header `X-Dev-User`. La API
avisa en los logs que está en este modo y **no arranca así con `ENV=production`**.

```bash
API=http://localhost:8008
H='X-Dev-User: ana'

# 1. Crear una mascota
PET=$(curl -s -X POST $API/api/v1/pets -H "$H" -H 'Content-Type: application/json' \
      -d '{"name":"Toby","breed":"Pug"}' | python -c 'import sys,json;print(json.load(sys.stdin)["id"])')

# 2. Pedir la URL firmada (tipo y tamaño exactos de la foto)
FOTO=foto.jpg
SIGN=$(curl -s -X POST $API/api/v1/uploads/sign -H "$H" -H 'Content-Type: application/json' \
       -d "{\"content_type\":\"image/jpeg\",\"content_length\":$(wc -c < $FOTO)}")
URL=$(echo "$SIGN" | python -c 'import sys,json;print(json.load(sys.stdin)["upload_url"])')
KEY=$(echo "$SIGN" | python -c 'import sys,json;print(json.load(sys.stdin)["object_key"])')

# 3. Subir la foto directo al almacenamiento
curl -s -X PUT "$URL" -H 'Content-Type: image/jpeg' --data-binary @$FOTO -o /dev/null -w '%{http_code}\n'

# 4. Pedir el análisis
curl -s -X POST $API/api/v1/analysis -H "$H" -H 'Content-Type: application/json' \
     -d "{\"pet_id\":\"$PET\",\"object_key\":\"$KEY\",\"image_consent\":false}"
```

Con `INFERENCE_BACKEND=stub` el resultado es fijo. Para ver los otros niveles cambia
`INFERENCE_STUB_PROBABILITY` en `.env` (`0.45` amarillo, `0.75` rojo) y reinicia la API con
`docker compose up -d api`.

### Probar desde un celular en la misma red

La URL firmada lleva el host dentro de la firma, así que debe ser alcanzable desde el
celular. En `.env` pon la IP de tu PC en la red local:

```
S3_PUBLIC_ENDPOINT_URL=http://192.168.1.50:9000
```

y reinicia: `docker compose up -d api`. La app debe apuntar a `http://192.168.1.50:8008`.

### Editar código de la API sin Docker

```bash
cd api
uv sync          # crea api/.venv con Python 3.11 (uv lo descarga si no lo tienes)
uv run ruff check .
```

La carpeta `api/` está montada en el contenedor y Uvicorn recarga solo al guardar.

### Variables de entorno

Todas están documentadas en [`.env.example`](.env.example). Las más importantes:

| Variable | Valor local | Producción |
|---|---|---|
| `ENV` | `development` | `production` |
| `AUTH_MODE` | `dev` | `firebase` (+ `FIREBASE_PROJECT_ID`) |
| `INFERENCE_BACKEND` | `stub` | `keras` (+ `INFERENCE_MODEL_PATH`) |
| `RISK_THRESHOLD_YELLOW` / `RISK_THRESHOLD_RED` | `0.30` / `0.60` | **provisionales**, salen de la validación cruzada de `ml/` |
| `S3_ENDPOINT_URL` | MinIO | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| `CONSENT_POLICY_VERSION` | `2026-11-v1` | versión vigente del texto de autorización |

### Preparar Cloudflare R2 (cuando se despliegue)

1. Crear el bucket y un token de API de R2 con permiso de lectura/escritura sobre él.
2. Aplicar la regla de `tmp/` con el mismo script que usa docker-compose:
   ```bash
   cd api
   S3_ENDPOINT_URL=https://<ACCOUNT_ID>.r2.cloudflarestorage.com S3_REGION=auto \
   S3_ACCESS_KEY_ID=... S3_SECRET_ACCESS_KEY=... S3_BUCKET=mandidog-images \
   uv run python -m scripts.init_storage
   ```
3. Antes de abrir la app al público, verificar contra R2 que un PUT con otro tamaño se
   rechaza con 403 (la prueba automática lo verifica contra MinIO).

---

## App · identificador

| Dato | Valor |
|---|---|
| `applicationId` / package name (Android) | `co.edu.ucc.mandidog` (en `app/android/app/build.gradle.kts`) |
| Nombre visible | MandiDog IA |
| Paquete Dart | `mandidog` |

El `applicationId` **no se puede cambiar** después de publicar en Google Play o de
registrar la app en Firebase.

Para registrar la app en Firebase también se pide la huella SHA-1 del certificado de firma.
La de depuración se obtiene así (el `-J-Duser.language=en` evita un fallo de `keytool` de
Java 25 en español):

```bash
keytool -J-Duser.language=en -list -v -keystore ~/.android/debug.keystore \
        -alias androiddebugkey -storepass android -keypass android | grep SHA
```

La de la llave de publicación (release) se agrega en Firebase cuando se cree esa llave.

## Documentación

- [Arquitectura](docs/arquitectura.md): flujo de carga firmada, verificación de pertenencia,
  niveles de riesgo, endpoints, códigos de error y decisiones.
- [Datos y consentimiento](docs/datos-y-consentimiento.md): Ley 1581, ciclo de vida de las
  fotos y texto de autorización.
