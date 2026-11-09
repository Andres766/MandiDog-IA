import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';

/// Ícono de la app (cuadrado azul redondeado con el perro-diente).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/logo_app.svg',
    width: size,
    height: size,
    semanticsLabel: 'MandiDog IA',
  );
}

/// Solo la figura, para fondos azules (arranque y encabezados).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/brand/logo_mark.svg',
    width: size,
    height: size,
    excludeFromSemantics: true,
  );
}

/// "MandiDog IA" con el peso de la marca.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.color, this.size = 28});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.onSurface;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'MandiDog'),
          TextSpan(
            text: ' IA',
            style: TextStyle(color: ink.withValues(alpha: 0.7)),
          ),
        ],
      ),
      style: TextStyle(
        fontFamily: AppTheme.headingFont,
        fontWeight: FontWeight.w800,
        fontSize: size,
        letterSpacing: -0.4,
        color: ink,
      ),
    );
  }
}

/// Ilustración de la marca sobre un círculo del color del tema (claro u oscuro).
class Illustration extends StatelessWidget {
  const Illustration(this.asset, {super.key, this.circle = 0.74});

  final String asset;

  /// Diámetro del círculo como fracción del ancho.
  final double circle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // En oscuro, un gris azulado: el azul profundo se confundiría con el dibujo.
    final tint = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : scheme.primaryContainer;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth * circle;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
            ),
            SvgPicture.asset(asset, excludeFromSemantics: true),
          ],
        );
      },
    );
  }
}
