import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/auth/auth_service.dart';
import 'core/config.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  _registerFontLicenses();

  final AuthService auth;
  if (AppConfig.useFirebase) {
    final options = AppConfig.firebaseOptions;
    if (options == null) {
      runApp(const _ConfigError());
      return;
    }
    await Firebase.initializeApp(options: options);
    auth = FirebaseAuthService(
      FirebaseAuth.instance,
      googleServerClientId: AppConfig.googleWebClientId,
    );
  } else {
    auth = DevAuthService();
  }

  runApp(
    ProviderScope(
      overrides: [authServiceProvider.overrideWithValue(auth)],
      // Los errores se muestran con un botón "Reintentar"; sin reintentos automáticos.
      retry: (_, _) => null,
      child: const MandiDogApp(),
    ),
  );
}

void _registerFontLicenses() {
  for (final (family, file) in [
    ('Nunito', 'assets/fonts/OFL-Nunito.txt'),
    ('DM Sans', 'assets/fonts/OFL-DMSans.txt'),
  ]) {
    LicenseRegistry.addLicense(() async* {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString(file));
    });
  }
}

/// AUTH_MODE=firebase sin las opciones de Firebase: mejor un mensaje claro que un cierre.
class _ConfigError extends StatelessWidget {
  const _ConfigError();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Falta la configuración de Firebase. Compila con '
              'FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_PROJECT_ID y '
              'FIREBASE_MESSAGING_SENDER_ID en dart_defines.local.json.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
