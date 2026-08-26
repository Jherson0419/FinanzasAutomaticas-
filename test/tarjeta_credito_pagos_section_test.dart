import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/tarjeta_credito_pagos_section.dart';

Future<void> _pump(WidgetTester tester, Cuenta cuenta) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: TarjetaCreditoPagosSection(cuenta: cuenta)),
    ),
  );
}

void main() {
  final hoy = DateTime.now();
  final proximoPago = hoy.add(const Duration(days: 7));
  String diaMes(DateTime f) =>
      '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}';

  Cuenta cuentaCredito({double? pagoMinimo}) => Cuenta(
    id: 'c1',
    nombre: 'Visa BCP',
    tipo: TipoCuenta.credito,
    moneda: Moneda.pen,
    saldoActual: -350,
    lineaCredito: 2000,
    fechaCorte: hoy.add(const Duration(days: 2)),
    fechaPago: proximoPago,
    pagoMinimo: pagoMinimo,
  );

  testWidgets(
    '"Pago del mes" (pestaña inicial) muestra pagoMinimo y la próxima fecha de pago',
    (WidgetTester tester) async {
      await _pump(tester, cuentaCredito(pagoMinimo: 120));

      expect(find.text('S/ 120.00'), findsOneWidget);
      expect(find.text('Vence el ${diaMes(proximoPago)}'), findsOneWidget);
    },
  );

  testWidgets(
    'sin pagoMinimo configurado, "Pago del mes" y "Pago mínimo" muestran '
    '"No configurado" en vez de S/ 0.00',
    (WidgetTester tester) async {
      await _pump(tester, cuentaCredito());

      expect(find.text('No configurado'), findsOneWidget);

      await tester.tap(find.text('Pago mínimo'));
      await tester.pumpAndSettle();

      expect(find.text('No configurado'), findsOneWidget);
    },
  );

  testWidgets(
    '"Deuda total" muestra |saldoActual| aunque no sea 0, nunca "No configurado"',
    (WidgetTester tester) async {
      await _pump(tester, cuentaCredito());

      await tester.tap(find.text('Deuda total'));
      await tester.pumpAndSettle();

      expect(find.text('S/ 350.00'), findsOneWidget);
      expect(find.text('No configurado'), findsNothing);
    },
  );

  testWidgets(
    '"Deuda total" con saldo positivo (sin usar la línea) muestra S/ 0.00',
    (WidgetTester tester) async {
      final cuenta = Cuenta(
        id: 'c2',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: 50,
        lineaCredito: 2000,
        fechaCorte: hoy,
        fechaPago: hoy,
      );
      await _pump(tester, cuenta);

      await tester.tap(find.text('Deuda total'));
      await tester.pumpAndSettle();

      expect(find.text('S/ 0.00'), findsOneWidget);
    },
  );

  testWidgets(
    'sin fechaPago configurada, muestra el mensaje en vez de "Vence el"',
    (WidgetTester tester) async {
      final cuenta = Cuenta(
        id: 'c3',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: -100,
        lineaCredito: 2000,
        pagoMinimo: 50,
      );
      await _pump(tester, cuenta);

      expect(find.text('Sin fecha de pago configurada'), findsOneWidget);
    },
  );

  testWidgets(
    '"Ver mis fechas de pago" abre un bottom sheet con el próximo corte Y pago',
    (WidgetTester tester) async {
      await _pump(tester, cuentaCredito(pagoMinimo: 120));

      await tester.tap(find.text('Ver mis fechas de pago'));
      await tester.pumpAndSettle();

      expect(find.text('Tus fechas de pago'), findsOneWidget);
      expect(find.text('Próximo corte'), findsOneWidget);
      expect(find.text('Próximo pago'), findsOneWidget);
      expect(
        find.text(diaMes(hoy.add(const Duration(days: 2)))),
        findsOneWidget,
      );
      expect(find.text(diaMes(proximoPago)), findsOneWidget);
    },
  );

  testWidgets(
    'el bottom sheet muestra "No configurado" si falta alguna de las 2 fechas',
    (WidgetTester tester) async {
      // `pagoMinimo` configurado a propósito: si quedara en `null`, la
      // pestaña de fondo ("Pago del mes") también mostraría "No
      // configurado" y el `find.text` de abajo encontraría 2 en vez de 1.
      final cuenta = Cuenta(
        id: 'c4',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: -100,
        lineaCredito: 2000,
        fechaPago: proximoPago,
        pagoMinimo: 120,
      );
      await _pump(tester, cuenta);

      await tester.tap(find.text('Ver mis fechas de pago'));
      await tester.pumpAndSettle();

      expect(find.text('No configurado'), findsOneWidget);
    },
  );
}
