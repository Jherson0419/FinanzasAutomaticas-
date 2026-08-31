import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/placeholders/deuda_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);

  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values.toList();

  @override
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();
}

final _deudaFixture = Deuda(
  id: 'd1',
  nombreDeuda: 'Préstamo personal',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 1000,
  montoPagado: 300,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

Future<void> _pumpTearDown(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('el botón "Ver historial de pagos" no aparece en modo creación', (
    WidgetTester tester,
  ) async {
    await _pumpTearDown(tester);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DeudaNuevaScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver historial de pagos'), findsNothing);
  });

  testWidgets('el botón "Ver historial de pagos" aparece en modo edición', (
    WidgetTester tester,
  ) async {
    await _pumpTearDown(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          datosEnLaNubeProvider.overrideWithValue(false),
          deudaRepositoryProvider.overrideWithValue(
            _FakeDeudaRepository({'d1': _deudaFixture}),
          ),
        ],
        child: const MaterialApp(home: DeudaNuevaScreen(deudaId: 'd1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ver historial de pagos'), findsOneWidget);
  });
}
