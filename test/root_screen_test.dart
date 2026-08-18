import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_fixtures.dart';
import 'package:finanzas_automaticas/presentation/screens/root_screen.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Fake mínimo — `DesbloqueoScreen` lee `obtenerBloqueoBiometricoActivo()`
/// directo del repositorio (no pasa por `bloqueoConfiguradoProvider`) para
/// decidir si intenta biométrico antes de mostrar el campo de PIN.
class _FakePreferenciasRepositorySinBiometrico
    implements PreferenciasRepository {
  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<bool> onboardingCompletado() async => true;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
  @override
  Future<String?> obtenerPinHash() async => null;
  @override
  Future<void> guardarPinHash(String hash) async {}
  @override
  Future<bool> obtenerBloqueoBiometricoActivo() async => false;
  @override
  Future<void> guardarBloqueoBiometricoActivo(bool activo) async {}
  @override
  Future<bool> bloqueoOmitido() async => false;
  @override
  Future<void> marcarBloqueoOmitido() async {}
  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<void> limpiarTodo() async {}
}

/// Overrides comunes para simular "ya hay sesión y el bloqueo ya se
/// omitió" — el estado por defecto para probar la lógica de onboarding
/// sin que `LoginScreen`/`ConfigurarBloqueoScreen` se interpongan.
List<Override> _sesionActivaSinBloqueo() => [
  haySesionActivaProvider.overrideWith((ref) => true),
  necesitaMigracionProvider.overrideWith((ref) async => false),
  bloqueoConfiguradoProvider.overrideWith((ref) async => false),
  bloqueoOmitidoProvider.overrideWith((ref) async => true),
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
    expect(find.text('Bienvenido a Finanzas Automáticas'), findsNothing);
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
            ..._sesionActivaSinBloqueo(),
            onboardingCompletadoProvider.overrideWith((ref) => false),
            cuentasProvider.overrideWith((ref) => const []),
            deudasProvider.overrideWith((ref) => const []),
          ],
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a Finanzas Automáticas'), findsOneWidget);
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
            ..._sesionActivaSinBloqueo(),
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
      expect(find.text('Bienvenido a Finanzas Automáticas'), findsNothing);
    },
  );

  testWidgets(
    'con sesión activa y bloqueo configurado (sin desbloquear todavía) se muestra la pantalla de desbloqueo',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            haySesionActivaProvider.overrideWith((ref) => true),
            necesitaMigracionProvider.overrideWith((ref) async => false),
            bloqueoConfiguradoProvider.overrideWith((ref) async => true),
            preferenciasRepositoryProvider.overrideWithValue(
              _FakePreferenciasRepositorySinBiometrico(),
            ),
          ],
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ingresa tu PIN'), findsOneWidget);
      expect(find.text('SALDO TOTAL'), findsNothing);
    },
  );
}
