import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/login_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAuthRepository implements AuthRepository {
  bool _haySesion = false;
  String? emailRecibido;
  String? passwordRecibido;
  Object? errorAlIniciarSesion;

  @override
  bool get haySesionActiva => _haySesion;

  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    emailRecibido = email;
    passwordRecibido = password;
    if (errorAlIniciarSesion != null) throw errorAlIniciarSesion!;
    _haySesion = true;
  }

  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> cerrarSesion() async => _haySesion = false;

  @override
  Future<void> eliminarCuenta() async => _haySesion = false;
}

Future<_FakeAuthRepository> _pumpScreen(
  WidgetTester tester, {
  Object? errorAlIniciarSesion,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeAuthRepository()
    ..errorAlIniciarSesion = errorAlIniciarSesion;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets(
    'el botón Iniciar sesión está deshabilitado con el formulario vacío',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'un correo con formato inválido mantiene el botón deshabilitado',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'no-es-un-correo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
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
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'con datos válidos, iniciar sesión invoca AuthRepository con el correo y contraseña ingresados',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(fake.emailRecibido, 'user@example.com');
      expect(fake.passwordRecibido, 'secreto123');
      expect(fake.haySesionActiva, isTrue);
    },
  );

  testWidgets('un error de credenciales muestra el mensaje traducido', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      errorAlIniciarSesion: StateError('Correo o contraseña incorrectos.'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('el enlace "Crear cuenta" navega a la pantalla de registro', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar contraseña'), findsOneWidget);
  });
}
