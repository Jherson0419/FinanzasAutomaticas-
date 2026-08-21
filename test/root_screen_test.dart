import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_fixtures.dart';
import 'package:finanzas_automaticas/presentation/screens/root_screen.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Overrides comunes para simular "ya hay sesión, sin datos locales sin
/// migrar" — el estado por defecto para probar la lógica de onboarding sin
/// que `LoginScreen`/`MigrarDatosScreen` se interpongan.
List<Override> _sesionActiva() => [
  haySesionActivaProvider.overrideWith((ref) => true),
  necesitaMigracionProvider.overrideWith((ref) async => false),
];

void main() {
  testWidgets('sin sesión activa se muestra el login', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [haySesionActivaProvider.overrideWith((ref) => false)],
        child: const MaterialApp(home: RootScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('SALDO TOTAL'), findsNothing);
    expect(find.text('Bienvenido a Finzo: Finanzas Automáticas'), findsNothing);
  });

  testWidgets(
    'con sesión activa pero onboardingCompletado en false se muestra el wizard en vez del dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._sesionActiva(),
            onboardingCompletadoProvider.overrideWith((ref) => false),
            cuentasProvider.overrideWith((ref) => const []),
            deudasProvider.overrideWith((ref) => const []),
          ],
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsOneWidget,
      );
      expect(find.text('SALDO TOTAL'), findsNothing);
    },
  );

  testWidgets(
    'con sesión activa y onboardingCompletado en true se muestra el dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._sesionActiva(),
            onboardingCompletadoProvider.overrideWith((ref) => true),
            cuentasProvider.overrideWith((ref) => cuentasDashboardFixture),
            resumenDashboardProvider.overrideWith(
              (ref) => resumenDashboardFixture,
            ),
            nombreUsuarioProvider.overrideWith((ref) => 'Jherson'),
          ],
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsNothing,
      );
    },
  );
}
