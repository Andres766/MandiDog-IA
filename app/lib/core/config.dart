import 'package:flutter/foundation.dart';

/// Configuración que se inyecta al compilar:
///
///   flutter run --dart-define-from-file=dart_defines.local.json
///
/// La clave del SDK nunca se escribe en el código ni se sube a git.
class AppConfig {
  const AppConfig._();

  /// Clave publicable del SDK de AI for Pet (`tt_pk_test_…` o `tt_pk_live_…`).
  static const aiforpetSdkKey = String.fromEnvironment('AIFORPET_SDK_KEY');

  /// Debe coincidir con la dependencia de android/app/build.gradle.kts.
  static const aiforpetSdkVersion = '2.2.3';

  /// URL de la API. `10.0.2.2` es el localhost del PC visto desde el emulador de Android.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8008',
  );

  /// Usuario de prueba para la API en `AUTH_MODE=dev` (header X-Dev-User).
  /// Desaparece cuando se integre Firebase Auth en la etapa 3.
  static const devUser = String.fromEnvironment(
    'DEV_USER',
    defaultValue: 'prueba-local',
  );

  /// El SDK de AI for Pet solo existe en Android (y en iOS, aún no integrado).
  static bool get aiforpetSdkAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
