import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// Sistema visual de MandiDog IA (DESIGN.md): app de cuidado de mascotas en la línea
/// de PetDesk, Petcube y TTcare.
///
/// - Fondo crema cálido, tarjetas blancas redondeadas y botones en píldora.
/// - Azul cobalto de marca para acciones y acentos.
/// - Verde, ámbar y rojo se reservan EXCLUSIVAMENTE para el nivel de riesgo.
class AppTheme {
  const AppTheme._();

  static const brand = Color(0xFF4A5FD9);
  static const brandDeep = Color(0xFF2B3A8C);
  static const brandTint = Color(0xFFE9ECFC);
  static const lilac = Color(0xFFB8A8F0);
  static const ink = Color(0xFF1C2333);
  static const cream = Color(0xFFFAF6F0);

  static const headingFont = 'Nunito';
  static const bodyFont = 'DMSans';

  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: brand,
      onPrimary: Colors.white,
      primaryContainer: brandTint,
      onPrimaryContainer: brandDeep,
      secondary: Color(0xFF6B5BC9),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFEFEAFD),
      onSecondaryContainer: Color(0xFF3B2F86),
      tertiary: Color(0xFF0E6E8C),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFE0F2F8),
      onTertiaryContainer: Color(0xFF0B4A5E),
      error: Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: Color(0xFFFCE8E6),
      onErrorContainer: Color(0xFF8C1D18),
      surface: cream,
      onSurface: ink,
      onSurfaceVariant: Color(0xFF5F6576),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFDFBF7),
      surfaceContainer: Color(0xFFF4EFE7),
      surfaceContainerHigh: Color(0xFFEFE9E0),
      surfaceContainerHighest: Color(0xFFE9E2D7),
      outline: Color(0xFF9A9FAD),
      outlineVariant: Color(0xFFECE6DC),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF2A3042),
      onInverseSurface: Color(0xFFF2F3F8),
      inversePrimary: Color(0xFFB9C3FF),
    ),
    RiskColors.light,
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF9AA8FF),
      onPrimary: Color(0xFF101A5C),
      primaryContainer: Color(0xFF2B3A8C),
      onPrimaryContainer: Color(0xFFDDE2FF),
      secondary: Color(0xFFC6BAFF),
      onSecondary: Color(0xFF2A1F6B),
      secondaryContainer: Color(0xFF3B2F86),
      onSecondaryContainer: Color(0xFFE9E3FF),
      tertiary: Color(0xFF8ED3EA),
      onTertiary: Color(0xFF00384A),
      tertiaryContainer: Color(0xFF0B4A5E),
      onTertiaryContainer: Color(0xFFD3F0FA),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF12141C),
      onSurface: Color(0xFFECEEF5),
      onSurfaceVariant: Color(0xFFAEB3C2),
      surfaceContainerLowest: Color(0xFF1B1E29),
      surfaceContainerLow: Color(0xFF181B25),
      surfaceContainer: Color(0xFF20232F),
      surfaceContainerHigh: Color(0xFF262A37),
      surfaceContainerHighest: Color(0xFF2D3140),
      outline: Color(0xFF6E7487),
      outlineVariant: Color(0xFF2C3040),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFFECEEF5),
      onInverseSurface: Color(0xFF1C2333),
      inversePrimary: brand,
    ),
    RiskColors.dark,
  );

  static ThemeData _build(ColorScheme scheme, RiskColors risk) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: bodyFont,
    );
    final text = base.textTheme;
    TextStyle? heading(TextStyle? s, {FontWeight weight = FontWeight.w800}) =>
        s?.copyWith(
          fontFamily: headingFont,
          fontWeight: weight,
          color: scheme.onSurface,
          letterSpacing: -0.2,
        );
    const pill = StadiumBorder();

    return base.copyWith(
      extensions: [risk],
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text.copyWith(
        displaySmall: heading(text.displaySmall),
        headlineLarge: heading(text.headlineLarge),
        headlineMedium: heading(text.headlineMedium),
        headlineSmall: heading(text.headlineSmall),
        titleLarge: heading(text.titleLarge),
        titleMedium: heading(text.titleMedium, weight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.5),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: SharedAxisPageTransitionsBuilder(
            transitionType: SharedAxisTransitionType.horizontal,
          ),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: headingFont,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
          shape: pill,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          foregroundColor: scheme.onSurface,
          backgroundColor: scheme.surfaceContainerLowest,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          shape: pill,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, Spacing.touchTarget),
          textStyle: const TextStyle(
            fontFamily: bodyFont,
            fontWeight: FontWeight.w700,
          ),
          shape: pill,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusField),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusField),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusField),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusField),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusField),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle: const TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: pill,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusLg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Spacing.radiusLg),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: TextStyle(
          fontFamily: bodyFont,
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: scheme.onSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radius),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Spacing.radiusField),
        ),
      ),
    );
  }
}

/// Ritmo de 4/8 dp y radios.
class Spacing {
  const Spacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Tarjetas.
  static const radius = 20.0;

  /// Campos de texto y avisos.
  static const radiusField = 16.0;

  /// Hojas, encabezados y paneles grandes.
  static const radiusLg = 28.0;
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
    yellowBg: Color(0xFFFEF3C7),
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

/// Colores del avatar de un perro sin foto: fondo pastel y tinta de su mismo tono.
/// Ninguno es verde, ámbar ni rojo (esos colores significan riesgo).
class PetPalette {
  const PetPalette._();

  static const _light = [
    (Color(0xFFE3E7FD), Color(0xFF2B3A8C)), // pervinca
    (Color(0xFFEDE7FE), Color(0xFF4C3A9E)), // lila
    (Color(0xFFDDF0FA), Color(0xFF0B4A5E)), // cielo
    (Color(0xFFF1EADF), Color(0xFF5C4B37)), // arena
    (Color(0xFFE6E9F0), Color(0xFF334155)), // pizarra
  ];

  static const _dark = [
    (Color(0xFF2B3A8C), Color(0xFFDDE2FF)),
    (Color(0xFF3B2F86), Color(0xFFE9E3FF)),
    (Color(0xFF0B4A5E), Color(0xFFD3F0FA)),
    (Color(0xFF4A3D2E), Color(0xFFF1EADF)),
    (Color(0xFF334155), Color(0xFFE6E9F0)),
  ];

  /// (fondo, tinta) estable según el id del perro.
  static (Color, Color) forId(String id, Brightness brightness) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final list = brightness == Brightness.dark ? _dark : _light;
    return list[hash % list.length];
  }
}
