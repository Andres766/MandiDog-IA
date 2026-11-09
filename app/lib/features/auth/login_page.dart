import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_service.dart';
import '../../core/config.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/states.dart';
import 'auth_widgets.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authServiceProvider);
    return AuthScaffold(
      title: '¡Hola de nuevo!',
      subtitle: 'Entra para revisar la sonrisa de tus perros.',
      children: [
        if (auth is DevAuthService)
          _DevLogin(auth: auth)
        else
          const _FirebaseLogin(),
      ],
    );
  }
}

class _FirebaseLogin extends ConsumerStatefulWidget {
  const _FirebaseLogin();

  @override
  ConsumerState<_FirebaseLogin> createState() => _FirebaseLoginState();
}

class _FirebaseLoginState extends ConsumerState<_FirebaseLogin> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    await _run(
      () => ref
          .read(authServiceProvider)
          .signIn(email: _email.text, password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormError(_error),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: validateEmail,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: Spacing.md),
            PasswordField(controller: _password, onSubmitted: _submit),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push('/reset-password'),
                child: const Text('¿Olvidaste tu contraseña?'),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            BusyButton(
              label: 'Iniciar sesión',
              busy: _busy,
              onPressed: _submit,
            ),
            const OrDivider(),
            GoogleButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => ref.read(authServiceProvider).signInWithGoogle(),
                    ),
            ),
            const SizedBox(height: Spacing.lg),
            _SwitchLink(
              question: '¿No tienes cuenta?',
              action: 'Regístrate',
              onTap: _busy ? null : () => context.push('/register'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "¿No tienes cuenta? Regístrate" centrado al pie del formulario.
class _SwitchLink extends StatelessWidget {
  const _SwitchLink({
    required this.question,
    required this.action,
    required this.onTap,
  });

  final String question;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          question,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _DevLogin extends StatefulWidget {
  const _DevLogin({required this.auth});

  final DevAuthService auth;

  @override
  State<_DevLogin> createState() => _DevLoginState();
}

class _DevLoginState extends State<_DevLogin> {
  final _user = TextEditingController(text: AppConfig.devUser);
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    try {
      await widget.auth.signInAsDev(_user.text);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.tertiaryContainer,
            borderRadius: BorderRadius.circular(Spacing.radiusField),
          ),
          child: Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.construction_outlined,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'Modo desarrollo: la app no usa Firebase. Entra con un usuario de '
                    'prueba; la API debe estar en AUTH_MODE=dev.',
                    style: TextStyle(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        FormError(_error),
        TextField(
          controller: _user,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _enter(),
          decoration: const InputDecoration(
            labelText: 'Usuario de prueba',
            helperText: 'Letras, números, punto, guion o guion bajo',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        FilledButton(onPressed: _enter, child: const Text('Entrar')),
      ],
    );
  }
}
