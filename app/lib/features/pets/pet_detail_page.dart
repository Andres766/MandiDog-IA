import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/states.dart';
import 'pet_widgets.dart';

/// Ficha del perro: datos, botón de escaneo e historial.
class PetDetailPage extends ConsumerWidget {
  const PetDetailPage({super.key, required this.petId});

  final String petId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(petProvider(petId));
    return switch (pet) {
      AsyncData(:final value) => _Detail(pet: value),
      AsyncError(:final error) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          error: error,
          onRetry: () => ref.invalidate(petProvider(petId)),
        ),
      ),
      _ => Scaffold(appBar: AppBar(), body: const LoadingView()),
    };
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.pet});

  final Pet pet;

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final scanPath = '/pets/${pet.id}/scan';
    try {
      final me = await ref.read(meProvider.future);
      if (!context.mounted) return;
      if (me.consent.required) {
        context.push('/consent?next=${Uri.encodeComponent(scanPath)}');
      } else {
        context.push(scanPath);
      }
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }

  void _open(BuildContext context, Analysis analysis) =>
      context.push('/pets/${pet.id}/analyses/${analysis.id}', extra: analysis);

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar a ${pet.name}?'),
        content: const Text(
          'Se borrarán sus datos y todo su historial de escaneos. Esta acción no se puede '
          'deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).deletePet(pet.id);
      ref.invalidate(petsProvider);
      if (context.mounted) {
        showMessage(context, '${pet.name} fue eliminado.');
        context.go('/');
      }
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider(pet.id));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (value) => switch (value) {
              'edit' => context.push('/pets/${pet.id}/edit'),
              'delete' => _delete(context, ref),
              _ => null,
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          refreshPetData(ref, pet.id);
          await ref.read(historyProvider(pet.id).future);
        },
        child: PageBody(
          children: [
            const SizedBox(height: Spacing.sm),
            PetTagCard(pet: pet, onTap: null, large: true),
            if (pet.sex != PetSex.unknown || pet.birthDate != null) ...[
              const SizedBox(height: Spacing.sm),
              Text(
                [
                  if (pet.sex != PetSex.unknown) pet.sex.label,
                  if (pet.birthDate != null)
                    'Nació el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(pet.birthDate!)}',
                ].join(' · '),
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: Spacing.lg),
            FilledButton.icon(
              onPressed: () => _scan(context, ref),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Escanear dientes'),
            ),
            const SectionTitle('Historial'),
            switch (history) {
              AsyncData(:final value) when value.isEmpty => const EmptyState(
                icon: Icons.photo_camera_outlined,
                title: 'Aún no hay escaneos',
                message: 'Toca «Escanear dientes» para hacer el primero.',
              ),
              AsyncData(:final value) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LatestScanCard(
                    analysis: value.first,
                    onTap: () => _open(context, value.first),
                  ),
                  if (value.length > 1) ...[
                    const SectionTitle('Escaneos anteriores'),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (i, analysis)
                              in value.skip(1).indexed) ...[
                            if (i > 0) const Divider(height: 1),
                            HistoryTile(
                              analysis: analysis,
                              onTap: () => _open(context, analysis),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              AsyncError(:final error) => ErrorView(
                error: error,
                onRetry: () => ref.invalidate(historyProvider(pet.id)),
              ),
              _ => const LoadingView(label: 'Cargando historial…'),
            },
          ],
        ),
      ),
    );
  }
}
