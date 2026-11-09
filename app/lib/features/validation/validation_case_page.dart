import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_style.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/states.dart';
import '../pets/pet_widgets.dart';

/// Valoración a ciegas de un caso: primero el veterinario decide, luego se revela la IA.
class ValidationCasePage extends ConsumerStatefulWidget {
  const ValidationCasePage({super.key, required this.analysisId});

  final String analysisId;

  @override
  ConsumerState<ValidationCasePage> createState() => _ValidationCasePageState();
}

class _ValidationCasePageState extends ConsumerState<ValidationCasePage> {
  final _notes = TextEditingController();
  PendingCase? _case;
  VetAssessment? _assessment;
  ValidationReveal? _reveal;
  bool _sending = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final assessment = _assessment;
    if (assessment == null || _sending) return;
    setState(() => _sending = true);
    try {
      final reveal = await ref
          .read(apiProvider)
          .submitValidation(widget.analysisId, assessment, _notes.text);
      if (!mounted) return;
      setState(() => _reveal = reveal);
      ref.invalidate(pendingCasesProvider);
      ref.invalidate(validationSummaryProvider);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _next() async {
    final pending = await ref.read(pendingCasesProvider.future);
    if (!mounted) return;
    final next = pending
        .where((c) => c.analysisId != widget.analysisId)
        .firstOrNull;
    if (next == null) {
      context.pop();
      showMessage(context, 'No quedan casos pendientes.');
    } else {
      context.pushReplacement('/validation/${next.analysisId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Se guarda el caso: al valorarlo sale de la lista de pendientes.
    final cases = ref.watch(pendingCasesProvider);
    _case ??= cases.value
        ?.where((c) => c.analysisId == widget.analysisId)
        .firstOrNull;
    final item = _case;

    return Scaffold(
      appBar: AppBar(title: const Text('Valorar caso')),
      body: switch (cases) {
        _ when item != null => _body(item),
        AsyncValue(:final error?) => PageBody(
          children: [
            ErrorView(
              error: error,
              onRetry: () => ref.invalidate(pendingCasesProvider),
            ),
          ],
        ),
        AsyncValue(hasValue: true) => const PageBody(
          children: [
            EmptyState(
              icon: Icons.task_alt,
              title: 'Caso ya valorado',
              message: 'Este caso ya no está pendiente.',
            ),
          ],
        ),
        _ => const LoadingView(label: 'Cargando caso…'),
      },
    );
  }

  Widget _body(PendingCase item) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reveal = _reveal;
    final details = [
      item.breed?.trim().isNotEmpty == true
          ? item.breed!
          : 'Raza sin registrar',
      ?item.positionLabel,
      formatDateTime(item.createdAt),
    ].join(' · ');

    return PageBody(
      children: [
        Text(item.petName, style: text.headlineSmall),
        const SizedBox(height: Spacing.xs),
        Text(details, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: Spacing.md),
        if (item.photoUrls.isEmpty)
          Text(
            'Este escaneo no tiene fotos disponibles. Si no puedes valorarlo, '
            'marca "No evaluable".',
            style: TextStyle(color: scheme.onSurfaceVariant),
          )
        else
          for (final url in item.photoUrls) ...[
            _CasePhoto(url: url),
            const SizedBox(height: Spacing.sm),
          ],
        if (reveal == null) ...[
          const SectionTitle('¿Qué observas?'),
          RadioGroup<VetAssessment>(
            groupValue: _assessment,
            onChanged: (value) {
              if (!_sending) setState(() => _assessment = value);
            },
            child: Card(
              child: Column(
                children: [
                  for (final (i, option) in VetAssessment.values.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    RadioListTile<VetAssessment>(
                      value: option,
                      title: Text(option.label),
                      subtitle: Text(option.help),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          TextField(
            controller: _notes,
            enabled: !_sending,
            maxLength: 1000,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notas (opcional)',
              helperText: 'Por ejemplo, qué viste o por qué no es evaluable.',
            ),
          ),
          const SizedBox(height: Spacing.md),
          FilledButton.icon(
            onPressed: _assessment == null || _sending ? null : _submit,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Registrar valoración'),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Después de registrarla verás lo que dijo la IA. La valoración no se puede '
            'cambiar.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ] else ...[
          const SectionTitle('Resultado'),
          _RevealCard(reveal: reveal),
          const SizedBox(height: Spacing.lg),
          FilledButton.icon(
            onPressed: _next,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Siguiente caso'),
          ),
          const SizedBox(height: Spacing.sm),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Volver a la lista'),
          ),
        ],
      ],
    );
  }
}

class _CasePhoto extends StatelessWidget {
  const _CasePhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(Spacing.radius),
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            semanticLabel: 'Foto de los dientes del caso',
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const LoadingView(label: 'Cargando foto…'),
            errorBuilder: (context, _, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.md),
                child: Text(
                  'No se pudo cargar la foto. El enlace de AI for Pet puede haber '
                  'vencido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealCard extends StatelessWidget {
  const _RevealCard({required this.reveal});

  final ValidationReveal reveal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ai = RiskStyle.of(context, reveal.aiRiskLevel);
    final (verdict, explanation) = switch (reveal.agreement) {
      true => ('Coinciden', 'Tu valoración y la de la IA concuerdan.'),
      false => ('No coinciden', 'Tu valoración y la de la IA son distintas.'),
      null => (
        'No cuenta en la concordancia',
        'Los casos no evaluables quedan fuera de la matriz.',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(verdict, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text(explanation, style: TextStyle(color: scheme.onSurfaceVariant)),
            const Divider(height: Spacing.xl),
            Text(
              'Tu valoración',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              reveal.assessment.label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Spacing.md),
            Text('La IA', style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: Spacing.xs),
            RiskBadge(level: reveal.aiRiskLevel),
            const SizedBox(height: Spacing.xs),
            Text(
              reveal.aiSeesSigns
                  ? 'Vio signos dentales (${ai.short.toLowerCase()}).'
                  : 'No vio signos dentales.',
            ),
          ],
        ),
      ),
    );
  }
}
