import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandidog/features/capture/data/tooth_scanner.dart';

const _officialResult = {
  'status': 'SUCCESS',
  'petType': 'DOG',
  'part': 'TOOTH',
  'subPart': 'TCENTER',
  'response': {
    'status': 'CAUTION',
    'symptoms': [
      {'code': 'inflammation', 'abnormLevel': 1},
      {'code': 'calculus', 'abnormLevel': 0},
    ],
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ToothScanner.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockNative(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('envía al código nativo solo la clave y los identificadores', () async {
    MethodCall? received;
    mockNative((call) async {
      received = call;
      return jsonEncode(_officialResult);
    });

    await ToothScanner(
      sdkKey: 'tt_pk_test_x',
    ).scan(userId: 'u-1', petId: 'p-1');

    expect(received!.method, 'scanTeeth');
    expect(received!.arguments, {
      'sdkKey': 'tt_pk_test_x',
      'userId': 'u-1',
      'petId': 'p-1',
    });
  });

  test('devuelve el JSON del SDK sin modificarlo', () async {
    final raw = jsonEncode(_officialResult);
    mockNative((_) async => raw);

    final result = await ToothScanner(
      sdkKey: 'k',
    ).scan(userId: 'u', petId: 'p');

    expect(result!.raw, raw);
    expect(result.json['part'], 'TOOTH');
    expect(result.providerStatus, 'CAUTION');
  });

  test('si el usuario cierra la cámara devuelve null', () async {
    mockNative((_) async => null);
    expect(
      await ToothScanner(sdkKey: 'k').scan(userId: 'u', petId: 'p'),
      isNull,
    );
  });

  test('sin clave no abre la cámara', () async {
    var called = false;
    mockNative((_) async => called = true);

    expect(
      () => ToothScanner(sdkKey: '').scan(userId: 'u', petId: 'p'),
      throwsA(
        isA<ToothScannerException>().having(
          (e) => e.code,
          'code',
          'missing_sdk_key',
        ),
      ),
    );
    expect(called, isFalse);
  });

  test('un error nativo se convierte en ToothScannerException', () async {
    mockNative(
      (_) async =>
          throw PlatformException(code: 'sdk_launch_failed', message: 'x'),
    );
    expect(
      () => ToothScanner(sdkKey: 'k').scan(userId: 'u', petId: 'p'),
      throwsA(
        isA<ToothScannerException>().having(
          (e) => e.code,
          'code',
          'sdk_launch_failed',
        ),
      ),
    );
  });

  for (final raw in ['no es json', '[1, 2]']) {
    test('resultado con formato inesperado: $raw', () async {
      mockNative((_) async => raw);
      expect(
        () => ToothScanner(sdkKey: 'k').scan(userId: 'u', petId: 'p'),
        throwsA(
          isA<ToothScannerException>().having(
            (e) => e.code,
            'code',
            'invalid_result',
          ),
        ),
      );
    });
  }
}
