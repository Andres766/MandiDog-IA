import 'package:flutter/material.dart';

import 'app_theme.dart';

enum RiskLevel {
  green,
  yellow,
  red;

  static RiskLevel? parse(String? value) => switch (value) {
    'green' => RiskLevel.green,
    'yellow' => RiskLevel.yellow,
    'red' => RiskLevel.red,
    _ => null,
  };
}

/// Cómo se presenta cada nivel. Siempre ícono + texto + color: nunca solo color.
class RiskStyle {
  const RiskStyle({
    required this.label,
    required this.short,
    required this.description,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  final String label;
  final String short;
  final String description;
  final IconData icon;
  final Color foreground;
  final Color background;

  static RiskStyle of(BuildContext context, RiskLevel level) {
    final colors = Theme.of(context).extension<RiskColors>()!;
    return switch (level) {
      RiskLevel.green => RiskStyle(
        label: 'Sin signos de riesgo',
        short: 'Verde',
        description:
            'No se observaron signos de sarro ni de inflamación de encías.',
        icon: Icons.check_circle_outline,
        foreground: colors.greenFg,
        background: colors.greenBg,
      ),
      RiskLevel.yellow => RiskStyle(
        label: 'Conviene vigilar',
        short: 'Amarillo',
        description:
            'Se observaron signos que conviene revisar con tu veterinario.',
        icon: Icons.visibility_outlined,
        foreground: colors.yellowFg,
        background: colors.yellowBg,
      ),
      RiskLevel.red => RiskStyle(
        label: 'Consulta pronto',
        short: 'Rojo',
        description: 'Se observaron signos que requieren atención veterinaria.',
        icon: Icons.priority_high_rounded,
        foreground: colors.redFg,
        background: colors.redBg,
      ),
    };
  }
}
