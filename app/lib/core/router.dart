import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/register_page.dart';
import '../features/auth/reset_password_page.dart';
import '../features/capture/presentation/scan_page.dart';
import '../features/consent/consent_page.dart';
import '../features/pets/pet_detail_page.dart';
import '../features/pets/pet_form_page.dart';
import '../features/pets/pets_page.dart';
import '../features/result/result_page.dart';
import '../features/start/onboarding_page.dart';
import '../features/start/splash_page.dart';
import '../features/validation/validation_case_page.dart';
import '../features/validation/validation_list_page.dart';
import '../features/validation/validation_summary_page.dart';
import 'api/models.dart';
import 'auth/auth_service.dart';
import 'providers.dart';

const _publicRoutes = {'/login', '/register', '/reset-password', '/welcome'};

/// Vuelve a evaluar la redirección cada vez que cambia la sesión.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AppUser?> changes) {
    _subscription = changes.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AppUser?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authServiceProvider);
  final refresh = _AuthRefresh(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      // El arranque decide a dónde ir cuando termina su animación.
      if (state.matchedLocation == '/splash') return null;
      final signedIn = auth.currentUser != null;
      final public = _publicRoutes.contains(state.matchedLocation);
      if (!signedIn && !public) return '/login';
      if (signedIn && public) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashPage()),
      GoRoute(path: '/welcome', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterPage()),
      GoRoute(
        path: '/reset-password',
        builder: (_, _) => const ResetPasswordPage(),
      ),
      GoRoute(path: '/', builder: (_, _) => const PetsPage()),
      GoRoute(path: '/account', builder: (_, _) => const AccountPage()),
      GoRoute(
        path: '/consent',
        builder: (_, state) =>
            ConsentPage(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: '/validation',
        builder: (_, _) => const ValidationListPage(),
        routes: [
          GoRoute(
            path: 'summary',
            builder: (_, _) => const ValidationSummaryPage(),
          ),
          GoRoute(
            path: ':analysisId',
            builder: (_, state) => ValidationCasePage(
              analysisId: state.pathParameters['analysisId']!,
            ),
          ),
        ],
      ),
      GoRoute(path: '/pets/new', builder: (_, _) => const PetFormPage()),
      GoRoute(
        path: '/pets/:id',
        builder: (_, state) =>
            PetDetailPage(petId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) =>
                PetFormPage(petId: state.pathParameters['id']),
          ),
          GoRoute(
            path: 'scan',
            builder: (_, state) => ScanPage(petId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'analyses/:analysisId',
            builder: (_, state) => ResultPage(
              petId: state.pathParameters['id']!,
              analysisId: state.pathParameters['analysisId']!,
              initial: state.extra is Analysis
                  ? state.extra! as Analysis
                  : null,
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
