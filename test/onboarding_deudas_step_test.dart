import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/onboarding/onboarding_deudas_step.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas = {};

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values
      .where(
        (d) => d.estado == EstadoDeuda.activa || d.estado == EstadoDeuda.enMora,
      )
      .toList();

  @override
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);
}

void main() {
  testWidgets('el paso de deudas se puede omitir', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fake = _FakeDeudaRepository();
    var avanzo = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          datosEnLaNubeProvider.overrideWithValue(false),
          deudaRepositoryProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: OnboardingDeudasStep(
              onAtras: () {},
              onContinuar: () => avanzo = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fake.deudas, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Omitir por ahora'));
    await tester.pumpAndSettle();

    expect(avanzo, isTrue);
    expect(fake.deudas, isEmpty);
  });
}
