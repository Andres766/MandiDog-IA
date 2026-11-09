import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/states.dart';
import 'pet_widgets.dart';
import 'pets_page.dart';

/// Ficha del perro: foto, datos, botón de revisión e historial.
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
      await ref.read(petPhotoStoreProvider).delete(pet.id);
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
    final hasPhoto = ref.watch(petPhotoProvider(pet.id)).value != null;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          refreshPetData(ref, pet.id);
          await ref.read(historyProvider(pet.id).future);
        },
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 300,
              backgroundColor: scheme.surface,
              actions: [
                PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  onSelected: (value) => switch (value) {
                    'photo' => choosePetPhoto(
                      context,
                      ref,
                      petId: pet.id,
                      hasPhoto: hasPhoto,
                    ),
                    'edit' => context.push('/pets/${pet.id}/edit'),
                    'delete' => _delete(context, ref),
                    _ => null,
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'photo',
                      child: ListTile(
                        leading: Icon(Icons.photo_camera_outlined),
                        title: Text('Cambiar foto'),
                      ),
                    ),
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
              // El nombre ya está en el encabezado: en la barra solo aparece al
              // desplazarse, cuando el encabezado se oculta.
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final top = MediaQuery.paddingOf(context).top;
                  final collapsed =
                      constraints.maxHeight <= kToolbarHeight + top + 24;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      FlexibleSpaceBar(
                        collapseMode: CollapseMode.parallax,
                        background: _Header(pet: pet, hasPhoto: hasPhoto),
                      ),
                      Positioned(
                        left: 64,
                        right: 64,
                        top: top,
                        height: kToolbarHeight,
                        child: ExcludeSemantics(
                          excluding: !collapsed,
                          child: AnimatedOpacity(
                            opacity: collapsed ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                pet.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(
                                  context,
                                ).appBarTheme.titleTextStyle,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: Spacing.maxContentWidth,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Spacing.md,
                      0,
                      Spacing.md,
                      Spacing.xl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _InfoChips(pet: pet).entrance(context),
                        const SizedBox(height: Spacing.lg),
                        FilledButton.icon(
                          onPressed: () => startScan(context, ref, pet.id),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Escanear dientes'),
                        ).entrance(context, index: 1),
                        const SectionTitle('Historial'),
                        switch (history) {
                          AsyncData(:final value) when value.isEmpty =>
                            const EmptyState(
                              icon: Icons.photo_camera_outlined,
                              title: 'Aún no hay escaneos',
                              message:
                                  'Toca «Escanear dientes» para hacer el primero.',
                            ),
                          AsyncData(:final value) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              LatestScanCard(
                                analysis: value.first,
                                onTap: () => _open(context, value.first),
                              ).entrance(context, index: 2),
                              if (value.length > 1) ...[
                                const SectionTitle('Escaneos anteriores'),
                                HistoryTimeline(
                                  analyses: value.skip(1).toList(),
                                  onOpen: (a) => _open(context, a),
                                ),
                              ],
                            ],
                          ),
                          AsyncError(:final error) => ErrorView(
                            error: error,
                            onRetry: () =>
                                ref.invalidate(historyProvider(pet.id)),
                          ),
                          _ => const LoadingView(label: 'Cargando historial…'),
                        },
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado: foto grande (con botón de cámara) sobre un degradado suave.
class _Header extends ConsumerWidget {
  const _Header({required this.pet, required this.hasPhoto});

  final Pet pet;
  final bool hasPhoto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final summary = petSummary(pet);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scheme.primaryContainer, scheme.surface],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: Spacing.lg),
            Stack(
              clipBehavior: Clip.none,
              children: [
                PetAvatar(petId: pet.id, name: pet.name, size: 128),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: IconButton.filled(
                    tooltip: hasPhoto ? 'Cambiar foto' : 'Agregar foto',
                    style: IconButton.styleFrom(
                      side: BorderSide(color: scheme.surface, width: 3),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined, size: 20),
                    onPressed: () => choosePetPhoto(
                      context,
                      ref,
                      petId: pet.id,
                      hasPhoto: hasPhoto,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            Text(
              pet.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (summary.isNotEmpty)
              Text(summary, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Sexo y nacimiento en píldoras.
class _InfoChips extends StatelessWidget {
  const _InfoChips({required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = [
      if (pet.sex != PetSex.unknown) (Icons.pets, pet.sex.label),
      if (pet.birthDate != null)
        (
          Icons.cake_outlined,
          'Nació el ${DateFormat("d 'de' MMMM 'de' y", 'es').format(pet.birthDate!)}',
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final (icon, label) in items)
          DecoratedBox(
            decoration: ShapeDecoration(
              color: scheme.surfaceContainerLowest,
              shape: StadiumBorder(
                side: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
