import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/historial_pagos_deuda_screen.dart';
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

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas;
  _FakeCuentaRepository(this.cuentas);

  @override
  Future<void> actualizar(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> crear(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> eliminar(String id) async => cuentas.remove(id);

  @override
  Future<Cuenta?> obtenerPorId(String id) async => cuentas[id];

  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas.values.toList();
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  final List<PagoDeuda> pagos;
  _FakePagoDeudaRepository(this.pagos);

  @override
  Future<void> crear(PagoDeuda pago) async => pagos.add(pago);

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async =>
      pagos.where((p) => p.cuentaId == cuentaId).toList();

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async =>
      pagos.where((p) => p.deudaId == deudaId).toList();

  @override
  Future<void> eliminar(String id) async {
    pagos.removeWhere((p) => p.id == id);
  }
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
  tieneInteres: true,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: 10,
  numeroCuotasPagadas: 2,
  montoCuota: 150,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

final _cuentaFixture = const Cuenta(
  id: 'cta-1',
  nombre: 'BCP Cuenta sueldo',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: 2000,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<PagoDeuda> pagos,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        deudaRepositoryProvider.overrideWithValue(
          _FakeDeudaRepository({'d1': _deudaFixture}),
        ),
        cuentaRepositoryProvider.overrideWithValue(
          _FakeCuentaRepository({'cta-1': _cuentaFixture}),
        ),
        pagoDeudaRepositoryProvider.overrideWithValue(
          _FakePagoDeudaRepository(pagos),
        ),
      ],
      child: const MaterialApp(home: HistorialPagosDeudaScreen(deudaId: 'd1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista los pagos ordenados por fecha descendente', (
    WidgetTester tester,
  ) async {
    final pagoAntiguo = PagoDeuda(
      id: 'pago-1',
      deudaId: 'd1',
      cuentaId: 'cta-1',
      montoPagado: 100,
      fechaPago: DateTime(2026, 1, 1),
      numeroCuota: 1,
    );
    final pagoReciente = PagoDeuda(
      id: 'pago-2',
      deudaId: 'd1',
      cuentaId: 'cta-1',
      montoPagado: 200,
      fechaPago: DateTime(2026, 2, 1),
      numeroCuota: 2,
    );

    await _pumpScreen(tester, pagos: [pagoAntiguo, pagoReciente]);

    final dyReciente = tester.getTopLeft(find.text('S/ 200.00')).dy;
    final dyAntiguo = tester.getTopLeft(find.text('S/ 100.00')).dy;
    expect(dyReciente, lessThan(dyAntiguo));
  });

  testWidgets('muestra el desglose de capital e interés cuando existe', (
    WidgetTester tester,
  ) async {
    final pagoConDesglose = PagoDeuda(
      id: 'pago-1',
      deudaId: 'd1',
      cuentaId: 'cta-1',
      montoPagado: 200,
      montoCapital: 150,
      montoInteres: 50,
      fechaPago: DateTime(2026, 2, 1),
      numeroCuota: 2,
    );

    await _pumpScreen(tester, pagos: [pagoConDesglose]);

    expect(find.text('Capital: S/ 150.00 · Interés: S/ 50.00'), findsOneWidget);
    expect(find.text('Cuota #2'), findsOneWidget);
    expect(find.text('Desde BCP Cuenta sueldo'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío cuando no hay pagos', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, pagos: []);

    expect(
      find.text('Todavía no registraste ningún pago para esta deuda.'),
      findsOneWidget,
    );
  });
}
