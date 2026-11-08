# MandiDog IA

App móvil que analiza fotos de los dientes de un perro con el SDK de **AI for Pet** y
devuelve un nivel de riesgo orientativo (**verde / amarillo / rojo**) sobre su salud dental:
sarro e inflamación de encías.
Proyecto de grado de Ingeniería de Software, Universidad Cooperativa de Colombia, sede Pasto.

> **MandiDog IA no diagnostica.** Es una herramienta de tamizaje orientativo. Todo
> resultado incluye la recomendación de consultar al veterinario.

## Estado

| Parte | Carpeta | Estado |
|---|---|---|
| API | `api/` | ✅ Lista en local: 118 pruebas |
| Integración AI for Pet | `app/android/` + `app/lib/features/capture/` | ✅ Probada con un escaneo real en un Galaxy S25 Ultra (Android 17); simulación en navegador |
| App (acceso, perros, autorización, escaneo, resultado, historial, cuenta) | `app/` | ✅ Etapa 3 en modo desarrollo: 35 pruebas; Firebase listo para conectar |
| Validación clínica ciega (veterinarios) | `api/` + `app/lib/features/validation/` | ✅ Valoración a ciegas, revelado y concordancia (sensibilidad, especificidad, exactitud) |
| Despliegue | Railway + APK/Play | Configuración lista ([docs/publicacion.md](docs/publicacion.md)); faltan las cuentas y claves |

