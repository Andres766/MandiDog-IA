/// Configuración que se inyecta al compilar:
///
///   flutter run --dart-define=AIFORPET_SDK_KEY=tt_pk_test_... \
///               --dart-define=API_BASE_URL=http://192.168.1.50:8008
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
}
