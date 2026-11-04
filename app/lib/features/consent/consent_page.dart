import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/states.dart';
import '../auth/auth_widgets.dart';
import 'consent_text.dart';

/// Autorización de tratamiento de datos (Ley 1581). Sin ella no se abre la cámara.
/// [next] es la ruta a la que se continúa después de aceptar (por ejemplo, el escaneo).
class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key, this.next});

  final String? next;

  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  bool _checked = false;
  bool _busy = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).acceptConsent(kConsentVersion);
      ref.invalidate(meProvider);
      if (!mounted) return;
      final next = widget.next;
      if (next != null) {
        context.pushReplacement(next);
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Revocar la autorización?'),
        content: const Text(
          'No podrás hacer escaneos nuevos hasta que la aceptes otra vez. Tu historial se '
          'conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).revokeConsent();
      ref.invalidate(meProvider);
      if (mounted) showMessage(context, 'Autorización revocada.');
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(meProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Autorización de datos')),
      body: switch (me) {
        AsyncData(:final value) => _content(value.consent),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(meProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }

  Widget _content(Consent consent) {
    final textTheme = Theme.of(context).textTheme;
    final outdatedApp = consent.currentVersion != kConsentVersion;
    final accepted = !consent.required;

    return PageBody(
      children: [
        Text(kConsentIntro, style: textTheme.bodyLarge),
        const SizedBox(height: Spacing.sm),
        for (final (i, purpose) in kConsentPurposes.indexed)
          _Item(leading: '${i + 1}.', text: purpose),
        const SectionTitle('Ten en cuenta que'),
        for (final item in kConsentUnderstand) _Item(leading: '•', text: item),
        const SizedBox(height: Spacing.md),
        Text(
          '$kConsentResponsible Versión $kConsentVersion.',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: Spacing.lg),
        FormError(_error),
        if (outdatedApp)
          const FormError(
            'El texto de autorización cambió. Actualiza la app para leer y aceptar la '
            'versión vigente.',
          )
        else if (accepted) ...[
          _AcceptedNote(acceptedAt: consent.acceptedAt),
          const SizedBox(height: Spacing.md),
          OutlinedButton.icon(
            onPressed: _busy ? null : _revoke,
            icon: const Icon(Icons.block_outlined),
            label: const Text('Revocar autorización'),
          ),
        ] else ...[
          CheckboxListTile(
            value: _checked,
            onChanged: _busy
                ? null
                : (v) => setState(() => _checked = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('He leído y acepto esta autorización'),
          ),
          const SizedBox(height: Spacing.sm),
          BusyButton(
            label: 'Aceptar y continuar',
            busy: _busy,
            onPressed: _checked ? _accept : null,
          ),
          const SizedBox(height: Spacing.sm),
          TextButton(
            onPressed: _busy ? null : () => context.pop(),
            child: const Text('Ahora no'),
          ),
        ],
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.leading, required this.text});

  final String leading;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text(leading)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AcceptedNote extends StatelessWidget {
  const _AcceptedNote({required this.acceptedAt});

  final DateTime? acceptedAt;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final date = acceptedAt == null
        ? ''
        : ' el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(acceptedAt!)}';
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(
          Icons.verified_user_outlined,
          color: scheme.onPrimaryContainer,
        ),
        title: Text(
          'Aceptaste esta autorización$date.',
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
      ),
    );
  }
}
