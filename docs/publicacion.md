# Publicación

Pasos para poner la API en internet y generar la app Android firmada. Nada de esto se
hace solo: requiere cuentas y claves que no van en git.

## 1. API en Railway

1. Crea un proyecto en Railway con dos servicios: **PostgreSQL** y el repositorio de GitHub.
2. En el servicio del repositorio, *Settings*: **Root Directory** = `/api` y **Config file
   path** = `/api/railway.json` (en un monorepo la ruta del archivo de configuración no
   sigue al Root Directory: va completa). Con eso Railway construye el `Dockerfile` (etapa
   `prod`, la última) y revisa `/health` antes de dar por buena cada versión.
3. Variables del servicio:

   | Variable | Valor |
   |---|---|
   | `ENV` | `production` |
   | `AUTH_MODE` | `firebase` (la API no arranca con `dev` en producción) |
   | `FIREBASE_PROJECT_ID` | id del proyecto de Firebase |
   | `DATABASE_URL` | referencia a la del servicio PostgreSQL (`${{Postgres.DATABASE_URL}}`) |
   | `CONSENT_POLICY_VERSION` | la misma que `kConsentVersion` en la app |
   | `CORS_ALLOW_ORIGINS` | vacío (la app Android no usa CORS) |

   `PORT` lo pone Railway. Las migraciones se aplican solas al arrancar (`docker/start.sh`).
4. *Settings → Networking → Generate Domain* da la URL pública (`https://….up.railway.app`).
   Esa URL es el `API_BASE_URL` de la app.
5. Veterinarios para la validación clínica: después de que entren una vez a la app, abre
   una terminal en el servicio (`railway ssh` desde la carpeta del proyecto enlazado) y
   ejecuta

   ```sh
   python -m app.cli set-role --email veterinaria@ejemplo.com --role vet
   ```

## 2. Firebase Authentication

1. Proyecto de Firebase → *Authentication* → *Sign-in method*: habilita **Correo/contraseña**
   y **Google** (pide un correo de soporte). El botón "Continuar con Google" de la app usa
   el flujo de Firebase (`signInWithProvider`), sin paquetes extra.
2. Registra la app Android `co.edu.ucc.mandidog` con los SHA-1 y SHA-256 de la llave de
   subida (paso 3) y, si usas Google Play, los de *App Signing* de Play Console. Para
   probar desde tu PC agrega también el SHA-1 de la llave de depuración. Sin el SHA-1
   correcto, el acceso con Google falla.
   "Continuar con Google" usa el selector de cuentas nativo de Android: pon en
   `GOOGLE_WEB_CLIENT_ID` el ID de cliente **web** (tipo 3 en `google-services.json`, o
   *Authentication → Google → Configuración del SDK web*). Sin él, la app usa el flujo
   del navegador, que en Chrome reciente puede mostrar "missing initial state".
3. Copia a `app/dart_defines.local.json` (está en `.gitignore`): `FIREBASE_API_KEY`,
   `FIREBASE_APP_ID`, `FIREBASE_PROJECT_ID` y `FIREBASE_MESSAGING_SENDER_ID`, y cambia
   `AUTH_MODE` a `firebase`.

## 3. Llave de subida de Android

Se crea una sola vez y se guarda con copia de seguridad: si se pierde, no se pueden publicar
actualizaciones con la misma llave.

```sh
keytool -genkey -v -keystore %USERPROFILE%\mandidog-upload.jks -keyalg RSA -keysize 2048 ^
  -validity 10000 -alias upload
```

Crea `app/android/key.properties` (está en `.gitignore`):

```properties
storePassword=<contraseña del keystore>
keyPassword=<contraseña de la llave>
keyAlias=upload
storeFile=C:\\Users\\<usuario>\\mandidog-upload.jks
```

Sin ese archivo, `flutter build` firma con la clave de depuración y muestra una advertencia:
sirve para probar, no para publicar.

Huellas de la llave (para Firebase y AI for Pet):

```sh
keytool -list -v -keystore %USERPROFILE%\mandidog-upload.jks -alias upload
```

## 4. AI for Pet en producción

- La clave de prueba (`tt_pk_test_…`) vence el **2026-11-18** y está ligada al SHA-256 de
  la llave de depuración.
- Para producción hay que pedir a AI for Pet la aprobación de la organización y una clave
  `tt_pk_live_…`, registrando el SHA-256 de la llave de subida (y el de *App Signing* si se
  publica en Google Play).

## 5. Compilar

Con `app/dart_defines.local.json` completo (`API_BASE_URL` = URL de Railway, `AUTH_MODE` =
`firebase`, clave de AI for Pet y datos de Firebase):

```sh
cd app
flutter build apk --release --dart-define-from-file=dart_defines.local.json        # APK para instalar directo
flutter build appbundle --release --dart-define-from-file=dart_defines.local.json  # para Google Play
```

Antes de cada versión sube `version:` en `app/pubspec.yaml` (`1.0.1+2`: el número tras `+`
debe crecer siempre).

## 6. Distribución

- **APK directo** (pruebas con usuarios, sustentación): comparte
  `build/app/outputs/flutter-apk/app-release.apk`; el teléfono pide permitir instalar apps
  de origen desconocido.
- **Google Play**: cuenta de desarrollador (pago único de 25 USD), ficha de la app,
  política de privacidad pública (puede salir de `docs/datos-y-consentimiento.md`),
  formulario de seguridad de datos y prueba cerrada con 12 testers durante 14 días si la
  cuenta es personal.
