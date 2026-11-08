import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/mandidog_api.dart';
import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_style.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/pet_tag.dart';
import '../../shared/widgets/states.dart';
import '../../shared/widgets/vet_notice.dart';
import '../pets/pet_widgets.dart';

/// Resultado de un escaneo. Recibe el análisis recién registrado o lo busca en el
/// historial (enlace directo o recarga en el navegador).
class ResultPage extends ConsumerWidget {
  const ResultPage({
    super.key,
    required this.petId,
    required this.analysisId,
    this.initial,
  });

  final String petId;
  final String analysisId;
  final Analysis? initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider(petId)).value;
    final petName = pet?.name;
    final AsyncValue<Analysis> analysis = initial != null
        ? AsyncData(initial!)
        : ref
              .watch(historyProvider(petId))
              .whenData(
                (list) => list.firstWhere(
                  (a) => a.id == analysisId,
                  orElse: () => throw const ApiException(
                    'analysis_not_found',
                    'No encontramos ese resultado.',
                  ),
                ),
              );

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      // El aviso queda fijo: no se puede cerrar ni desplazar fuera de la pantalla.
      bottomNavigationBar: const VetNotice(),
      body: switch (analysis) {
        AsyncData(:final value) => _Result(
          analysis: value,
          petId: petId,
          petName: petName,
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(historyProvider(petId)),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.analysis,
    required this.petId,
    required this.petName,
  });

  final Analysis analysis;
  final String petId;
  final String? petName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = RiskStyle.of(context, analysis.riskLevel);
    final meta = [
      formatDateTime(analysis.createdAt),
      analysis.positionLabel,
    ].whereType<String>().join(' · ');

    return PageBody(
      children: [
        if (petName != null) ...[
          TagChip(hue: TagHue.forId(petId), name: petName!),
          const SizedBox(height: Spacing.md),
        ],
        if (analysis.isSimulated) ...[
          Card(
            color: scheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(
                Icons.science_outlined,
                color: scheme.onTertiaryContainer,
              ),
              title: Text(
                'Resultado simulado: es el ejemplo oficial de AI for Pet, no un análisis '
                'real de tu perro.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
        Semantics(
          container: true,
          label:
              'Resultado: nivel ${style.short}, ${style.label}. ${style.description}',
          excludeSemantics: true,
          child: Card(
            color: style.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Spacing.radius),
              side: BorderSide(color: style.foreground.withValues(alpha: 0.4)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: style.foreground,
                    child: Icon(style.icon, size: 40, color: style.background),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    style.label,
                    textAlign: TextAlign.center,
                    style: textTheme.headlineSmall?.copyWith(
                      color: style.foreground,
                    ),
                  ),
                  Text(
                    'Nivel ${style.short.toLowerCase()}',
                    style: TextStyle(
                      color: style.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Spacing.sm),
                  Text(
                    style.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: style.foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          meta,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SectionTitle('Lo que encontró el análisis'),
        if (analysis.findings.isEmpty)
          const Text('El análisis no reportó hallazgos específicos.')
        else
          for (final finding in analysis.findings)
            _FindingRow(finding: finding),
        const SectionTitle('Qué hacer ahora'),
        // El aviso del veterinario ya está fijo abajo: no se repite aquí.
        Text(
          analysis.recommendation.replaceAll(VetNotice.text, '').trim(),
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: Spacing.lg),
        Text(
          'Análisis hecho con inteligencia artificial por AI for Pet '
          '(${analysis.modelVersion}). MandiDog IA no reemplaza la valoración de un '
          'veterinario.',
          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: Spacing.lg),
        FilledButton(
          onPressed: () => context.go('/pets/$petId'),
          child: Text(petName == null ? 'Volver' : 'Volver a $petName'),
        ),
        const SizedBox(height: Spacing.sm),
        OutlinedButton.icon(
          onPressed: () => context.pushReplacement('/pets/$petId/scan'),
          icon: const Icon(Icons.photo_camera_outlined),
          label: const Text('Escanear otro lado'),
        ),
      ],
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (finding.status) {
      FindingStatus.abnormal => (Icons.warning_amber_rounded, scheme.error),
      FindingStatus.normal => (Icons.check_circle_outline, scheme.primary),
      FindingStatus.unknown => (Icons.help_outline, scheme.onSurfaceVariant),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Card(
        child: ListTile(
          leading: ExcludeSemantics(child: Icon(icon, color: color)),
          title: Text(finding.name),
          trailing: Text(
            finding.status.label,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ),
    );
  }
}
