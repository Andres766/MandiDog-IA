import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Configuración que se inyecta al compilar:
///
///   flutter run --dart-define-from-file=dart_defines.local.json
///
/// Las claves nunca se escriben en el código ni se suben a git.
class AppConfig {
  const AppConfig._();

  /// `dev`: usuario de prueba con el header X-Dev-User (la API debe estar en AUTH_MODE=dev).
  /// `firebase`: inicio de sesión real con Firebase Auth.
  static const authMode = String.fromEnvironment(
    'AUTH_MODE',
    defaultValue: 'dev',
  );
  static bool get useFirebase => authMode == 'firebase';

  /// Usuario de prueba por defecto en modo dev.
  static const devUser = String.fromEnvironment(
    'DEV_USER',
    defaultValue: 'prueba-local',
  );

  /// URL de la API. `10.0.2.2` es el localhost del PC visto desde el emulador de Android.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8008',
  );

  /// Clave publicable del SDK de AI for Pet (`tt_pk_test_…` o `tt_pk_live_…`).
  static const aiforpetSdkKey = String.fromEnvironment('AIFORPET_SDK_KEY');

  /// Debe coincidir con la dependencia de android/app/build.gradle.kts.
  static const aiforpetSdkVersion = '2.2.3';

  /// El SDK de AI for Pet solo existe en Android (y en iOS, aún no integrado).
  static bool get aiforpetSdkAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const _firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );

  /// ID de cliente web de OAuth (tipo 3 en google-services.json). Con él, "Continuar
  /// con Google" usa el selector de cuentas nativo de Android en vez del navegador.
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );

  /// Opciones de Firebase desde --dart-define (sin google-services.json en el repo).
  /// Null si falta alguna.
  static FirebaseOptions? get firebaseOptions {
    if ([
      _firebaseApiKey,
      _firebaseAppId,
      _firebaseProjectId,
      _firebaseSenderId,
    ].any((v) => v.isEmpty)) {
      return null;
    }
    return const FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: _firebaseAppId,
      projectId: _firebaseProjectId,
      messagingSenderId: _firebaseSenderId,
      authDomain: '$_firebaseProjectId.firebaseapp.com',
    );
  }
}
