import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/pet_tag.dart';
import '../../shared/widgets/states.dart';
import 'pet_widgets.dart';

/// Inicio: los perros del usuario con su último resultado.
class PetsPage extends ConsumerWidget {
  const PetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pets = ref.watch(petsProvider);
    final hasPets = pets.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis perros'),
        actions: [
          IconButton(
            tooltip: 'Mi cuenta',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/account'),
          ),
        ],
      ),
      floatingActionButton: hasPets
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/pets/new'),
              icon: const Icon(Icons.add),
              label: const Text('Agregar perro'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(meProvider);
          return ref.refresh(petsProvider.future);
        },
        child: switch (pets) {
          AsyncData(:final value) => _list(context, ref, value),
          AsyncError(:final error) => PageBody(
            children: [
              ErrorView(
                error: error,
                onRetry: () => ref.invalidate(petsProvider),
              ),
            ],
          ),
          _ => const LoadingView(),
        },
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, List<Pet> pets) {
    if (pets.isEmpty) {
      return PageBody(
        children: [
          const SizedBox(height: Spacing.lg),
          BlankTag(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu primer perro',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Cada perro tiene su placa, con su nombre y el resultado de su último '
                  'escaneo dental.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/pets/new'),
            icon: const Icon(Icons.add),
            label: const Text('Agregar perro'),
          ),
        ],
      );
    }
    return PageBody(
      children: [
        const _ConsentBanner(),
        for (final pet in pets) ...[
          PetTagCard(pet: pet, onTap: () => context.push('/pets/${pet.id}')),
          const SizedBox(height: 12),
        ],
        // Espacio para que el botón flotante no tape la última placa.
        const SizedBox(height: 88),
      ],
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
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            Spacing.md,
            Spacing.sm,
            Spacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    color: scheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'Para escanear necesitas aceptar la autorización de datos.',
                      style: TextStyle(color: scheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/consent'),
                  child: const Text('Revisar autorización'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
