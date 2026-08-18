import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/screens/onboarding/onboarding_nombre_step.dart';

void main() {
  testWidgets('no se puede avanzar del paso nombre sin texto', (
    WidgetTester tester,
  ) async {
    final controller = TextEditingController();
    var avanzo = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OnboardingNombreStep(
            controller: controller,
            onAtras: () {},
            onContinuar: () => avanzo = true,
          ),
        ),
      ),
    );

    final botonVacio = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(botonVacio.onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'Jherson');
    await tester.pump();

    final botonConTexto = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(botonConTexto.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    expect(avanzo, isTrue);
  });
}
