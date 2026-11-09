import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandidog/app.dart';
import 'package:mandidog/core/api/mandidog_api.dart';
import 'package:mandidog/core/auth/auth_service.dart';
import 'package:mandidog/core/local_store.dart';
import 'package:mandidog/core/providers.dart';
import 'package:mandidog/features/capture/data/tooth_scanner.dart';
import 'package:mandidog/features/consent/consent_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kUserId = '00000000-0000-4000-8000-000000000001';

/// API falsa con estado: reproduce el comportamiento esencial de la API real
/// (autorización, mascotas, historial y registro idempotente de escaneos).
class FakeBackend {
  String currentPolicyVersion = kConsentVersion;
  String? acceptedVersion;
  final pets = <Map<String, dynamic>>[];
  final analyses = <String, List<Map<String, dynamic>>>{};
  final submissions = <Map<String, dynamic>>[];
  bool failNextSubmit = false;
  bool accountDeleted = false;
  String role = 'owner';
  final pendingCases = <Map<String, dynamic>>[];
  final validations = <Map<String, dynamic>>[];

  /// Caso pendiente de validación; [aiStatus] es lo que la API revela al final.
  Map<String, dynamic> addPendingCase(
    String petName, {
    String aiStatus = 'WARNING',
    String? breed,
  }) {
    final item = {
      'analysis_id': '00000000-0000-4000-8000-0000000002${_ids++}',
      'created_at': '2026-11-04T15:00:00Z',
      'sub_part': 'TCENTER',
      'pet_name': petName,
      'breed': breed,
      'sex': 'unknown',
      'birth_date': null,
      'photo_urls': <String>[],
      '_ai_status': aiStatus,
    };
    pendingCases.add(item);
    return item;
  }

  int _ids = 10;

  void acceptConsent() => acceptedVersion = currentPolicyVersion;

  Map<String, dynamic> addPet(String name, {String? lastRiskLevel}) {
    final pet = {
      'id': '00000000-0000-4000-8000-0000000000${_ids++}',
      'name': name,
      'breed': null,
      'sex': 'unknown',
      'birth_date': null,
      'weight_kg': null,
      'created_at': '2026-11-01T10:00:00Z',
      'updated_at': '2026-11-01T10:00:00Z',
      'last_analysis': lastRiskLevel == null
          ? null
          : {'risk_level': lastRiskLevel, 'created_at': '2026-11-02T10:00:00Z'},
    };
    pets.add(pet);
    return pet;
  }

  MandiDogApi api(AuthService auth) => MandiDogApi(
    baseUrl: 'http://api.test',
    idToken: auth.idToken,
    devUser: () => auth.devUserHeader,
    client: MockClient(_handle),
  );

  Map<String, dynamic> get _me => {
    'id': kUserId,
    'email': null,
    'display_name': 'ana',
    'role': role,
    'consent': {
      'current_version': currentPolicyVersion,
      'accepted_version': acceptedVersion,
      'accepted_at': acceptedVersion == null ? null : '2026-11-04T10:00:00Z',
      'required': acceptedVersion != currentPolicyVersion,
    },
  };

