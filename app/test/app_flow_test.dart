import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mandidog/core/auth/auth_service.dart';
import 'package:mandidog/features/capture/data/tooth_scanner.dart';
import 'package:mandidog/features/consent/consent_text.dart';
import 'package:mandidog/shared/widgets/vet_notice.dart';

import 'support/fake_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('acceso', () {
    testWidgets(
      'sin sesión pide entrar; en modo dev entra con un usuario de prueba',
      (tester) async {
        useTallPhone(tester);
        await pumpApp(tester, FakeBackend(), auth: DevAuthService());

        expect(find.textContaining('Modo desarrollo'), findsOneWidget);
        await tapText(tester, 'Entrar');

        expect(find.text('Mis perros'), findsOneWidget);
        expect(find.text('Agrega a tu primer perro'), findsOneWidget);
      },
    );

    testWidgets('cerrar sesión vuelve a la pantalla de acceso', (tester) async {
      useTallPhone(tester);
      await pumpApp(tester, FakeBackend());

      await tapWidget(tester, find.byTooltip('Mi cuenta'));
      await tapText(tester, 'Cerrar sesión');

      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('perros', () {
    testWidgets('agregar un perro valida el nombre y abre su ficha', (
      tester,
    ) async {
      useTallPhone(tester);
      final backend = FakeBackend();
      await pumpApp(tester, backend);

      await tapText(tester, 'Agregar perro');
      await tapText(tester, 'Guardar');
      expect(find.text('Escribe el nombre de tu perro.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre *'),
        'Toby',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Peso (kg)'),
        '8,5',
      );
      await tapText(tester, 'Guardar');

      expect(backend.pets.single['weight_kg'], 8.5);
      expect(find.text('Toby'), findsWidgets);
      expect(find.text('Aún no hay escaneos'), findsOneWidget);
    });

    testWidgets('peso inválido muestra el error junto al campo', (
      tester,
    ) async {
      useTallPhone(tester);
      await pumpApp(tester, FakeBackend());

      await tapText(tester, 'Agregar perro');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre *'),
        'Toby',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Peso (kg)'),
        '500',
      );
      await tapText(tester, 'Guardar');

      expect(find.text('El peso debe estar entre 0 y 120 kg.'), findsOneWidget);
    });

    testWidgets('la lista muestra el último resultado con texto, no solo color', (
      tester,
    ) async {
      useTallPhone(tester);
      final semantics = tester.ensureSemantics();
      final backend = FakeBackend()..addPet('Luna', lastRiskLevel: 'red');
      backend.addPet('Max');
      await pumpApp(tester, backend);

      expect(find.text('Consulta pronto'), findsOneWidget);
      // La tarjeta une su texto con el de la insignia en un solo nodo accesible.
      expect(
        find.bySemanticsLabel(RegExp('Nivel Rojo: Consulta pronto')),
        findsWidgets,
      );
      expect(find.text('Sin escaneos aún'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('eliminar un perro pide confirmación', (tester) async {
      useTallPhone(tester);
      final backend = FakeBackend()..addPet('Toby');
      await pumpApp(tester, backend);

      await tapText(tester, 'Toby');
      await tapWidget(tester, find.byTooltip('Más opciones'));
      await tapText(tester, 'Eliminar');
      expect(find.text('¿Eliminar a Toby?'), findsOneWidget);
      await tapWidget(tester, find.widgetWithText(TextButton, 'Eliminar'));

      expect(backend.pets, isEmpty);
      expect(find.text('Agrega a tu primer perro'), findsOneWidget);
    });
  });

  group('autorización de datos', () {
    testWidgets('sin autorización, escanear lleva primero a aceptarla', (
      tester,
    ) async {
      useTallPhone(tester);
      final backend = FakeBackend()..addPet('Toby');
      await pumpApp(tester, backend);

      expect(find.text('Revisar autorización'), findsOneWidget);
      await tapText(tester, 'Toby');
      await tapText(tester, 'Escanear dientes');

      expect(find.text('Autorización de datos'), findsOneWidget);
      final accept = find.widgetWithText(FilledButton, 'Aceptar y continuar');
      await bringIntoView(tester, accept);
      expect(tester.widget<FilledButton>(accept).onPressed, isNull);

      await tapText(tester, 'He leído y acepto esta autorización');
      await tapWidget(tester, accept);

      expect(backend.acceptedVersion, kConsentVersion);
      expect(find.text('Antes de empezar'), findsOneWidget);
    });

    testWidgets(
      'si el texto vigente cambió, la app desactualizada no puede aceptarlo',
      (tester) async {
        useTallPhone(tester);
        final backend = FakeBackend()
          ..currentPolicyVersion = '2027-01-v3'
          ..addPet('Toby');
        await pumpApp(tester, backend);

        await tapText(tester, 'Revisar autorización');

        await expectShown(tester, find.textContaining('Actualiza la app'));
        expect(find.text('He leído y acepto esta autorización'), findsNothing);
      },
    );

    testWidgets('se puede revocar desde la cuenta', (tester) async {
      useTallPhone(tester);
      final backend = FakeBackend()..acceptConsent();
      await pumpApp(tester, backend);

      await tapWidget(tester, find.byTooltip('Mi cuenta'));
      await tapText(tester, 'Autorización de datos');
      await tapText(tester, 'Revocar autorización');
      await tapWidget(tester, find.widgetWithText(TextButton, 'Revocar'));

      expect(backend.acceptedVersion, isNull);
    });
  });

  group('escaneo y resultado', () {
    testWidgets(
      'simulación: registra el ejemplo oficial y muestra el resultado',
      (tester) async {
        useTallPhone(tester);
        final backend = FakeBackend()..acceptConsent();
        backend.addPet('Toby');
        await pumpApp(tester, backend);

        await tapText(tester, 'Toby');
        await tapText(tester, 'Escanear dientes');
        expect(find.byKey(const Key('simulation-notice')), findsOneWidget);
        await tapText(tester, 'Simular escaneo');

        final sent = backend.submissions.single;
        expect(sent['sdk_version'], '2.2.3-simulacion');
        expect(sent['result']['petType'], 'DOG');
        expect(sent['result']['userId'], kUserId);

        expect(find.textContaining('Resultado simulado'), findsOneWidget);
        expect(find.text('Conviene vigilar'), findsOneWidget);
        expect(find.text(VetNotice.text), findsOneWidget);
        await expectShown(tester, find.text('Inflamación de encías'));
        await expectShown(tester, find.text('Signos detectados'));
        // El aviso del veterinario sigue visible al desplazarse: está fijo abajo.
        expect(find.text(VetNotice.text), findsOneWidget);
      },
    );

    testWidgets('si falla el envío, reintenta con el mismo client_scan_id', (
      tester,
    ) async {
      useTallPhone(tester);
      final backend = FakeBackend()..acceptConsent();
      backend
        ..addPet('Toby')
        ..failNextSubmit = true;
      await pumpApp(tester, backend);

      await tapText(tester, 'Toby');
      await tapText(tester, 'Escanear dientes');
      await tapText(tester, 'Simular escaneo');

      expect(find.textContaining('tu escaneo no se perdió'), findsOneWidget);
      await tapText(tester, 'Reintentar envío');

      expect(backend.submissions, hasLength(2));
      expect(
        backend.submissions[0]['client_scan_id'],
        backend.submissions[1]['client_scan_id'],
      );
      expect(find.text('Conviene vigilar'), findsOneWidget);
    });

    testWidgets('en Android abre la cámara real del SDK', (tester) async {
      useTallPhone(tester);
      const channel = MethodChannel(ToothScanner.channelName);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments['userId'], kUserId);
        return jsonEncode({
          'status': 'SUCCESS',
          'petType': 'DOG',
          'part': 'TOOTH',
          'subPart': 'TRIGHT',
          'response': {
            'status': 'WARNING',
            'symptoms': [
              {'code': 'calculus', 'abnormLevel': 1},
            ],
          },
        });
      });
      final backend = FakeBackend()..acceptConsent();
      backend.addPet('Toby');
      await pumpApp(tester, backend, sdkAvailable: true);

      await tapText(tester, 'Toby');
      await tapText(tester, 'Escanear dientes');
      await tapText(tester, 'Abrir cámara');

      expect(backend.submissions.single['sdk_version'], '2.2.3');
      expect(find.text('Consulta pronto'), findsOneWidget);
      expect(find.text('Dientes del lado derecho'), findsNothing);
      await expectShown(
        tester,
        find.textContaining('Dientes del lado derecho'),
      );
      expect(find.textContaining('Resultado simulado'), findsNothing);
      expect(find.text(VetNotice.text), findsOneWidget);
    });

    testWidgets('el historial abre el resultado guardado', (tester) async {
      useTallPhone(tester);
      final backend = FakeBackend()..acceptConsent();
      backend.addPet('Toby');
      await pumpApp(tester, backend);

      await tapText(tester, 'Toby');
      await tapText(tester, 'Escanear dientes');
      await tapText(tester, 'Simular escaneo');
      await tapText(tester, 'Volver a Toby');

      expect(find.text('Historial'), findsOneWidget);
      expect(
        find.textContaining('Signos: inflamación de encías'),
        findsOneWidget,
      );
    });
  });
}
