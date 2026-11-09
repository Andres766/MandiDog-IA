import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/motion.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/pet_avatar.dart';
import '../../shared/widgets/risk_badge.dart';
import '../../shared/widgets/states.dart';
import 'pet_widgets.dart';

/// Abre el escaneo de un perro, pasando antes por la autorización si falta.
Future<void> startScan(
  BuildContext context,
  WidgetRef ref,
  String petId,
) async {
  final scanPath = '/pets/$petId/scan';
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

/// Inicio: saludo, los perros en una fila de avatares y la tarjeta del elegido.
class PetsPage extends ConsumerStatefulWidget {
  const PetsPage({super.key});

  @override
  ConsumerState<PetsPage> createState() => _PetsPageState();
}

class _PetsPageState extends ConsumerState<PetsPage> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final pets = ref.watch(petsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () {
            ref.invalidate(meProvider);
            return ref.refresh(petsProvider.future);
          },
          child: switch (pets) {
            AsyncData(:final value) => _content(value),
            AsyncError(:final error) => PageBody(
              children: [
                const _Greeting(),
                ErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(petsProvider),
                ),
              ],
            ),
            _ => const PageBody(children: [_Greeting(), _HomeSkeleton()]),
          },
        ),
      ),
    );
  }

  Widget _content(List<Pet> pets) {
    if (pets.isEmpty) {
      return PageBody(
        children: [
          const _Greeting(),
          const _ConsentBanner(),
          const _EmptyPets(),
        ],
      );
    }
    final selected =
        pets.where((p) => p.id == _selectedId).firstOrNull ?? pets.first;
    return PageBody(
      children: [
        const _Greeting().entrance(context),
        const _ConsentBanner(),
        Text(
          'Tus perros',
          style: Theme.of(context).textTheme.titleMedium,
        ).entrance(context, index: 1),
        const SizedBox(height: Spacing.sm + 4),
        _PetSelector(
          pets: pets,
          selectedId: selected.id,
          onSelect: (id) => setState(() => _selectedId = id),
        ).entrance(context, index: 1),
        const SizedBox(height: Spacing.lg),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _SelectedPetCard(key: ValueKey(selected.id), pet: selected),
        ).entrance(context, index: 2),
        const SizedBox(height: Spacing.md),
        const _TipCard().entrance(context, index: 3),
      ],
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final name = ref.watch(meProvider).value?.displayName?.trim();
    final first = name == null || name.isEmpty ? null : name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md, bottom: Spacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    first == null ? '¡Hola!' : '¡Hola, $first!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¿Cómo están esas sonrisas hoy?',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Mi cuenta',
            iconSize: 26,
            style: IconButton.styleFrom(
              minimumSize: const Size(52, 52),
              backgroundColor: scheme.surfaceContainerLowest,
              foregroundColor: scheme.onSurface,
              side: BorderSide(color: scheme.outlineVariant),
            ),
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
    );
  }
}

/// Fila de avatares (patrón de PetDesk) con el círculo "Agregar" al final.
class _PetSelector extends StatelessWidget {
  const _PetSelector({
    required this.pets,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Pet> pets;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 104,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (final pet in pets)
            _AvatarChoice(
              label: pet.name,
              selected: pet.id == selectedId,
              onTap: () => onSelect(pet.id),
              child: PetAvatar(
                petId: pet.id,
                name: pet.name,
                size: 68,
                hero: false,
                ring: pet.id == selectedId ? scheme.primary : null,
              ),
            ),
          _AvatarChoice(
            label: 'Agregar',
            selected: false,
            onTap: () => context.push('/pets/new'),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primaryContainer,
              ),
              child: Icon(Icons.add, color: scheme.primary, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  const _AvatarChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: Spacing.md),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Pressable(
          onTap: onTap,
          child: SizedBox(
            width: 72,
            child: Column(
              children: [
                child,
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
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

/// Tarjeta del perro elegido: foto, datos, último resultado y el botón de revisar.
class _SelectedPetCard extends ConsumerWidget {
  const _SelectedPetCard({super.key, required this.pet});

  final Pet pet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final summary = petSummary(pet);
    final last = pet.lastAnalysis;

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Spacing.radiusLg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.push('/pets/${pet.id}'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                Spacing.md,
                Spacing.sm,
                Spacing.md,
              ),
              child: Row(
                children: [
                  PetAvatar(petId: pet.id, name: pet.name, size: 76),
                  const SizedBox(width: Spacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineSmall,
                        ),
                        if (summary.isNotEmpty)
                          Text(
                            summary,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  Semantics(
                    label: 'Ver la ficha de ${pet.name}',
                    child: Icon(
                      Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Última revisión',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                if (last == null)
                  Text('Sin escaneos aún', style: text.titleMedium)
                else
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      RiskBadge(level: last.riskLevel),
                      Text(
                        relativeDay(last.createdAt),
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                const SizedBox(height: Spacing.md),
                FilledButton.icon(
                  onPressed: () => startScan(context, ref, pet.id),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Revisar sus dientes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Consejo de cuidado dental, cambia cada día.
class _TipCard extends StatelessWidget {
  const _TipCard();

  static const _tips = [
    'Cepilla sus dientes varias veces por semana con pasta para perros.',
    'Nunca uses pasta dental de personas: puede tener xilitol, que es tóxico '
        'para los perros.',
    'Los snacks y juguetes dentales ayudan, pero no reemplazan el cepillado.',
    'El mal aliento persistente es motivo para consultar al veterinario.',
    'Revisa sus encías: deben verse rosadas, sin enrojecimiento ni sangrado.',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final day = DateTime.now().difference(DateTime(2026)).inDays;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Spacing.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consejo',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tips[day % _tips.length],
                    style: TextStyle(color: scheme.onSecondaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPets extends StatelessWidget {
  const _EmptyPets();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget art = const SizedBox(
      height: 200,
      child: Illustration('assets/illustrations/empty_dogs.svg', circle: 0.5),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      art = art
          .animate()
          .fadeIn(duration: 400.ms)
          .scaleXY(begin: 0.9, end: 1, curve: Curves.easeOutBack);
    }
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          art,
          const SizedBox(height: Spacing.lg),
          Text(
            'Tu primer perro',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Agrégalo con su nombre y una foto para empezar a revisar su sonrisa.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/pets/new'),
            icon: const Icon(Icons.add),
            label: const Text('Agregar perro'),
          ),
        ],
      ).entrance(context),
    );
  }
}

/// Aviso si falta la autorización (sin ella no se puede escanear).
class _ConsentBanner extends ConsumerWidget {
  const _ConsentBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final required = ref.watch(meProvider).value?.consent.required ?? false;
    if (!required) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.lg),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(Spacing.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/consent'),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.privacy_tip_outlined,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Para escanear necesitas aceptar la autorización de datos.',
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
                Text(
                  'Revisar',
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
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

/// Esqueleto mientras cargan los perros.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget box(double w, double h, {double r = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(r),
      ),
    );
    Widget skeleton = Semantics(
      label: 'Cargando tus perros…',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(120, 18),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                box(68, 68, r: 34),
                const SizedBox(width: Spacing.md),
              ],
            ],
          ),
          const SizedBox(height: Spacing.lg),
          box(double.infinity, 220, r: Spacing.radiusLg),
        ],
      ),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      skeleton = skeleton
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: scheme.surfaceContainerLowest);
    }
    return skeleton;
  }
}
