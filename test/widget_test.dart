import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_fixtures.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

void main() {
  testWidgets('DashboardScreen muestra el saldo total con datos de prueba', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cuentasProvider.overrideWith((ref) => cuentasDashboardFixture),
          resumenDashboardProvider.overrideWith(
            (ref) => resumenDashboardFixture,
          ),
          nombreUsuarioProvider.overrideWith((ref) => 'Jherson'),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SALDO TOTAL'), findsOneWidget);
    expect(find.text('GASTO POR CATEGORÍA'), findsOneWidget);
    expect(find.text('DEUDAS ACTIVAS'), findsOneWidget);
  });

  testWidgets('DashboardScreen muestra el estado vacío sin datos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resumenDashboardProvider.overrideWith(
            (ref) => resumenDashboardVacioFixture,
          ),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Aún no tienes transacciones registradas'),
      findsOneWidget,
    );
  });
}
