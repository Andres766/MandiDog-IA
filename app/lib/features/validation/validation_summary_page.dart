import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/states.dart';

final _percent = NumberFormat.decimalPercentPattern(
  locale: 'es',
  decimalDigits: 1,
);

String _metric(double? value) => value == null ? '—' : _percent.format(value);

/// Concordancia entre la IA y las valoraciones de los veterinarios (todas, no solo
/// las propias), con sensibilidad, especificidad y exactitud.
class ValidationSummaryPage extends ConsumerWidget {
  const ValidationSummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(validationSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Concordancia')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(validationSummaryProvider.future),
        child: switch (summary) {
          AsyncValue(:final value?) => _SummaryBody(summary: value),
          AsyncValue(:final error?) => PageBody(
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(validationSummaryProvider),
              ),
            ],
          ),
          _ => const LoadingView(label: 'Cargando resumen…'),
        },
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final ValidationSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(color: scheme.onSurfaceVariant);

    if (summary.validations == 0) {
      return const PageBody(
        children: [
          EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'Aún no hay valoraciones',
            message:
                'Cuando los veterinarios valoren casos, aquí verás cuánto coincide la '
                'IA con su criterio.',
          ),
        ],
      );
    }

    final evaluable = summary.overall.n;
    return PageBody(
      children: [
        Text(
          '${summary.validations} valoraciones · $evaluable evaluables · '
          '${summary.notEvaluable} no evaluables',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.xs),
        Text(summary.criterion, style: muted),
        const SectionTitle('Matriz de confusión'),
        _MatrixTable(matrix: summary.overall),
        const SizedBox(height: Spacing.md),
        _Metrics(matrix: summary.overall),
        const SectionTitle('Por biotipo cefálico'),
        _GroupList(groups: summary.byCephalicGroup),
        const SectionTitle('Por raza'),
        _GroupList(groups: summary.byBreed),
        const SizedBox(height: Spacing.md),
        Text(
          'Sensibilidad: de los casos en que el veterinario vio signos, cuántos marcó '
          'la IA. Especificidad: de los casos sin signos, cuántos dejó en verde. '
          'Exactitud: aciertos sobre el total evaluable. Con pocos casos estas cifras '
          'cambian mucho; "—" indica que aún no hay casos para calcularla.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Filas: veterinario (referencia). Columnas: IA.
class _MatrixTable extends StatelessWidget {
  const _MatrixTable({required this.matrix});

  final AgreementMatrix matrix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final header = TextStyle(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );

    Widget cell(String text, {TextStyle? style, String? semantics}) => Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.sm + 4,
      ),
      child: Semantics(
        label: semantics,
        excludeSemantics: semantics != null,
        child: Text(text, style: style),
      ),
    );

    Widget count(int value, String meaning) => cell(
      '$value',
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      semantics: '$meaning: $value',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              children: [
                cell('Veterinario \\ IA', style: header),
                cell('IA con signos', style: header),
                cell('IA sin signos', style: header),
              ],
            ),
            TableRow(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: scheme.outlineVariant),
                ),
              ),
              children: [
                cell('Con signos', style: header),
                count(matrix.truePositive, 'Verdaderos positivos'),
                count(matrix.falseNegative, 'Falsos negativos'),
              ],
            ),
            TableRow(
              children: [
                cell('Sin signos', style: header),
                count(matrix.falsePositive, 'Falsos positivos'),
                count(matrix.trueNegative, 'Verdaderos negativos'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.matrix});

  final AgreementMatrix matrix;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (label, value) in [
          ('Sensibilidad', matrix.sensitivity),
          ('Especificidad', matrix.specificity),
          ('Exactitud', matrix.accuracy),
        ])
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Spacing.md,
                  horizontal: Spacing.sm,
                ),
                child: MergeSemantics(
                  child: Column(
                    children: [
                      Text(
                        _metric(value),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: Spacing.xs),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.groups});

  final Map<String, AgreementMatrix> groups;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (groups.isEmpty) {
      return Text(
        'Sin casos evaluables todavía.',
        style: TextStyle(color: scheme.onSurfaceVariant),
      );
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.value.n.compareTo(a.value.n));
    return Card(
      child: Column(
        children: [
          for (final (i, e) in entries.indexed) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              title: Text(e.key),
              subtitle: Text(
                'Sensibilidad ${_metric(e.value.sensitivity)} · '
                'Especificidad ${_metric(e.value.specificity)} · '
                'Exactitud ${_metric(e.value.accuracy)}',
              ),
              trailing: Text(
                'n = ${e.value.n}',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
