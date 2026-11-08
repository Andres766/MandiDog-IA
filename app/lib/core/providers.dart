import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/capture/data/tooth_scanner.dart';
import 'api/mandidog_api.dart';
import 'api/models.dart';
import 'auth/auth_service.dart';
import 'config.dart';

/// Se sobrescribe en main() con DevAuthService o FirebaseAuthService.
final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('authServiceProvider sin configurar'),
);

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authServiceProvider).authStateChanges(),
);

final apiProvider = Provider<MandiDogApi>((ref) {
  final auth = ref.watch(authServiceProvider);
  return MandiDogApi(
    baseUrl: AppConfig.apiBaseUrl,
    idToken: auth.idToken,
    devUser: () => auth.devUserHeader,
  );
});

final toothScannerProvider = Provider<ToothScanner>(
  (ref) => ToothScanner(sdkKey: AppConfig.aiforpetSdkKey),
);

final sdkAvailableProvider = Provider<bool>(
  (ref) => AppConfig.aiforpetSdkAvailable,
);

/// Datos del usuario y estado de su autorización. Se recarga al cambiar de sesión.
final meProvider = FutureProvider<UserProfile>((ref) {
  ref.watch(authStateProvider.select((s) => s.value?.uid));
  return ref.watch(apiProvider).me();
});

final petsProvider = FutureProvider<List<Pet>>((ref) {
  ref.watch(authStateProvider.select((s) => s.value?.uid));
  return ref.watch(apiProvider).pets();
});

final petProvider = FutureProvider.family<Pet, String>(
  (ref, id) => ref.watch(apiProvider).pet(id),
);

final historyProvider = FutureProvider.family<List<Analysis>, String>(
  (ref, petId) => ref.watch(apiProvider).history(petId),
);

final pendingCasesProvider = FutureProvider<List<PendingCase>>(
  (ref) => ref.watch(apiProvider).pendingCases(),
);

final validationSummaryProvider = FutureProvider<ValidationSummary>(
  (ref) => ref.watch(apiProvider).validationSummary(),
);

/// Tras registrar o borrar algo, refresca lo que muestra la app.
void refreshPetData(WidgetRef ref, String petId) {
  ref.invalidate(petsProvider);
  ref.invalidate(petProvider(petId));
  ref.invalidate(historyProvider(petId));
}
