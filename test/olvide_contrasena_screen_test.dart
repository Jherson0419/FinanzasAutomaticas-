import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/olvide_contrasena_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAuthRepository implements AuthRepository {
  String? emailRecibido;
  Object? errorAlEnviar;

  @override
  bool get haySesionActiva => false;
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
  Future<void> actualizarContrasena({required String nuevaContrasena}) async {}

  @override
  Future<void> enviarLinkRecuperacion({required String email}) async {
    emailRecibido = email;
    if (errorAlEnviar != null) throw errorAlEnviar!;
  }
}

/// `OlvideContrasenaScreen` hace `Navigator.pop()` al enviar con éxito —
/// necesita una pantalla debajo en la pila (como en la app real, donde
/// `LoginScreen` la abre con `Navigator.push`) para que ese `pop()` tenga
/// dónde volver.
Future<_FakeAuthRepository> _pumpScreen(
  WidgetTester tester, {
  Object? errorAlEnviar,
}) async {
  final fake = _FakeAuthRepository()..errorAlEnviar = errorAlEnviar;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const OlvideContrasenaScreen(),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('el botón está deshabilitado con el correo vacío o inválido', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'no-es-un-correo',
    );
    await tester.pump();

    final boton2 = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton2.onPressed, isNull);
  });

  testWidgets(
    'con un correo válido, envía el link y vuelve al login con confirmación',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'user@example.com',
      );
      await tester.pump();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Enviar link de recuperación'),
      );
      await tester.pumpAndSettle();

      expect(fake.emailRecibido, 'user@example.com');
    },
  );

  testWidgets('un error al enviar muestra el mensaje traducido', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      errorAlEnviar: StateError('No se pudo enviar el link de recuperación.'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'user@example.com',
    );
    await tester.pump();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Enviar link de recuperación'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo enviar el link de recuperación.'),
      findsOneWidget,
    );
  });
}
