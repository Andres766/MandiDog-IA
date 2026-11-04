import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandidog/app.dart';
import 'package:mandidog/core/api/mandidog_api.dart';
import 'package:mandidog/core/auth/auth_service.dart';
import 'package:mandidog/core/providers.dart';
import 'package:mandidog/features/capture/data/tooth_scanner.dart';
import 'package:mandidog/features/consent/consent_text.dart';

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
    'role': 'owner',
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

/// Monta la app completa con el backend falso.
Future<void> pumpApp(
  WidgetTester tester,
  FakeBackend backend, {
  AuthService? auth,
  bool sdkAvailable = false,
}) async {
  final authService = auth ?? DevAuthService(initialUser: 'ana');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        apiProvider.overrideWithValue(backend.api(authService)),
        sdkAvailableProvider.overrideWithValue(sdkAvailable),
        toothScannerProvider.overrideWithValue(
          ToothScanner(sdkKey: 'tt_pk_test_x'),
        ),
      ],
      retry: (_, _) => null,
      child: const MandiDogApp(),
    ),
  );
  await tester.pumpAndSettle();
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
  await tester.pumpAndSettle();
}

Future<void> tapWidget(WidgetTester tester, Finder finder) async {
  await bringIntoView(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
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
