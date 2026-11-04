import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  const AppUser({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;
}

/// Error de autenticación con mensaje en español para mostrar al usuario.
class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthService {
  bool get isDev;
  AppUser? get currentUser;

  /// Emite el usuario actual al suscribirse y cada vez que cambia.
  Stream<AppUser?> authStateChanges();

  Future<void> signIn({required String email, required String password});
  Future<void> register({
    required String name,
    required String email,
    required String password,
  });
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Token de Firebase para la API; null en modo desarrollo.
  Future<String?> idToken();

  /// Valor del header X-Dev-User; null con Firebase.
  String? get devUserHeader;
}

/// Modo desarrollo: sin Firebase. El "usuario" es un identificador que la API recibe en
/// X-Dev-User (la API debe estar en AUTH_MODE=dev, que nunca arranca en producción).
class DevAuthService implements AuthService {
  DevAuthService({String? initialUser})
    : _user = initialUser == null
          ? null
          : AppUser(uid: 'dev:$initialUser', displayName: initialUser);

  static final _valid = RegExp(r'^[A-Za-z0-9_.-]{1,64}$');

  AppUser? _user;
  final _changes = StreamController<AppUser?>.broadcast();

  @override
  bool get isDev => true;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() async* {
    yield _user;
    yield* _changes.stream;
  }

  /// Entra con un identificador de prueba (letras, números, punto, guion o guion bajo).
  Future<void> signInAsDev(String id) async {
    final value = id.trim();
    if (!_valid.hasMatch(value)) {
      throw const AuthException(
        'Usa solo letras, números, punto, guion o guion bajo (máximo 64).',
      );
    }
    _set(AppUser(uid: 'dev:$value', displayName: value));
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw const AuthException(
        'En modo desarrollo se entra con un usuario de prueba.',
      );

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) => throw const AuthException('El registro requiere Firebase.');

  @override
  Future<void> sendPasswordReset(String email) => throw const AuthException(
    'La recuperación de contraseña requiere Firebase.',
  );

  @override
  Future<void> signOut() async => _set(null);

  @override
  Future<String?> idToken() async => null;

  @override
  String? get devUserHeader => _user?.displayName;

  void _set(AppUser? user) {
    _user = user;
    _changes.add(user);
  }
}

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  static AppUser? _map(User? u) => u == null
      ? null
      : AppUser(uid: u.uid, email: u.email, displayName: u.displayName);

  @override
  bool get isDev => false;

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() => _auth.authStateChanges().map(_map);

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        ),
      );

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) => _guard(() async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(name.trim());
  });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();

  @override
  String? get devUserHeader => null;

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(messageFor(e.code));
    }
  }

  static String messageFor(String code) => switch (code) {
    'invalid-email' => 'El correo no tiene un formato válido.',
    'user-disabled' => 'Esta cuenta fue deshabilitada.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'El correo o la contraseña no son correctos.',
    'email-already-in-use' =>
      'Ya existe una cuenta con ese correo. Inicia sesión.',
    'weak-password' => 'La contraseña es muy débil. Usa al menos 8 caracteres.',
    'too-many-requests' =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
    'network-request-failed' =>
      'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
    _ => 'No pudimos completar la operación. Inténtalo de nuevo.',
  };
}
