import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';

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
  Future<List<Deuda>> obtenerActivas() async => deudas.values
      .where(
        (d) => d.estado == EstadoDeuda.activa || d.estado == EstadoDeuda.enMora,
      )
      .toList();

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
  final List<PagoDeuda> pagos = [];

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

void main() {
  test(
    'un pago que salda una deuda en mora la deja con enMora=false',
    () async {
      final deudaEnMora = Deuda(
        id: 'd1',
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 300,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: true,
        diasMora: 12,
        estado: EstadoDeuda.enMora,
      );
      final cuenta = const Cuenta(
        id: 'cta-1',
        nombre: 'BCP Cuenta sueldo',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 1000,
      );

      final fakeDeudas = _FakeDeudaRepository({'d1': deudaEnMora});
      final fakeCuentas = _FakeCuentaRepository({'cta-1': cuenta});
      final fakePagos = _FakePagoDeudaRepository();

      final registrarPagoDeuda = RegistrarPagoDeuda(
        pagoDeudaRepository: fakePagos,
        deudaRepository: fakeDeudas,
        cuentaRepository: fakeCuentas,
      );

      await registrarPagoDeuda(
        deudaId: 'd1',
        cuentaId: 'cta-1',
        montoPagado: 300,
      );

      final actualizada = fakeDeudas.deudas['d1']!;
      expect(actualizada.estado, EstadoDeuda.pagada);
      expect(actualizada.enMora, isFalse);
      expect(actualizada.diasMora, 0);
    },
  );

  test(
    'un pago parcial que no salda la deuda no toca enMora/diasMora',
    () async {
      final deudaEnMora = Deuda(
        id: 'd2',
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: true,
        diasMora: 7,
        estado: EstadoDeuda.enMora,
      );
      final cuenta = const Cuenta(
        id: 'cta-1',
        nombre: 'BCP Cuenta sueldo',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 1000,
      );

      final fakeDeudas = _FakeDeudaRepository({'d2': deudaEnMora});
      final fakeCuentas = _FakeCuentaRepository({'cta-1': cuenta});
      final fakePagos = _FakePagoDeudaRepository();

      final registrarPagoDeuda = RegistrarPagoDeuda(
        pagoDeudaRepository: fakePagos,
        deudaRepository: fakeDeudas,
        cuentaRepository: fakeCuentas,
      );

      await registrarPagoDeuda(
        deudaId: 'd2',
        cuentaId: 'cta-1',
        montoPagado: 100,
      );

      final actualizada = fakeDeudas.deudas['d2']!;
      expect(actualizada.estado, EstadoDeuda.enMora);
      expect(actualizada.enMora, isTrue);
      expect(actualizada.diasMora, 7);
    },
  );

  test(
    'rechaza un pago cuando la moneda de la cuenta no coincide con la de la deuda',
    () async {
      final deudaEnPen = Deuda(
        id: 'd3',
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
      );
      final cuentaEnUsd = const Cuenta(
        id: 'cta-usd',
        nombre: 'Ahorros USD',
        tipo: TipoCuenta.debito,
        moneda: Moneda.usd,
        saldoActual: 500,
      );

      final fakeDeudas = _FakeDeudaRepository({'d3': deudaEnPen});
      final fakeCuentas = _FakeCuentaRepository({'cta-usd': cuentaEnUsd});
      final fakePagos = _FakePagoDeudaRepository();

      final registrarPagoDeuda = RegistrarPagoDeuda(
        pagoDeudaRepository: fakePagos,
        deudaRepository: fakeDeudas,
        cuentaRepository: fakeCuentas,
      );

      await expectLater(
        () => registrarPagoDeuda(
          deudaId: 'd3',
          cuentaId: 'cta-usd',
          montoPagado: 100,
        ),
        throwsA(isA<StateError>()),
      );

      // No debe haber quedado ningún rastro del intento rechazado.
      expect(fakePagos.pagos, isEmpty);
      expect(fakeDeudas.deudas['d3']!.montoPagado, 0);
      expect(fakeCuentas.cuentas['cta-usd']!.saldoActual, 500);
    },
  );

  test(
    'un pago retroactivo (cuentaId null) no descuenta saldo de ninguna cuenta ni valida moneda',
    () async {
      final deuda = Deuda(
        id: 'd4',
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
      );
      // Ninguna cuenta disponible en ninguna moneda — si el uso de caso
      // intentara resolver una cuenta, esto haría fallar el pago.
      final fakeDeudas = _FakeDeudaRepository({'d4': deuda});
      final fakeCuentas = _FakeCuentaRepository({});
      final fakePagos = _FakePagoDeudaRepository();

      final registrarPagoDeuda = RegistrarPagoDeuda(
        pagoDeudaRepository: fakePagos,
        deudaRepository: fakeDeudas,
        cuentaRepository: fakeCuentas,
      );

      final pago = await registrarPagoDeuda(
        deudaId: 'd4',
        cuentaId: null,
        montoPagado: 300,
        fechaPago: DateTime(2025, 6, 1),
      );

      expect(pago.cuentaId, isNull);
      expect(fakeDeudas.deudas['d4']!.montoPagado, 300);
      expect(fakeCuentas.cuentas, isEmpty);
    },
  );
}
