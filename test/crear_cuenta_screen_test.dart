import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/crear_cuenta_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAuthRepository implements AuthRepository {
  bool _haySesion = false;
  String? emailRecibido;
  String? passwordRecibido;
  Object? errorAlCrearCuenta;

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
  }) async {
    emailRecibido = email;
    passwordRecibido = password;
    if (errorAlCrearCuenta != null) throw errorAlCrearCuenta!;
    _haySesion = true;
  }

  @override
  Future<void> cerrarSesion() async => _haySesion = false;

  @override
  Future<void> iniciarSesionConGoogle() async {}

  @override
  Future<void> eliminarCuenta() async => _haySesion = false;
}

Future<_FakeAuthRepository> _pumpScreen(
  WidgetTester tester, {
  Object? errorAlCrearCuenta,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeAuthRepository()..errorAlCrearCuenta = errorAlCrearCuenta;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: CrearCuentaScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets(
    'el botón Crear cuenta está deshabilitado con el formulario vacío',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Crear cuenta'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'si las contraseñas no coinciden, muestra el error inline y deshabilita el botón',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'otra-cosa',
      );
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Crear cuenta'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'una contraseña de menos de 6 caracteres mantiene el botón deshabilitado',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        '123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        '123',
      );
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Crear cuenta'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'con datos válidos y coincidentes, crear cuenta invoca AuthRepository y vuelve al login',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'nuevo@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'secreto123',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(fake.emailRecibido, 'nuevo@example.com');
      expect(fake.passwordRecibido, 'secreto123');
      expect(fake.haySesionActiva, isTrue);
    },
  );

  testWidgets('un correo ya registrado muestra el mensaje traducido', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      errorAlCrearCuenta: StateError(
        'Ese correo ya está registrado. Inicia sesión en vez de crear una cuenta nueva.',
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'existente@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'secreto123',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Ese correo ya está registrado. Inicia sesión en vez de crear una cuenta nueva.',
      ),
      findsOneWidget,
    );
  });
}