  Future<http.Response> _handle(http.Request request) async {
    final path = request.url.path;
    final body = request.body.isEmpty ? null : jsonDecode(request.body);
    final route = '${request.method} $path';

    if (route == 'GET /api/v1/me') return _json(_me);
    if (route == 'PUT /api/v1/me/consent') {
      if (body['policy_version'] != currentPolicyVersion) {
        return _error(
          409,
          'consent_policy_outdated',
          'El texto de autorización cambió.',
        );
      }
      acceptedVersion = currentPolicyVersion;
      return _json(_me);
    }
    if (route == 'DELETE /api/v1/me/consent') {
      acceptedVersion = null;
      return http.Response('', 204);
    }
    if (route == 'DELETE /api/v1/me') {
      accountDeleted = true;
      return http.Response('', 204);
    }
    if (path.startsWith('/api/v1/validations') ||
        path.endsWith('/validation')) {
      if (role == 'owner') {
        return _error(403, 'vet_only', 'Solo para veterinarios.');
      }
      return _validation(route, path, body);
    }
    if (route == 'GET /api/v1/pets') return _json(pets);
    if (route == 'POST /api/v1/pets') {
      final pet = addPet(body['name'] as String)
        ..addAll(body as Map<String, dynamic>);
      return _json(pet, 201);
    }
    final petMatch = RegExp(
      r'^/api/v1/pets/([^/]+)(/analyses)?$',
    ).firstMatch(path);
    if (petMatch != null) {
      final id = petMatch.group(1)!;
      final pet = pets.where((p) => p['id'] == id).firstOrNull;
      if (pet == null) {
        return _error(404, 'pet_not_found', 'No encontramos esa mascota.');
      }
      if (petMatch.group(2) != null) return _json(analyses[id] ?? []);
      switch (request.method) {
        case 'GET':
          return _json(pet);
        case 'PATCH':
          pet.addAll(body as Map<String, dynamic>);
          return _json(pet);
        case 'DELETE':
          pets.remove(pet);
          return http.Response('', 204);
      }
    }
    if (route == 'POST /api/v1/analysis') {
      submissions.add(body as Map<String, dynamic>);
      if (failNextSubmit) {
        failNextSubmit = false;
        throw http.ClientException('sin red');
      }
      return _json(_registerScan(body), 201);
    }
    return _error(404, 'not_found', 'Ruta no simulada: $route');
  }

  http.Response _validation(String route, String path, Object? body) {
    if (route == 'GET /api/v1/validations/pending') {
      return _json([
        for (final c in pendingCases)
          {...c}..removeWhere((k, _) => k.startsWith('_')),
      ]);
    }
    if (route == 'GET /api/v1/validations/summary') {
      final evaluable = validations
          .where((v) => v['agreement'] != null)
          .toList();
      int count(bool aiSigns, bool vetSigns) => evaluable
          .where(
            (v) =>
                v['ai_sees_signs'] == aiSigns &&
                (v['vet_assessment'] == 'con_signos') == vetSigns,
          )
          .length;
      final tp = count(true, true), fn = count(false, true);
      final fp = count(true, false), tn = count(false, false);
      double? ratio(int a, int b) => b == 0 ? null : a / b;
      final matrix = {
        'n': evaluable.length,
        'true_positive': tp,
        'false_positive': fp,
        'false_negative': fn,
        'true_negative': tn,
        'sensitivity': ratio(tp, tp + fn),
        'specificity': ratio(tn, tn + fp),
        'accuracy': ratio(tp + tn, evaluable.length),
      };
      return _json({
        'validations': validations.length,
        'not_evaluable': validations.length - evaluable.length,
        'criterion': 'La IA "ve signos" cuando su estado no es NORMAL.',
        'overall': matrix,
        'by_cephalic_group': {if (evaluable.isNotEmpty) 'Braquicéfalo': matrix},
        'by_breed': {if (evaluable.isNotEmpty) 'Pug': matrix},
      });
    }
    final match = RegExp(
      r'^/api/v1/analyses/([^/]+)/validation$',
    ).firstMatch(path);
    if (match != null && route.startsWith('POST')) {
      final item = pendingCases
          .where((c) => c['analysis_id'] == match.group(1))
          .firstOrNull;
      if (item == null) {
        return _error(409, 'already_validated', 'Ya valoraste este caso.');
      }
      pendingCases.remove(item);
      final status = item['_ai_status'] as String;
      final data = body! as Map<String, dynamic>;
      final assessment = data['vet_assessment'];
      final aiSigns = status != 'NORMAL';
      final reveal = {
        'validation_id': '00000000-0000-4000-8000-0000000003${_ids++}',
        'vet_assessment': assessment,
        'ai_risk_level': const {
          'NORMAL': 'green',
          'CAUTION': 'yellow',
          'WARNING': 'red',
        }[status],
        'ai_provider_status': status,
        'ai_sees_signs': aiSigns,
        'agreement': assessment == 'no_evaluable'
            ? null
            : aiSigns == (assessment == 'con_signos'),
      };
      validations.add({...reveal, 'notes': data['notes']});
      return _json(reveal, 201);
    }
    return _error(404, 'not_found', 'Ruta no simulada: $route');
  }

