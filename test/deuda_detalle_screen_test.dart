import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/deuda_detalle_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

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

Future<void> _pumpScreen(
  WidgetTester tester, {
  required Deuda deuda,
  List<PagoDeuda> pagos = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        deudaRepositoryProvider.overrideWithValue(
          _FakeDeudaRepository({deuda.id: deuda}),
        ),
        pagoDeudaRepositoryProvider.overrideWithValue(
          _FakePagoDeudaRepository(pagos),
        ),
        cuentaRepositoryProvider.overrideWithValue(_FakeCuentaRepository({})),
      ],
      child: MaterialApp(home: DeudaDetalleScreen(deudaId: deuda.id)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'una deuda cuotasFijas muestra el resumen y el cronograma de cuotas',
    (WidgetTester tester) async {
      final deuda = Deuda(
        id: 'd1',
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1200,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 4,
        numeroCuotasPagadas: 0,
        montoCuota: 300,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
      );

      await _pumpScreen(tester, deuda: deuda);

      expect(find.text('Préstamo personal'), findsOneWidget);
      expect(find.text('Cronograma de cuotas'), findsOneWidget);
      expect(find.text('Cuota #1'), findsOneWidget);
      expect(find.text('Cuota #4'), findsOneWidget);
    },
  );

  testWidgets(
    'una deuda pagoLibre muestra "Sin cuota fija" y el historial de pagos embebido',
    (WidgetTester tester) async {
      final deuda = Deuda(
        id: 'd2',
        nombreDeuda: 'Tarjeta de crédito',
        tipoDeuda: TipoDeuda.tarjetaCredito,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BBVA',
        moneda: Moneda.pen,
        montoTotal: 500,
        montoPagado: 100,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
      );

      await _pumpScreen(tester, deuda: deuda);

      expect(find.text('Sin cuota fija (pago libre)'), findsOneWidget);
      expect(find.text('Cronograma de cuotas'), findsNothing);
      expect(find.text('Pagos registrados'), findsOneWidget);
    },
  );

  testWidgets(
    'Fase 58: una cuota pagada se muestra tachada, la pendiente no',
    (WidgetTester tester) async {
      final deuda = Deuda(
        id: 'd3',
        nombreDeuda: 'Compra a cuotas',
        tipoDeuda: TipoDeuda.compraCuotas,
        tipoAcreedor: TipoAcreedor.comercio,
        nombreAcreedor: 'Falabella',
        moneda: Moneda.pen,
        montoTotal: 300,
        montoPagado: 100,
        tieneInteres: false,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 3,
        numeroCuotasPagadas: 1,
        montoCuota: 100,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
      );
      final pagoCuota1 = PagoDeuda(
        id: 'p1',
        deudaId: 'd3',
        cuentaId: 'cta-1',
        montoPagado: 100,
        fechaPago: DateTime(2026, 1, 1),
        numeroCuota: 1,
      );

      await _pumpScreen(tester, deuda: deuda, pagos: [pagoCuota1]);

      final numeroCuota1 = tester.widget<Text>(find.text('Cuota #1'));
      expect(numeroCuota1.style?.decoration, TextDecoration.lineThrough);

      final numeroCuota2 = tester.widget<Text>(find.text('Cuota #2'));
      expect(numeroCuota2.style?.decoration, isNot(TextDecoration.lineThrough));
    },
  );
}
