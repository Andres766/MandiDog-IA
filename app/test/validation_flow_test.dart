import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'support/fake_backend.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  testWidgets('un dueño no ve la validación clínica en su cuenta', (
    tester,
  ) async {
    useTallPhone(tester);
    await pumpApp(tester, FakeBackend());

    await tapWidget(tester, find.byTooltip('Mi cuenta'));

    expect(find.text('Validación clínica'), findsNothing);
  });

  testWidgets('el veterinario valora a ciegas y después ve lo que dijo la IA', (
    tester,
  ) async {
    useTallPhone(tester);
    final backend = FakeBackend()..role = 'vet';
    backend.addPendingCase('Toby', aiStatus: 'WARNING', breed: 'Pug');
    backend.addPendingCase('Luna', aiStatus: 'NORMAL');
    await pumpApp(tester, backend);

    await tapWidget(tester, find.byTooltip('Mi cuenta'));
    await tapText(tester, 'Validación clínica');
    expect(find.text('2 casos pendientes'), findsOneWidget);

    await tapText(tester, 'Toby');
    // Antes de valorar no aparece nada del resultado de la IA.
    expect(find.text('Consulta pronto'), findsNothing);
    final submit = find.widgetWithText(FilledButton, 'Registrar valoración');
    await bringIntoView(tester, submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tapText(tester, 'Sin signos');
    await tester.enterText(find.byType(TextField), 'Encías sanas');
    await tapWidget(tester, submit);

    expect(backend.validations.single['vet_assessment'], 'sin_signos');
    expect(backend.validations.single['notes'], 'Encías sanas');
    await expectShown(tester, find.text('No coinciden'));
    await expectShown(tester, find.text('Consulta pronto'));

    await tapText(tester, 'Siguiente caso');
    expect(find.text('Luna'), findsOneWidget);
    await tapText(tester, 'No evaluable');
    await tapWidget(
      tester,
      find.widgetWithText(FilledButton, 'Registrar valoración'),
    );
    await expectShown(tester, find.text('No cuenta en la concordancia'));

    await tapText(tester, 'Siguiente caso');
    expect(find.text('No quedan casos pendientes.'), findsOneWidget);
    expect(find.text('No hay casos pendientes'), findsOneWidget);
  });

  testWidgets('el resumen muestra la matriz y las métricas', (tester) async {
    useTallPhone(tester);
    final backend = FakeBackend()..role = 'vet';
    backend.validations.addAll([
      {
        'vet_assessment': 'con_signos',
        'ai_sees_signs': true,
        'agreement': true,
      },
      {
        'vet_assessment': 'con_signos',
        'ai_sees_signs': false,
        'agreement': false,
      },
      {
        'vet_assessment': 'sin_signos',
        'ai_sees_signs': false,
        'agreement': true,
      },
      {
        'vet_assessment': 'no_evaluable',
        'ai_sees_signs': true,
        'agreement': null,
      },
    ]);
    await pumpApp(tester, backend);

    await tapWidget(tester, find.byTooltip('Mi cuenta'));
    await tapText(tester, 'Validación clínica');
    await tapWidget(tester, find.byTooltip('Resumen de concordancia'));

    expect(
      find.text('4 valoraciones · 3 evaluables · 1 no evaluables'),
      findsOneWidget,
    );
    expect(find.text('Matriz de confusión'), findsOneWidget);
    // Sensibilidad 1/2, especificidad 1/1, exactitud 2/3 (espacio duro antes de %).
    expect(find.textContaining(RegExp(r'^50,0\s%$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^100,0\s%$')), findsOneWidget);
    expect(find.textContaining(RegExp(r'^66,7\s%$')), findsOneWidget);
    await expectShown(tester, find.text('Braquicéfalo'));
  });

  testWidgets('sin valoraciones el resumen lo explica', (tester) async {
    useTallPhone(tester);
    final backend = FakeBackend()..role = 'vet';
    await pumpApp(tester, backend);

    await tapWidget(tester, find.byTooltip('Mi cuenta'));
    await tapText(tester, 'Validación clínica');
    expect(find.text('No hay casos pendientes'), findsOneWidget);
    await tapText(tester, 'Ver resumen');

    expect(find.text('Aún no hay valoraciones'), findsOneWidget);
  });
}
