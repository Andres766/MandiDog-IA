import 'package:flutter/material.dart';

/// Sistema visual de MandiDog IA (generado con la skill ui-ux-pro-max y ajustado):
/// minimalista, teal clínico y tipografías redondeadas y cercanas.
///
/// - El teal de los botones es el tono 40 de Material (contraste ≥ 4.5:1 con blanco).
/// - Verde, amarillo y rojo se reservan EXCLUSIVAMENTE para el nivel de riesgo; ningún
///   botón ni acento usa esos colores para que no se confundan con una alerta.
class AppTheme {
  const AppTheme._();

  static const seed = Color(0xFF0D9488);
  static const _lightBackground = Color(0xFFF0FDFA);

  static const headingFont = 'VarelaRound';
  static const bodyFont = 'NunitoSans';

  static ThemeData light() => _build(
    ColorScheme.fromSeed(seedColor: seed, surface: _lightBackground),
    RiskColors.light,
  );

  static ThemeData dark() => _build(
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
    RiskColors.dark,
  );

  static ThemeData _build(ColorScheme scheme, RiskColors risk) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: bodyFont,
    );
    final text = base.textTheme;
    TextStyle? heading(TextStyle? s) =>
        s?.copyWith(fontFamily: headingFont, color: scheme.onSurface);

    return base.copyWith(
      extensions: [risk],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: heading(text.titleLarge),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          fontSize: 22,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, Spacing.touchTarget),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Spacing.radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, Spacing.touchTarget),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Spacing.radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Spacing.touchTarget),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Spacing.radius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle: const TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Ritmo de 4/8 dp.
class Spacing {
  const Spacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const radius = 16.0;
  static const touchTarget = 48.0;

  /// Ancho máximo del contenido en tabletas y navegador.
  static const maxContentWidth = 640.0;
}

/// Colores del semáforo de riesgo. Texto sobre fondo con contraste ≥ 4.5:1 en ambos temas.
@immutable
class RiskColors extends ThemeExtension<RiskColors> {
  const RiskColors({
    required this.greenFg,
    required this.greenBg,
    required this.yellowFg,
    required this.yellowBg,
    required this.redFg,
    required this.redBg,
  });

  final Color greenFg;
  final Color greenBg;
  final Color yellowFg;
  final Color yellowBg;
  final Color redFg;
  final Color redBg;

  static const light = RiskColors(
    greenFg: Color(0xFF166534),
    greenBg: Color(0xFFDCFCE7),
    yellowFg: Color(0xFF854D0E),
    yellowBg: Color(0xFFFEF9C3),
    redFg: Color(0xFF991B1B),
    redBg: Color(0xFFFEE2E2),
  );

  static const dark = RiskColors(
    greenFg: Color(0xFFBBF7D0),
    greenBg: Color(0xFF14532D),
    yellowFg: Color(0xFFFEF08A),
    yellowBg: Color(0xFF713F12),
    redFg: Color(0xFFFECACA),
    redBg: Color(0xFF7F1D1D),
  );

  @override
  RiskColors copyWith() => this;

  @override
  RiskColors lerp(ThemeExtension<RiskColors>? other, double t) =>
      other is RiskColors && t >= 0.5 ? other : this;
}
