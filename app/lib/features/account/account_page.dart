import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(meProvider);
    final auth = ref.watch(authServiceProvider);
    final user = auth.currentUser;
    final consent = me.value?.consent;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: PageBody(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline, color: scheme.onSurfaceVariant),
            title: Text(
              user?.displayName ?? me.value?.displayName ?? 'Tu cuenta',
            ),
            subtitle: Text(
              auth.isDev
                  ? 'Usuario de prueba (modo desarrollo)'
                  : (user?.email ?? ''),
            ),
          ),
          const SectionTitle('Privacidad'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
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
                leading: const Icon(Icons.fact_check_outlined),
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
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () => ref.read(authServiceProvider).signOut(),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Eliminar mi cuenta'),
              subtitle: const Text('Borra tus perros y su historial'),
              onTap: () => _deleteAccount(context, ref),
            ),
          ),
          const SectionTitle('Acerca de'),
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
