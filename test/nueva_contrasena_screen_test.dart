import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/nueva_contrasena_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAuthRepository implements AuthRepository {
  String? contrasenaRecibida;
  Object? errorAlActualizar;

  @override
  bool get haySesionActiva => true;
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
  Future<void> cerrarSesion() async {}
  @override
  Future<void> eliminarCuenta() async {}
  @override
  Future<void> iniciarSesionConGoogle() async {}
  @override
  Future<void> enviarLinkRecuperacion({required String email}) async {}

  @override
  Future<void> actualizarContrasena({required String nuevaContrasena}) async {
    contrasenaRecibida = nuevaContrasena;
    if (errorAlActualizar != null) throw errorAlActualizar!;
  }
}

Future<_FakeAuthRepository> _pumpScreen(
  WidgetTester tester, {
  Object? errorAlActualizar,
}) async {
  final fake = _FakeAuthRepository()..errorAlActualizar = errorAlActualizar;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: NuevaContrasenaScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('el botón Guardar está deshabilitado con el formulario vacío', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    final boton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Guardar'),
    );
    expect(boton.onPressed, isNull);
  });

  testWidgets(
    'una contraseña de menos de 6 caracteres mantiene el botón deshabilitado',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'),
        '123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        '123',
      );
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'si las contraseñas no coinciden, muestra el error inline y deshabilita el botón',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'),
        'secreto123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'otra-cosa',
      );
      await tester.pump();

      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'con datos válidos, Guardar invoca actualizarContrasena con la nueva contraseña',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nueva contraseña'),
        'secreto123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'secreto123',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(fake.contrasenaRecibida, 'secreto123');
      expect(find.text('Contraseña actualizada'), findsOneWidget);
    },
  );

  testWidgets('un error al guardar muestra el mensaje traducido', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      errorAlActualizar: StateError('No se pudo actualizar la contraseña.'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nueva contraseña'),
      'secreto123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña'),
      'secreto123',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('No se pudo actualizar la contraseña.'), findsOneWidget);
  });
}
