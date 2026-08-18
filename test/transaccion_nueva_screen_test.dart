import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/presentation/screens/placeholders/transaccion_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

final _cuentasFixture = [
  const Cuenta(
    id: 'cta-1',
    nombre: 'BCP Cuenta sueldo',
    tipo: TipoCuenta.debito,
    moneda: Moneda.pen,
    saldoActual: 1000,
  ),
];

final _categoriasFixture = [
  const Categoria(
    id: 'cat-gasto',
    nombre: 'Comida',
    tipo: TipoCategoria.gasto,
    iconName: 'restaurant',
  ),
  const Categoria(
    id: 'cat-ingreso',
    nombre: 'Sueldo',
    tipo: TipoCategoria.ingreso,
    iconName: 'payments',
  ),
];

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cuentasProvider.overrideWith((ref) => _cuentasFixture),
        categoriasProvider.overrideWith((ref) => _categoriasFixture),
      ],
      child: const MaterialApp(home: TransaccionNuevaScreen()),
    ),
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
    'el botón Guardar se habilita al completar monto, cuenta y categoría',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto'),
        '25.50',
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCP Cuenta sueldo (S/)').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Categoría'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comida').last);
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNotNull);
    },
  );
}
