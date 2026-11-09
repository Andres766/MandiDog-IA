import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/page_body.dart';
import '../../shared/widgets/states.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar tu cuenta?'),
        content: const Text(
          'Se borrarán tus perros y todo su historial en MandiDog. Esta acción no se puede '
          'deshacer. Los datos que conserve AI for Pet se eliminan según su propio '
          'procedimiento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiProvider).deleteAccount();
      await ref.read(authServiceProvider).signOut();
    } catch (e) {
      if (context.mounted) showMessage(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(meProvider);
    final auth = ref.watch(authServiceProvider);
    final user = auth.currentUser;
    final consent = me.value?.consent;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: PageBody(
        children: [
          _ProfileHeader(
            name: user?.displayName ?? me.value?.displayName ?? 'Tu cuenta',
            detail: auth.isDev
                ? 'Usuario de prueba (modo desarrollo)'
                : (user?.email ?? ''),
          ),
          const SectionTitle('Privacidad'),
          Card(
            child: ListTile(
              leading: const _RowIcon(Icons.privacy_tip_outlined),
              title: const Text('Autorización de datos'),
              subtitle: Text(switch (consent) {
                null => 'Cargando…',
                _ when consent.required => 'Pendiente: necesaria para escanear',
                _ => 'Aceptada · versión ${consent.acceptedVersion}',
              }),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/consent'),
            ),
          ),
          if (me.value?.canValidate == true) ...[
            const SectionTitle('Veterinario'),
            Card(
              child: ListTile(
                leading: const _RowIcon(Icons.fact_check_outlined),
                title: const Text('Validación clínica'),
                subtitle: const Text(
                  'Valora casos a ciegas y mira la concordancia',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/validation'),
              ),
            ),
          ],
          const SectionTitle('Sesión'),
          Card(
            child: ListTile(
              leading: const _RowIcon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => ref.read(authServiceProvider).signOut(),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Card(
            child: ListTile(
              leading: const _RowIcon(Icons.delete_forever_outlined),
              title: const Text('Eliminar mi cuenta'),
              subtitle: const Text('Borra tus perros y su historial'),
              onTap: () => _deleteAccount(context, ref),
            ),
          ),
          const SectionTitle('Acerca de'),
          Row(
            children: [
              const BrandLogo(size: 48),
              const SizedBox(width: 12),
              const BrandWordmark(size: 20),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          const Text(
            'MandiDog IA es un proyecto de grado de Ingeniería de Software de la Universidad '
            'Cooperativa de Colombia, sede Pasto. El análisis lo hace AI for Pet con '
            'inteligencia artificial. Es orientativo y no es un diagnóstico: consulta '
            'siempre a tu veterinario.',
          ),
          const SizedBox(height: Spacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'MandiDog IA',
              ),
              child: const Text('Licencias de software'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del usuario con su inicial.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            ExcludeSemantics(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: scheme.primary,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleLarge),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      style: TextStyle(color: scheme.onSurfaceVariant),
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

class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: 20,
      backgroundColor: scheme.primaryContainer,
      child: Icon(icon, size: 20, color: scheme.primary),
    );
  }
}
