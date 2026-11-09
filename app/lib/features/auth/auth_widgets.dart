import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Escribe tu correo.';
  if (!_emailPattern.hasMatch(v)) {
    return 'Revisa el correo: falta algo (ej. nombre@correo.com).';
  }
  return null;
}

String? validatePassword(String? value) {
  if ((value ?? '').length < 8) {
    return 'La contraseña debe tener al menos 8 caracteres.';
  }
  return null;
}

/// Pantallas de acceso: encabezado azul con la marca y una hoja blanca que sube con
/// el formulario.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
    this.compactHeader = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;
  final bool compactHeader;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final headerHeight = compactHeader ? 150.0 : 240.0;

    Widget sheet = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(Spacing.radiusLg),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xl,
        Spacing.lg,
        Spacing.xl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: text.headlineMedium),
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                subtitle,
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: Spacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
    if (!reduce) {
      sheet = sheet
          .animate()
          .slideY(
            begin: 0.08,
            end: 0,
            duration: 450.ms,
            curve: Curves.easeOutCubic,
          )
          .fadeIn(duration: 300.ms);
    }

    return Scaffold(
      backgroundColor: AppTheme.brand,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: headerHeight + MediaQuery.paddingOf(context).top,
              child: _Header(showBack: showBack, compact: compactHeader),
            ),
          ),
          SliverFillRemaining(hasScrollBody: false, child: sheet),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.showBack, required this.compact});

  final bool showBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Destellos decorativos, como en el logo.
        const Positioned(top: 70, left: 28, child: _Sparkle(size: 18)),
        const Positioned(top: 120, right: 36, child: _Sparkle(size: 26)),
        const Positioned(bottom: 40, left: 70, child: _Sparkle(size: 12)),
        SafeArea(
          bottom: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandMark(size: compact ? 72 : 108),
                if (!compact) ...[
                  const SizedBox(height: Spacing.sm),
                  const BrandWordmark(color: Colors.white, size: 26),
                ],
              ],
            ),
          ),
        ),
        if (showBack)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.xs),
              child: IconButton(
                tooltip: 'Volver',
                color: Colors.white,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
      ],
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Icon(
      Icons.auto_awesome,
      size: size,
      color: Colors.white.withValues(alpha: 0.35),
    ),
  );
}

/// "Continuar con Google", con el logo oficial.
class GoogleButton extends StatelessWidget {
  const GoogleButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: SvgPicture.asset(
        'assets/brand/google_g.svg',
        width: 20,
        height: 20,
        excludeFromSemantics: true,
      ),
      label: const Text('Continuar con Google'),
    );
  }
}

/// Separador "o" entre el acceso con correo y con Google.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Text('o', style: TextStyle(color: muted)),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.helperText,
    this.autofillHints = const [AutofillHints.password],
    this.validator = validatePassword,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final Iterable<String> autofillHints;
  final String? Function(String?) validator;
  final TextInputAction textInputAction;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Mensaje de error del formulario, anunciado por el lector de pantalla.
class FormError extends StatelessWidget {
  const FormError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Semantics(
        liveRegion: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(Spacing.radiusField),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    message!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón principal con estado de carga, sin cambiar de tamaño.
class BusyButton extends StatelessWidget {
  const BusyButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          )
        : Text(label);
    final onTap = busy ? null : onPressed;
    if (icon != null && !busy) {
      return FilledButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: child,
      );
    }
    return FilledButton(
      onPressed: onTap,
      child: Semantics(label: busy ? '$label, en curso' : null, child: child),
    );
  }
}
