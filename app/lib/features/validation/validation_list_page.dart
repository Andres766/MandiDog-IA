import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/states.dart';
import '../pets/pet_widgets.dart';

/// Casos que el veterinario aún no ha valorado. No muestra nada del resultado de la IA.
class ValidationListPage extends ConsumerWidget {
  const ValidationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final cases = ref.watch(pendingCasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Validación clínica'),
        actions: [
          IconButton(
            tooltip: 'Resumen de concordancia',
            icon: const Icon(Icons.table_chart_outlined),
            onPressed: () => context.push('/validation/summary'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingCasesProvider.future),
        child: switch (cases) {
          AsyncValue(:final value?) => PageBody(
            children: [
              Text(
                'Valora cada caso mirando solo las fotos. El resultado de la IA se '
                'muestra después de registrar tu valoración, para no influir en ella.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              if (value.isEmpty)
                EmptyState(
                  icon: Icons.task_alt,
                  title: 'No hay casos pendientes',
                  message:
                      'Ya valoraste todos los escaneos registrados. Vuelve cuando haya '
                      'escaneos nuevos.',
                  action: OutlinedButton.icon(
                    onPressed: () => context.push('/validation/summary'),
                    icon: const Icon(Icons.table_chart_outlined),
                    label: const Text('Ver resumen'),
                  ),
                )
              else ...[
                SectionTitle(
                  value.length == 1
                      ? '1 caso pendiente'
                      : '${value.length} casos pendientes',
                ),
                Card(
                  child: Column(
                    children: [
                      for (final (i, c) in value.indexed) ...[
                        if (i > 0) const Divider(height: 1),
                        _CaseTile(item: c),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
          AsyncValue(:final error?) => PageBody(
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(pendingCasesProvider),
              ),
            ],
          ),
          _ => const LoadingView(label: 'Cargando casos…'),
        },
      ),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.item});

  final PendingCase item;

  @override
  Widget build(BuildContext context) {
    final details = [
      item.breed?.trim().isNotEmpty == true
          ? item.breed!
          : 'Raza sin registrar',
      ?item.positionLabel,
    ].join(' · ');
    final photos = item.photoUrls.length == 1
        ? '1 foto'
        : '${item.photoUrls.length} fotos';
    return ListTile(
      minVerticalPadding: Spacing.sm + 4,
      title: Text(item.petName),
      subtitle: Text('$details\n$photos · ${formatDateTime(item.createdAt)}'),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/validation/${item.analysisId}'),
    );
  }
}
