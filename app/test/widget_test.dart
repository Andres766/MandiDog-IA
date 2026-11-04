import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mandidog/features/capture/data/tooth_scanner.dart';
import 'package:mandidog/features/capture/presentation/scan_test_page.dart';
import 'package:mandidog/shared/widgets/vet_notice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(ToothScanner.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Widget app(ToothScanner scanner) =>
      MaterialApp(home: ScanTestPage(scanner: scanner));

  testWidgets('el aviso del veterinario siempre está visible', (tester) async {
    await tester.pumpWidget(app(ToothScanner(sdkKey: 'k')));
    expect(find.text(VetNotice.text), findsOneWidget);
  });

  testWidgets('sin clave del SDK muestra cómo configurarla', (tester) async {
    await tester.pumpWidget(app(ToothScanner(sdkKey: '')));
    await tester.tap(find.text('Escanear dientes'));
    await tester.pump();
    expect(find.textContaining('AIFORPET_SDK_KEY'), findsOneWidget);
  });

  testWidgets('muestra el semáforo del resultado y mantiene el aviso', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      return jsonEncode({
        'status': 'SUCCESS',
        'petType': 'DOG',
        'part': 'TOOTH',
        'response': {'status': 'WARNING', 'symptoms': []},
      });
    });

    await tester.pumpWidget(app(ToothScanner(sdkKey: 'k')));
    await tester.tap(find.text('Escanear dientes'));
    await tester.pumpAndSettle();

    expect(find.text('Rojo · consultar pronto'), findsOneWidget);
    expect(find.text(VetNotice.text), findsOneWidget);
  });

  testWidgets('cancelar la cámara no muestra resultado', (tester) async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    await tester.pumpWidget(app(ToothScanner(sdkKey: 'k')));
    await tester.tap(find.text('Escanear dientes'));
    await tester.pumpAndSettle();

    expect(find.text('Escaneo cancelado.'), findsOneWidget);
  });
}
