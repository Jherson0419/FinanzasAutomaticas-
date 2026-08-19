import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/cuentas_carrusel.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/wallet_account_card.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

const _cuentaBcp = Cuenta(
  id: 'cta-1',
  nombre: 'BCP Cuenta sueldo',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: 3250.40,
);
const _cuentaYape = Cuenta(
  id: 'cta-2',
  nombre: 'Yape',
  tipo: TipoCuenta.billetera,
  moneda: Moneda.pen,
  saldoActual: 180,
);
const _cuentaUsd = Cuenta(
  id: 'cta-3',
  nombre: 'Ahorros USD',
  tipo: TipoCuenta.debito,
  moneda: Moneda.usd,
  saldoActual: 420,
);
const _cuentaExtra1 = Cuenta(
  id: 'cta-4',
  nombre: 'Interbank Sueldo',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: 100,
);
const _cuentaExtra2 = Cuenta(
  id: 'cta-5',
  nombre: 'Efectivo',
  tipo: TipoCuenta.efectivo,
  moneda: Moneda.pen,
  saldoActual: 50,
);

const _tresCuentas = [_cuentaBcp, _cuentaYape, _cuentaUsd];
const _cincoCuentas = [
  _cuentaBcp,
  _cuentaYape,
  _cuentaUsd,
  _cuentaExtra1,
  _cuentaExtra2,
];

Future<void> _pump(WidgetTester tester, List<Cuenta> cuentas) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [cuentasProvider.overrideWith((ref) => cuentas)],
      child: MaterialApp(
        routes: {
          '/cuentas/nueva': (_) =>
              const Scaffold(body: Text('Pantalla: Nueva cuenta')),
        },
        home: const Scaffold(body: CuentasCarrusel()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// La tarjeta frontal es la única envuelta en `ClipPath` (el recorte
/// cóncavo del botón "Añadir cuenta", Fase 33.3) — usarlo para identificar
/// cuál cuenta está al frente sin depender de un tipo privado del widget.
bool _esFrente(WidgetTester tester, String nombreCuenta) {
  return tester
      .widgetList(
        find.ancestor(
          of: find.text(nombreCuenta),
          matching: find.byType(ClipPath),
        ),
      )
      .isNotEmpty;
}

void main() {
  group('CuentasCarrusel (Fase 33 — pila vertical)', () {
    testWidgets('con 3 cuentas muestra máximo 3 tarjetas (1 frente + 2 '
        'detrás)', (tester) async {
      await _pump(tester, _tresCuentas);

      expect(find.byType(WalletAccountCard), findsNWidgets(3));
    });

    testWidgets('con 5 cuentas sigue mostrando máximo 3 tarjetas', (
      tester,
    ) async {
      await _pump(tester, _cincoCuentas);

      expect(find.byType(WalletAccountCard), findsNWidgets(3));
    });

    testWidgets('con 1 sola cuenta no hay tarjetas fantasma', (tester) async {
      await _pump(tester, const [_cuentaBcp]);

      expect(find.byType(WalletAccountCard), findsOneWidget);
      expect(_esFrente(tester, 'BCP Cuenta sueldo'), isTrue);
    });

    testWidgets('con 2 cuentas muestra la frontal y solo 1 fantasma detrás', (
      tester,
    ) async {
      await _pump(tester, const [_cuentaBcp, _cuentaYape]);

      expect(find.byType(WalletAccountCard), findsNWidgets(2));
    });

    testWidgets('el texto de ayuda no aparece con una sola cuenta', (
      tester,
    ) async {
      await _pump(tester, const [_cuentaBcp]);

      expect(
        find.text('Desliza hacia arriba para ver la siguiente cuenta'),
        findsNothing,
      );
    });

    testWidgets('el texto de ayuda sí aparece con más de una cuenta', (
      tester,
    ) async {
      await _pump(tester, _tresCuentas);

      expect(
        find.text('Desliza hacia arriba para ver la siguiente cuenta'),
        findsOneWidget,
      );
    });

    testWidgets(
      'deslizar hacia arriba rota la pila: la siguiente cuenta pasa al '
      'frente',
      (tester) async {
        await _pump(tester, _tresCuentas);

        expect(_esFrente(tester, 'BCP Cuenta sueldo'), isTrue);
        expect(_esFrente(tester, 'Yape'), isFalse);

        await tester.fling(
          find.byType(CuentasCarrusel),
          const Offset(0, -300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(_esFrente(tester, 'Yape'), isTrue);
        expect(_esFrente(tester, 'BCP Cuenta sueldo'), isFalse);
        // La cuenta que salió del frente sigue en la pila (pasó al final),
        // no desaparece.
        expect(find.text('BCP Cuenta sueldo'), findsOneWidget);
      },
    );

    testWidgets(
      'deslizar hacia abajo no rota la pila (solo el gesto hacia arriba '
      'lo hace)',
      (tester) async {
        await _pump(tester, _tresCuentas);

        await tester.fling(
          find.byType(CuentasCarrusel),
          const Offset(0, 300),
          1000,
        );
        await tester.pumpAndSettle();

        expect(_esFrente(tester, 'BCP Cuenta sueldo'), isTrue);
      },
    );

    testWidgets('el botón "Añadir cuenta" navega a /cuentas/nueva', (
      tester,
    ) async {
      await _pump(tester, _tresCuentas);

      await tester.tap(find.text('Añadir cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla: Nueva cuenta'), findsOneWidget);
    });

    testWidgets('con cero cuentas muestra el prompt de agregar cuenta', (
      tester,
    ) async {
      await _pump(tester, const []);

      expect(find.byType(WalletAccountCard), findsNothing);
      expect(find.text('Añadir cuenta'), findsOneWidget);

      await tester.tap(find.text('Añadir cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla: Nueva cuenta'), findsOneWidget);
    });
  });
}
