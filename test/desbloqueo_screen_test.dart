import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/pin_hash.dart';
import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/root_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakePreferenciasRepository implements PreferenciasRepository {
  final String? pinHash;
  _FakePreferenciasRepository({this.pinHash});

  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<bool> onboardingCompletado() async => false;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
  @override
  Future<String?> obtenerPinHash() async => pinHash;
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

class _FakeAuthRepository implements AuthRepository {
  bool _haySesion = true;
  bool cerrarSesionLlamado = false;

  @override
  bool get haySesionActiva => _haySesion;
  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> cerrarSesion() async {
    cerrarSesionLlamado = true;
    _haySesion = false;
  }

  @override
  Future<void> eliminarCuenta() async => _haySesion = false;
}

Future<_FakeAuthRepository> _pumpRoot(
  WidgetTester tester, {
  required String? pinHashGuardado,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeAuth = _FakeAuthRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        bloqueoConfiguradoProvider.overrideWith((ref) async => true),
        preferenciasRepositoryProvider.overrideWithValue(
          _FakePreferenciasRepository(pinHash: pinHashGuardado),
        ),
      ],
      child: const MaterialApp(home: RootScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fakeAuth;
}

void main() {
  testWidgets('un PIN incorrecto muestra un error y no desbloquea', (
    WidgetTester tester,
  ) async {
    await _pumpRoot(tester, pinHashGuardado: hashPin('1234'));

    await tester.enterText(find.byType(TextFormField), '0000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('PIN incorrecto'), findsOneWidget);
    expect(find.text('Ingresa tu PIN'), findsOneWidget);
  });

  testWidgets('el PIN correcto desbloquea y continúa al flujo normal', (
    WidgetTester tester,
  ) async {
    await _pumpRoot(tester, pinHashGuardado: hashPin('1234'));

    await tester.enterText(find.byType(TextFormField), '1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Desbloquear'));
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu PIN'), findsNothing);
    // onboardingCompletado() del fake es false → cae al wizard.
    expect(
      find.text('Bienvenido a Finzo: Finanzas Automáticas'),
      findsOneWidget,
    );
  });

  testWidgets('"Usar mi correo y contraseña" cierra sesión y vuelve al login', (
    WidgetTester tester,
  ) async {
    final fakeAuth = await _pumpRoot(tester, pinHashGuardado: hashPin('1234'));

    await tester.tap(find.text('Usar mi correo y contraseña'));
    await tester.pumpAndSettle();

    expect(fakeAuth.cerrarSesionLlamado, isTrue);
    expect(fakeAuth.haySesionActiva, isFalse);
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Ingresa tu PIN'), findsNothing);
  });
}
