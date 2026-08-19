import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/wallet_account_card.dart';

Future<void> _pump(WidgetTester tester, Cuenta cuenta) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: WalletAccountCard(cuenta: cuenta)),
    ),
  );
}

void main() {
  testWidgets(
    'una cuenta de crédito con saldo negativo muestra "Usado X de Y"',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const Cuenta(
          id: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -350,
          lineaCredito: 2000,
          diaCorte: 10,
          diaPago: 20,
        ),
      );

      expect(find.text('Usado S/ 350.00 de S/ 2,000.00'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      final barra = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(barra.value, closeTo(350 / 2000, 0.001));
    },
  );

  testWidgets(
    'una cuenta de crédito sin usar (saldo 0 o positivo) muestra "Usado S/ 0.00"',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const Cuenta(
          id: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: 0,
          lineaCredito: 2000,
          diaCorte: 10,
          diaPago: 20,
        ),
      );

      expect(find.text('Usado S/ 0.00 de S/ 2,000.00'), findsOneWidget);
    },
  );

  testWidgets(
    'una cuenta que NO es de crédito sigue mostrando el saldo tal cual',
    (WidgetTester tester) async {
      await _pump(
        tester,
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1234.5,
        ),
      );

      expect(find.text('S/ 1,234.50'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'la textura decorativa (Fase 31) no tapa el texto ni queda expuesta '
    'a lectores de pantalla',
    (WidgetTester tester) async {
      final handle = tester.ensureSemantics();

      const cuenta = Cuenta(
        id: 'c1',
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 1234.5,
      );
      await _pump(tester, cuenta);

      // La textura existe...
      expect(find.byType(CustomPaint), findsWidgets);
      // ...pero es puramente decorativa: no aparece en el árbol de
      // semántica (los lectores de pantalla la ignoran).
      expect(find.byType(ExcludeSemantics), findsWidgets);

      // El nombre y el saldo siguen siendo legibles/encontrables encima de
      // la textura — nada la tapa ni la reemplaza.
      expect(find.text('Ahorros'), findsOneWidget);
      expect(find.text('S/ 1,234.50'), findsOneWidget);

      final semantics = tester.getSemantics(find.text('Ahorros'));
      expect(semantics.label, contains('Ahorros'));

      handle.dispose();
    },
  );
}
