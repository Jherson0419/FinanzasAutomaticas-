import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_fixtures.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/cuentas_carrusel.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/wallet_account_card.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

Future<void> _pumpCarrusel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cuentasProvider.overrideWith((ref) => cuentasDashboardFixture),
      ],
      child: const MaterialApp(home: Scaffold(body: CuentasCarrusel())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'la tarjeta ocupa ~85% del ancho disponible, dejando ver las vecinas',
    (WidgetTester tester) async {
      await _pumpCarrusel(tester);

      final anchoPantalla = tester.getSize(find.byType(Scaffold)).width;
      final anchoTarjeta = tester
          .getSize(find.byType(WalletAccountCard).first)
          .width;

      // viewportFraction = 0.85, con margen por el padding horizontal de 8
      // a cada lado de cada página.
      expect(anchoTarjeta / anchoPantalla, closeTo(0.85, 0.02));

      // Proporción ancho:alto ≈ 1.6:1, como una tarjeta de crédito real.
      final altoTarjeta = tester
          .getSize(find.byType(WalletAccountCard).first)
          .height;
      expect(anchoTarjeta / altoTarjeta, closeTo(1.6, 0.05));
    },
  );

  testWidgets(
    'muestra un indicador de página con una tarjeta por cuenta más la de agregar',
    (WidgetTester tester) async {
      await _pumpCarrusel(tester);

      // 3 cuentas fixture + la tarjeta "agregar" = 4 páginas → 4 puntitos.
      expect(find.byType(AnimatedContainer), findsNWidgets(4));
    },
  );

  testWidgets(
    'deslizar el carrusel avanza de página y actualiza el indicador',
    (WidgetTester tester) async {
      await _pumpCarrusel(tester);

      final anchoPantalla = tester.getSize(find.byType(Scaffold)).width;

      final puntosAntes = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((w) => (w.decoration as BoxDecoration).color)
          .toList();

      await tester.drag(find.byType(PageView), Offset(-anchoPantalla, 0));
      await tester.pumpAndSettle();

      final puntosDespues = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((w) => (w.decoration as BoxDecoration).color)
          .toList();

      // El punto "activo" (color distinto) cambió de posición.
      expect(puntosDespues, isNot(equals(puntosAntes)));
    },
  );

  testWidgets(
    'con cero cuentas el carrusel solo muestra la tarjeta de agregar',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [cuentasProvider.overrideWith((ref) => const [])],
          child: const MaterialApp(home: Scaffold(body: CuentasCarrusel())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WalletAccountCard), findsNothing);
      expect(find.text('Agregar cuenta'), findsOneWidget);
    },
  );
}