El 2026-11-04 se reemplazó el modelo propio por el SDK de AI for Pet. Los motivos y las
consecuencias están en [docs/arquitectura.md](docs/arquitectura.md#0-cambio-de-arquitectura-2026-11-04).

## Estructura

```
├── api/            FastAPI + SQLAlchemy + Alembic (Python 3.11)
├── app/            Flutter, Android 9+, con el SDK nativo de AI for Pet
├── docs/
│   ├── arquitectura.md               flujo, integración con el SDK, endpoints, errores, decisiones
│   ├── datos-y-consentimiento.md     Ley 1581, transferencia a AI for Pet, texto de autorización
│   └── publicacion.md                Railway, Firebase, llave de Android y distribución
├── docker-compose.yml               api + postgres
└── .env.example
```

---

## API

### Requisitos

- Docker Desktop (con Docker Compose v2)
- [uv](https://docs.astral.sh/uv/) solo si vas a editar código de la API fuera de Docker

### Levantar el entorno

```bash
cp .env.example .env
docker compose up -d --build
curl http://localhost:8008/health
# {"status":"ok","version":"0.1.0","environment":"development","analysis_provider":"aiforpet","database":"ok"}
```

| Servicio | URL en tu máquina | Notas |
|---|---|---|
| API | http://localhost:8008 | `/docs` tiene la documentación interactiva (OpenAPI) |
| PostgreSQL | `localhost:5436` | bases `mandidog` y `mandidog_test` |

La API aplica las migraciones al arrancar. Los puertos se cambian en `.env`
(`API_HOST_PORT`, `POSTGRES_HOST_PORT`); los predeterminados evitan el 5432 y el 8000.

### Correr las pruebas

```bash
docker compose run --rm api pytest                  # 118 pruebas
docker compose run --rm api pytest --cov=app        # con cobertura
docker compose run --rm api sh -c "ruff check . && ruff format --check ."
```

Usan el PostgreSQL de docker-compose (base `mandidog_test`), no una simulación: los CHECK,
los enums y JSONB son de Postgres. Los resultados de prueba parten del JSON oficial de
ejemplo de AI for Pet.

### Probar el flujo a mano (modo dev)

En desarrollo `AUTH_MODE=dev`: el usuario se identifica con el header `X-Dev-User`. La API
avisa en los logs que está en este modo y **no arranca así con `ENV=production`**.

```bash
API=http://localhost:8008
H='X-Dev-User: ana'

# 1. Aceptar la autorización vigente (sin ella no se registran análisis)
curl -s -X PUT $API/api/v1/me/consent -H "$H" -H 'Content-Type: application/json' \
     -d '{"policy_version":"2026-11-v2"}'

# 2. Crear una mascota
PET=$(curl -s -X POST $API/api/v1/pets -H "$H" -H 'Content-Type: application/json' \
      -d '{"name":"Toby"}' | python -c 'import sys,json;print(json.load(sys.stdin)["id"])')

# 3. Registrar un resultado como el que devuelve el SDK
curl -s -X POST $API/api/v1/analysis -H "$H" -H 'Content-Type: application/json' -d "{
  \"pet_id\": \"$PET\",
  \"client_scan_id\": \"$(python -c 'import uuid;print(uuid.uuid4())')\",
  \"sdk_platform\": \"android\", \"sdk_version\": \"2.2.3\",
  \"result\": {\"status\":\"SUCCESS\",\"petType\":\"DOG\",\"part\":\"TOOTH\",\"subPart\":\"TCENTER\",
             \"response\":{\"status\":\"CAUTION\",\"symptoms\":[
               {\"code\":\"inflammation\",\"abnormLevel\":1},{\"code\":\"calculus\",\"abnormLevel\":0}]}}
}"
# → risk_level "yellow", hallazgos en español y la recomendación con el aviso del veterinario
```

### Variables de entorno

Todas están en [`.env.example`](.env.example):

| Variable | Local | Producción |
|---|---|---|
| `ENV` | `development` | `production` |
| `AUTH_MODE` | `dev` | `firebase` (+ `FIREBASE_PROJECT_ID`) |
| `DATABASE_URL` | Postgres de docker-compose | la que entrega Railway |
| `CONSENT_POLICY_VERSION` | `2026-11-v2` | versión vigente del texto de autorización |

La clave del SDK de AI for Pet **no** va en la API: la usa la app.

### Editar código de la API sin Docker

```bash
cd api
uv sync          # crea api/.venv con Python 3.11 (uv lo descarga si no lo tienes)
uv run ruff check .
```

La carpeta `api/` está montada en el contenedor y Uvicorn recarga solo al guardar.

---

## App

### Identificador

| Dato | Valor |
|---|---|
| `applicationId` / package name (Android) | `co.edu.ucc.mandidog` (en `app/android/app/build.gradle.kts`) |
| Nombre visible | MandiDog IA |
| Paquete Dart | `mandidog` |

El `applicationId` **no se puede cambiar** después de registrarlo en Firebase, en AI for Pet
o en Google Play.

### Registrar la app en AI for Pet

En la consola de AI for Pet (*SDK integration → Android → Edit registration*) se registran el
paquete y el **SHA-256** del certificado que firma la app. Debug, release y Google Play App
Signing tienen huellas distintas; hay que registrar cada una que se vaya a usar. La de
depuración se obtiene así (el `-J-Duser.language=en` evita un fallo de `keytool` de Java 25
en español):

```bash
keytool -J-Duser.language=en -list -v -keystore ~/.android/debug.keystore \
        -alias androiddebugkey -storepass android -keypass android | grep SHA
```

### Configuración de la app (`dart_defines.local.json`)

La app se configura al compilar. Copia `app/dart_defines.example.json` a
`app/dart_defines.local.json` (está en el `.gitignore`) y completa:

| Clave | Para qué |
|---|---|
| `AUTH_MODE` | `dev` (usuario de prueba, sin Firebase) o `firebase` |
| `DEV_USER` | Usuario de prueba sugerido en modo dev |
| `API_BASE_URL` | `http://localhost:8008` (celular por USB) · `http://10.0.2.2:8008` (emulador) |
| `AIFORPET_SDK_KEY` | Clave publicable completa del SDK de AI for Pet |
| `FIREBASE_API_KEY`, `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID`, `FIREBASE_MESSAGING_SENDER_ID` | Del proyecto de Firebase (*Configuración del proyecto → Tus apps → Android*) |

Para usar Firebase: crea el proyecto, habilita **Authentication → Correo electrónico/contraseña**,
registra la app Android (`co.edu.ucc.mandidog` + SHA-1), completa esas cuatro claves y pon
`"AUTH_MODE": "firebase"`. La API también debe pasar a `AUTH_MODE=firebase` con
`FIREBASE_PROJECT_ID`. No hace falta `google-services.json`: las opciones se pasan al compilar.

### Probar en un celular

Hace falta un **celular Android 9 o superior** conectado por USB con la depuración USB
activada; el emulador no sirve para la cámara del SDK.

```bash
cd app
adb devices                          # el celular debe aparecer como "device"
adb reverse tcp:8008 tcp:8008        # el celular ve la API del PC en localhost:8008 por el cable
flutter run --dart-define-from-file=dart_defines.local.json
```

Solo la versión de depuración permite HTTP hacia la API local
(`android/app/src/debug/res/xml/network_security_config_debug.xml`); producción usa HTTPS.
En Samsung, además de la *Depuración USB*, hay que desactivar el **Bloqueo automático**
(Ajustes → Seguridad y privacidad), que bloquea la depuración por cable.

Cada escaneo real consume uno de los análisis del plan de prueba de AI for Pet (100, vence
el 2026-11-18).

### Probar en el navegador (sin SDK)

El SDK de AI for Pet solo existe en Android, así que en el navegador el escaneo se
**simula** con el resultado de ejemplo oficial de AI for Pet. Todo lo demás es real: acceso,
autorización, perros, historial y registro en la API local (queda marcado como
`2.2.3-simulacion` y la app lo muestra como "Resultado simulado"). Con la API corriendo
(`docker compose up -d`):

```bash
cd app
flutter build web --dart-define=API_BASE_URL=http://localhost:8008
python -m http.server 5050 --bind 127.0.0.1 -d build/web
# abrir http://localhost:5050 en Chrome
```

El puerto 5050 es el que la API autoriza en `CORS_ALLOW_ORIGINS` (`.env`). La app Android no
usa CORS; en producción esa variable queda vacía.

### Pruebas de la app

```bash
cd app
flutter analyze
flutter test                         # 35 pruebas; simulan la API y el SDK, no consumen análisis
flutter build apk --debug            # compila con el SDK real de AI for Pet
```

### Validación clínica

Un veterinario valora cada escaneo mirando solo las fotos; después de registrar su
valoración la app le muestra lo que dijo la IA. *Mi cuenta → Validación clínica* aparece
solo para cuentas con rol `vet`. En desarrollo:

```bash
docker compose exec api python -m app.cli set-role --uid dev:prueba-local --role vet
```

## Documentación

- [Arquitectura](docs/arquitectura.md): flujo del escaneo, integración con el SDK,
  interpretación del resultado, endpoints, códigos de error y decisiones.
- [Datos y consentimiento](docs/datos-y-consentimiento.md): Ley 1581, transferencia
  internacional a AI for Pet, derechos del titular y texto de autorización.
- [Diseño](DESIGN.md): sistema visual "placa de collar" (color, tipografía, componentes,
  semáforo) y reglas de accesibilidad.
- [Publicación](docs/publicacion.md): API en Railway, Firebase, firma de Android y
  distribución.
