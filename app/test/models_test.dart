import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mandidog/core/api/mandidog_api.dart';
import 'package:mandidog/core/api/models.dart';
import 'package:mandidog/core/theme/risk_style.dart';

void main() {
  group('Pet.ageLabel', () {
    final now = DateTime(2026, 11, 4);
    Pet born(DateTime d) => Pet(id: 'p', name: 'Toby', birthDate: d);

    test(
      'años',
      () => expect(born(DateTime(2023, 5, 1)).ageLabel(now), '3 años'),
    );
    test(
      'un año',
      () => expect(born(DateTime(2025, 10, 1)).ageLabel(now), '1 año'),
    );
    test(
      'meses',
      () => expect(born(DateTime(2026, 4, 4)).ageLabel(now), '7 meses'),
    );
    test('recién nacido', () {
      expect(born(DateTime(2026, 10, 20)).ageLabel(now), 'Menos de 1 mes');
    });
    test(
      'sin fecha',
      () => expect(const Pet(id: 'p', name: 'x').ageLabel(now), isNull),
    );
  });

  group('Analysis.fromJson', () {
    Map<String, dynamic> json(String version) => {
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
        {'code': 'nuevo', 'name': 'nuevo', 'status': 'unknown'},
      ],
      'sub_part': 'TLEFT',
      'model_version': version,
      'recommendation': 'x',
      'created_at': '2026-11-04T18:05:09Z',
    };

    test('interpreta nivel, hallazgos y posición', () {
      final a = Analysis.fromJson(json('aiforpet-scansdk-android/2.2.3'));
      expect(a.riskLevel, RiskLevel.yellow);
      expect(a.positionLabel, 'Dientes del lado izquierdo');
      expect(a.abnormalFindings.map((f) => f.code), ['inflammation']);
      expect(a.findings.last.status, FindingStatus.unknown);
      expect(a.isSimulated, isFalse);
    });

    test('reconoce los resultados simulados', () {
      expect(
        Analysis.fromJson(
          json('aiforpet-scansdk-android/2.2.3-simulacion'),
        ).isSimulated,
        isTrue,
      );
    });
  });

  group('MandiDogApi', () {
    MandiDogApi api(
      Future<http.Response> Function(http.Request) handler, {
      String? token,
    }) => MandiDogApi(
      baseUrl: 'http://api.test',
      idToken: () async => token,
      devUser: () => 'ana',
      client: MockClient(handler),
    );

    test('con token de Firebase usa Authorization y no X-Dev-User', () async {
      late http.Request seen;
      await api((r) async {
        seen = r;
        return http.Response('[]', 200);
      }, token: 'jwt').pets();
      expect(seen.headers['Authorization'], 'Bearer jwt');
      expect(seen.headers.containsKey('X-Dev-User'), isFalse);
    });

    test('muestra el mensaje en español que envía la API', () async {
      final call = api(
        (_) async => http.Response.bytes(
          utf8.encode(
            '{"error":{"code":"consent_required","message":"Debes aceptar…"}}',
          ),
          409,
        ),
      ).pets();
      await expectLater(
        call,
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'consent_required')
              .having((e) => e.message, 'message', 'Debes aceptar…'),
        ),
      );
    });

    test('error del servidor sin formato da un mensaje genérico', () async {
      await expectLater(
        api((_) async => http.Response('Bad Gateway', 502)).pets(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('servidor'),
          ),
        ),
      );
    });

    test('sin conexión', () async {
      await expectLater(
        api((_) async => throw http.ClientException('x')).pets(),
        throwsA(
          isA<ApiException>().having((e) => e.isOffline, 'isOffline', isTrue),
        ),
      );
    });
  });
}
