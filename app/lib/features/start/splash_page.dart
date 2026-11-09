import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand.dart';

/// Continúa la pantalla de arranque nativa (mismo azul y misma figura): el perro
/// aparece con un rebote, brilla y deja paso a la app. Dura poco más de un segundo.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    _continue();
  }

  Future<void> _continue() async {
    final seen = AppPrefs.onboardingSeen();
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    await Future<void>.delayed(Duration(milliseconds: reduce ? 300 : 1400));
    final onboardingSeen = await seen;
    if (!mounted) return;
    // Pase lo que pase, el arranque nunca se queda en esta pantalla.
    bool signedIn;
    try {
      signedIn = ref.read(authServiceProvider).currentUser != null;
    } catch (e) {
      debugPrint('Arranque: $e');
      signedIn = false;
    }
    context.go(
      !onboardingSeen
          ? '/welcome'
          : signedIn
          ? '/'
          : '/login',
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget mark = const BrandMark(size: 132);
    Widget title = const BrandWordmark(color: Colors.white, size: 30);
    Widget tagline = Text(
      'Sonrisas sanas, perros felices',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
    if (!reduce) {
      mark = mark
          .animate()
          .scaleXY(
            begin: 0.6,
            end: 1,
            duration: 650.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms)
          .then(delay: 150.ms)
          .shimmer(duration: 700.ms, color: const Color(0xFFC9D1FF));
      title = title
          .animate(delay: 300.ms)
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic);
      tagline = tagline.animate(delay: 500.ms).fadeIn(duration: 400.ms);
    }
    return Scaffold(
      backgroundColor: AppTheme.brand,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            mark,
            const SizedBox(height: Spacing.md),
            title,
            const SizedBox(height: Spacing.xs),
            tagline,
          ],
        ),
      ),
    );
  }
}
