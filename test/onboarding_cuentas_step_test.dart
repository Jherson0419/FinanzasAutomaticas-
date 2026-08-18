import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/onboarding/onboarding_cuentas_step.dart';
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

void main() {
  testWidgets('no se puede avanzar del paso cuentas sin al menos una cuenta', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _FakeCuentaRepository();
    var avanzo = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          datosEnLaNubeProvider.overrideWithValue(false),
          cuentaRepositoryProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OnboardingCuentasStep(
              onAtras: () {},
              onContinuar: () => avanzo = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final continuarInicial = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(continuarInicial.onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
      'Efectivo',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(fake.cuentas.length, 1);

    final continuarFinal = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Continuar'),
    );
    expect(continuarFinal.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    expect(avanzo, isTrue);
  });
}
