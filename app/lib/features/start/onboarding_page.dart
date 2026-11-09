import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand.dart';

class _Slide {
  const _Slide(this.image, this.title, this.text);

  final String image;
  final String title;
  final String text;
}

const _slides = [
  _Slide(
    'assets/illustrations/scan.svg',
    'Revisa sus dientes con una foto',
    'La cámara de AI for Pet te guía para tomar la foto de la boca de tu perro.',
  ),
  _Slide(
    'assets/illustrations/result.svg',
    'Un resultado claro en segundos',
    'Verde, amarillo o rojo según los signos de sarro e inflamación de encías. '
        'Es orientativo: no reemplaza al veterinario.',
  ),
  _Slide(
    'assets/illustrations/history.svg',
    'Su historial, siempre a mano',
    'Guarda cada revisión y muéstrasela a tu veterinario en la próxima consulta.',
  ),
];

/// Presentación de tres pasos la primera vez que se abre la app.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await AppPrefs.markOnboardingSeen();
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = _index == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  0,
                  Spacing.sm,
                  Spacing.sm,
                  0,
                ),
                child: AnimatedOpacity(
                  opacity: last ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: last ? null : _finish,
                    child: const Text('Saltar'),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Semantics(
              label: 'Paso ${_index + 1} de ${_slides.length}',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _index ? 24 : 8,
                      height: 8,
                      decoration: ShapeDecoration(
                        shape: const StadiumBorder(),
                        color: i == _index
                            ? scheme.primary
                            : scheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(last ? 'Empezar' : 'Siguiente'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    Widget image = Illustration(slide.image);
    if (!reduce) {
      image = image
          .animate()
          .fadeIn(duration: 350.ms)
          .scaleXY(begin: 0.92, end: 1, curve: Curves.easeOutBack);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: AspectRatio(aspectRatio: 320 / 260, child: image),
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: text.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm + 4),
          Text(
            slide.text,
            textAlign: TextAlign.center,
            style: text.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
