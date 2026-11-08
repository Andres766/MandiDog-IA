import 'package:flutter/material.dart';

import '../../core/api/mandidog_api.dart';
import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';

/// Mensaje en español para cualquier error esperado.
String friendlyError(Object error) => switch (error) {
  ApiException(:final message) => message,
  AuthException(:final message) => message,
  _ => 'Ocurrió un error inesperado. Inténtalo de nuevo.',
};

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.xl,
        horizontal: Spacing.md,
      ),
      child: Column(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 40, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (action != null) ...[const SizedBox(height: Spacing.lg), action!],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).isOffline;
    return EmptyState(
      icon: offline ? Icons.cloud_off_outlined : Icons.error_outline,
      title: offline ? 'Sin conexión con el servidor' : 'Algo salió mal',
      message: friendlyError(error),
      action: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Cargando…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: label,
        child: const Padding(
          padding: EdgeInsets.all(Spacing.xl),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
