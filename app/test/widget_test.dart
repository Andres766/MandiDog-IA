import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandidog/core/api/mandidog_api.dart';
import 'package:mandidog/features/capture/data/tooth_scanner.dart';
import 'package:mandidog/features/capture/presentation/scan_test_page.dart';
import 'package:mandidog/shared/widgets/vet_notice.dart';

/// API falsa con el comportamiento esencial de la real.
class FakeApi {
  bool consentAccepted = false;
  final submissions = <Map<String, dynamic>>[];

  Map<String, dynamic> get user => {
    'id': '00000000-0000-4000-8000-000000000001',
    'consent': {'current_version': '2026-11-v2', 'required': !consentAccepted},
  };

  MandiDogApi client() => MandiDogApi(
    baseUrl: 'http://api.test',
    devUser: 'prueba',
    client: MockClient(_handle),
  );

  Future<http.Response> _handle(http.Request request) async {
    expect(request.headers['X-Dev-User'], 'prueba');
    final path = '${request.method} ${request.url.path}';
    switch (path) {
      case 'GET /api/v1/me':
        return _json(user);
      case 'PUT /api/v1/me/consent':
        consentAccepted = true;
        return _json(user);
      case 'GET /api/v1/pets':
        return _json([
          {'id': '00000000-0000-4000-8000-000000000002', 'name': 'Toby'},
        ]);
      case 'POST /api/v1/analysis':
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        submissions.add(body);
        return _json({
          'analysis_id': 'a1',
          'risk_level': 'yellow',
          'provider_status': 'CAUTION',
          'findings': [
            {
              'code': 'inflammation',
              'name': 'Inflamación de encías',
              'status': 'abnormal',
            },
            {
              'code': 'calculus',
              'name': 'Sarro (cálculo dental)',
              'status': 'normal',
            },
          ],
          'sub_part': 'TLEFT',
          'model_version': 'aiforpet-scansdk-android/${body['sdk_version']}',
          'recommendation': 'Programa una revisión dental con tu veterinario.',
          'created_at': '2026-11-04T10:00:00Z',
        }, 201);
    }
    return _json({
      'error': {'code': 'not_found', 'message': 'No existe'},
    }, 404);
  }

  http.Response _json(Object body, [int status = 200]) => http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ToothScanner.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<void> open(
    WidgetTester tester,
    MandiDogApi api, {
    bool sdkAvailable = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ScanTestPage(
          api: api,
          scanner: ToothScanner(sdkKey: 'k'),
          sdkAvailable: sdkAvailable,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder scanButton(String label) => find.widgetWithText(FilledButton, label);

  testWidgets('sin autorización no se puede escanear', (tester) async {
    final api = FakeApi();
    await open(tester, api.client());

    expect(find.text(VetNotice.text), findsOneWidget);
    expect(
      tester.widget<FilledButton>(scanButton('Simular escaneo')).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('consent-checkbox')));
    await tester.pumpAndSettle();

    expect(api.consentAccepted, isTrue);
    expect(find.text('1. Autorización aceptada'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(scanButton('Simular escaneo')).onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'simulación: envía el ejemplo oficial a la API y muestra el resultado',
    (tester) async {
      final api = FakeApi()..consentAccepted = true;
      await open(tester, api.client());

      expect(find.byKey(const Key('simulation-notice')), findsOneWidget);
      await tester.tap(scanButton('Simular escaneo'));
      await tester.pumpAndSettle();

      final sent = api.submissions.single;
      expect(sent['sdk_version'], '2.2.3-simulacion');
      expect(sent['result']['petType'], 'DOG');
      expect(sent['result']['userId'], '00000000-0000-4000-8000-000000000001');
      expect(sent['client_scan_id'], matches(RegExp(r'^[0-9a-f-]{36}$')));

      expect(find.text('Amarillo · conviene vigilar'), findsOneWidget);
      expect(find.text('Inflamación de encías'), findsOneWidget);
      expect(find.text('Signos detectados'), findsOneWidget);
      expect(find.text(VetNotice.text), findsOneWidget);
    },
  );

  testWidgets('en Android usa la cámara real del SDK', (tester) async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'scanTeeth');
      return jsonEncode({
        'status': 'SUCCESS',
        'petType': 'DOG',
        'part': 'TOOTH',
        'response': {'status': 'CAUTION', 'symptoms': []},
      });
    });
    final api = FakeApi()..consentAccepted = true;
    await open(tester, api.client(), sdkAvailable: true);

    await tester.tap(scanButton('Escanear dientes'));
    await tester.pumpAndSettle();

    expect(api.submissions.single['sdk_version'], '2.2.3');
    expect(find.text('Amarillo · conviene vigilar'), findsOneWidget);
  });

  testWidgets('si la API no responde lo dice claramente', (tester) async {
    final api = MandiDogApi(
      baseUrl: 'http://api.test',
      devUser: 'prueba',
      client: MockClient((_) async => throw http.ClientException('sin red')),
    );
    await open(tester, api);

    expect(
      find.textContaining('No se pudo conectar con la API'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text(VetNotice.text), findsOneWidget);
  });
}
