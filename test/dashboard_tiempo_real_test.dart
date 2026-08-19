import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_fixtures.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

void main() {
  testWidgets(
    'un segundo evento del stream de transacciones en vivo invalida y '
    'refresca el resumen del dashboard, sin acción manual del usuario',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = StreamController<List<Map<String, dynamic>>>();
      addTearDown(controller.close);

      // El override de `resumenDashboardProvider` devuelve un resumen
      // distinto cada vez que Riverpod lo vuelve a construir — así se
      // puede distinguir visualmente "sigue igual" de "se refrescó de
      // verdad" sin necesitar un backend real detrás.
      var version = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nombreUsuarioProvider.overrideWith((ref) => 'Jherson'),
            cuentasProvider.overrideWith((ref) => cuentasDashboardFixture),
            transaccionesEnVivoProvider.overrideWith(
              (ref) => controller.stream,
            ),
            resumenDashboardProvider.overrideWith((ref) {
              version++;
              return version == 1
                  ? resumenDashboardFixture
                  : resumenDashboardVacioFixture;
            }),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Primera versión del resumen — la de datos de prueba.
      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(version, 1);

      // Primer evento del stream = el snapshot inicial de la tabla, mismo
      // dato que el dashboard ya cargó por su cuenta al montar — no debe
      // disparar un refresh (transición `AsyncLoading` → `AsyncData` en
      // el listener, no cuenta como cambio real).
      controller.add(const []);
      await tester.pump();
      await tester.pump();
      expect(version, 1);
      expect(find.text('SALDO TOTAL'), findsOneWidget);

      // Segundo evento = un cambio real (p. ej. una captura automática vía
      // `capturar-transaccion`) — debe invalidar `resumenDashboardProvider`
      // y volver a pedirlo, que en este test cambia a la versión "vacía"
      // para poder comprobar visualmente que sí se refrescó.
      controller.add(const [
        {'id': 'tx-nueva'},
      ]);
      await tester.pumpAndSettle();

      expect(version, 2);
      expect(
        find.text('Aún no tienes transacciones registradas'),
        findsOneWidget,
      );
    },
  );
}