  Map<String, dynamic> _registerScan(Map<String, dynamic> body) {
    final petId = body['pet_id'] as String;
    final list = analyses.putIfAbsent(petId, () => []);
    final previous = list.where(
      (a) => a['client_scan_id'] == body['client_scan_id'],
    );
    if (previous.isNotEmpty) return previous.first;

    final response = body['result']['response'] as Map<String, dynamic>;
    const names = {
      'calculus': 'Sarro (cálculo dental)',
      'inflammation': 'Inflamación de encías',
    };
    final analysis = {
      'analysis_id': '00000000-0000-4000-8000-0000000001${_ids++}',
      'client_scan_id': body['client_scan_id'],
      'risk_level': const {
        'NORMAL': 'green',
        'CAUTION': 'yellow',
        'WARNING': 'red',
      }[response['status']],
      'provider_status': response['status'],
      'findings': [
        for (final s in response['symptoms'] as List)
          {
            'code': s['code'],
            'name': names[s['code']] ?? s['code'],
            'status': (s['abnormLevel'] as int) > 0 ? 'abnormal' : 'normal',
          },
      ],
      'sub_part': body['result']['subPart'],
      'model_version': 'aiforpet-scansdk-android/${body['sdk_version']}',
      'recommendation':
          'Programa una revisión dental con tu veterinario. Este resultado es orientativo '
          'y no es un diagnóstico: consulta siempre a tu veterinario.',
      'created_at': '2026-11-04T15:00:00Z',
    };
    list.insert(0, analysis);
    return analysis;
  }

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );

  http.Response _error(int status, String code, String message) => _json({
    'error': {'code': code, 'message': message},
  }, status);
}

/// Espera a que la pantalla quede quieta. Las animaciones de entrada arrancan con
/// un temporizador de duración cero: si se crea en el último cuadro, pumpAndSettle
/// no lo dispara y la prueba terminaría con un temporizador pendiente (según la
/// velocidad de la máquina). Por eso se avanza un instante y se espera de nuevo.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pumpAndSettle();
}

/// Monta la app completa con el backend falso.
Future<void> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  AuthService? auth,
  bool sdkAvailable = false,
  bool onboardingSeen = true,
}) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': onboardingSeen});
  final authService = auth ?? DevAuthService(initialUser: 'ana');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiProvider.overrideWithValue(backend.api(authService)),
        sdkAvailableProvider.overrideWithValue(sdkAvailable),
        petPhotoStoreProvider.overrideWithValue(MemoryPetPhotoStore()),
        toothScannerProvider.overrideWithValue(
          ToothScanner(sdkKey: 'tt_pk_test_x'),
        ),
      ],
      retry: (_, _) => null,
      child: const MandiDogApp(),
    ),
  );
  await settle(tester);
  // Deja pasar la pantalla de arranque (dura 1,4 s).
  await tester.pump(const Duration(milliseconds: 1600));
  await settle(tester);
}

/// Desplaza la pantalla hasta que [finder] exista y sea visible. Los ListView solo
/// construyen lo que está cerca de la pantalla, como en un celular real.
Future<void> bringIntoView(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder.first);
  await settle(tester);
}

Future<void> tapWidget(WidgetTester tester, Finder finder) async {
  await bringIntoView(tester, finder);
  await tester.tap(finder.first);
  await settle(tester);
}

/// Abre la ficha de un perro desde el inicio. Su nombre aparece en la fila de
/// avatares (que solo lo selecciona) y en la tarjeta (que abre la ficha).
Future<void> openPet(WidgetTester tester, String name) async {
  await tapWidget(tester, find.text(name).last);
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapWidget(tester, find.text(text));

/// Comprueba que un texto aparece en la pantalla (desplazándose si hace falta).
Future<void> expectShown(WidgetTester tester, Finder finder) async {
  await bringIntoView(tester, finder);
  expect(finder, findsOneWidget);
}

/// Para pantallas largas: un teléfono alto.
void useTallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
}
