import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/cuenta_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas = {};

  @override
  Future<void> actualizar(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> crear(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<Cuenta?> obtenerPorId(String id) async => cuentas[id];

  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas.values.toList();

  @override
  Future<void> eliminar(String id) async => cuentas.remove(id);
}

Future<_FakeCuentaRepository> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeCuentaRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: CuentaNuevaScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('el botón Guardar está deshabilitado sin nombre de cuenta', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets('completar el nombre habilita Guardar y crea la cuenta', (
    WidgetTester tester,
  ) async {
    final fake = await _pumpScreen(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
      'Efectivo diario',
    );
    await tester.pump();

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    // Dos pumps (sin `pumpAndSettle` todavía): uno procesa el tap y
    // dispara `_guardar()`, el otro deja que el `await` al repositorio se
    // resuelva. `pumpAndSettle` demasiado pronto haría avanzar también la
    // animación de auto-cierre del SnackBar, y ya no quedaría nada que
    // encontrar con `find.text`.
    await tester.pump();
    await tester.pump();

    expect(fake.cuentas.length, 1);
    expect(fake.cuentas.values.first.nombre, 'Efectivo diario');
    expect(fake.cuentas.values.first.saldoActual, 0);
    expect(find.text('Cuenta creada'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
