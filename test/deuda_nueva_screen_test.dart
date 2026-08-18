import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/screens/placeholders/deuda_nueva_screen.dart';

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: DeudaNuevaScreen())),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el botón Guardar está deshabilitado con el formulario vacío', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets(
    'los campos de interés aparecen y desaparecen según el switch (solo en pago libre)',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      // El switch "¿Tiene interés?" solo existe bajo "Pago libre": en
      // "cuotas fijas" el interés total se deriva automáticamente.
      await tester.tap(find.text('Pago libre'));
      await tester.pumpAndSettle();

      expect(find.text('Tasa de interés (%)'), findsNothing);

      await tester.tap(find.text('¿Tiene interés?'));
      await tester.pumpAndSettle();

      expect(find.text('Tasa de interés (%)'), findsOneWidget);
      expect(find.text('Tipo de tasa'), findsOneWidget);

      await tester.tap(find.text('¿Tiene interés?'));
      await tester.pumpAndSettle();

      expect(find.text('Tasa de interés (%)'), findsNothing);
    },
  );

  testWidgets(
    'bajo "cuotas fijas" no se pide tasa de interés, switch de interés ni día de pago',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      expect(find.text('¿Tiene interés?'), findsNothing);
      expect(find.text('Tasa de interés (%)'), findsNothing);
      expect(find.text('Día de pago (1-31)'), findsNothing);
      expect(find.text('Fecha de vencimiento final'), findsNothing);
      expect(find.text('Periodicidad de cuotas'), findsOneWidget);
    },
  );

  testWidgets(
    'los campos de estructura de pago cambian entre cuotas fijas y pago libre',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      // Por defecto la estructura es "cuotas fijas".
      expect(find.text('Número de cuotas'), findsOneWidget);
      expect(find.text('Pago mínimo (opcional)'), findsNothing);

      await tester.tap(find.text('Pago libre'));
      await tester.pumpAndSettle();

      expect(find.text('Número de cuotas'), findsNothing);
      expect(find.text('Pago mínimo (opcional)'), findsOneWidget);

      await tester.tap(find.text('Cuotas fijas'));
      await tester.pumpAndSettle();

      expect(find.text('Número de cuotas'), findsOneWidget);
      expect(find.text('Pago mínimo (opcional)'), findsNothing);
    },
  );
}
