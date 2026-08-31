import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_cuenta.dart';

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

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  _FakeTransaccionRepository([this.transacciones = const []]);
  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerTodas() async => transacciones;
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async =>
      transacciones.where((t) => t.cuentaId == cuentaId).toList();
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async => [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => [];
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  @override
  Future<void> crear(PagoDeuda pago) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => [];
}

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async {
    final indice = deudas.indexWhere((d) => d.id == deuda.id);
    if (indice != -1) deudas[indice] = deuda;
  }

  @override
  Future<void> crear(Deuda deuda) async => deudas.add(deuda);

  @override
  Future<void> eliminar(String id) async =>
      deudas.removeWhere((d) => d.id == id);

  @override
  Future<Deuda?> obtenerPorId(String id) async {
    for (final d in deudas) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas;

  @override
  Future<List<Deuda>> obtenerActivas() async =>
      deudas.where((d) => d.estado == EstadoDeuda.activa).toList();
}

void main() {
  test('elimina una cuenta sin movimientos ni deuda vinculada', () async {
    final fakeCuentas = _FakeCuentaRepository({
      'c1': const Cuenta(
        id: 'c1',
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 100,
      ),
    });
    final eliminarCuenta = EliminarCuenta(
      cuentaRepository: fakeCuentas,
      transaccionRepository: _FakeTransaccionRepository(),
      pagoDeudaRepository: _FakePagoDeudaRepository(),
      deudaRepository: _FakeDeudaRepository([]),
    );

    await eliminarCuenta(cuentaId: 'c1');

    expect(fakeCuentas.cuentas, isEmpty);
  });

  test(
    'Fase 62: al eliminar una cuenta de crédito, elimina también su Deuda '
    'vinculada en la misma operación',
    () async {
      final fakeCuentas = _FakeCuentaRepository({
        'cta-credito': const Cuenta(
          id: 'cta-credito',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: 0,
          lineaCredito: 2000,
        ),
      });
      final deudaVinculada = Deuda(
        id: 'd1',
        nombreDeuda: 'Visa BCP',
        tipoDeuda: TipoDeuda.tarjetaCredito,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'Visa BCP',
        moneda: Moneda.pen,
        montoTotal: 2000,
        montoPagado: 2000,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
        cuentaId: 'cta-credito',
      );
      final fakeDeudas = _FakeDeudaRepository([deudaVinculada]);
      final eliminarCuenta = EliminarCuenta(
        cuentaRepository: fakeCuentas,
        transaccionRepository: _FakeTransaccionRepository(),
        pagoDeudaRepository: _FakePagoDeudaRepository(),
        deudaRepository: fakeDeudas,
      );

      await eliminarCuenta(cuentaId: 'cta-credito');

      expect(fakeCuentas.cuentas, isEmpty);
      expect(fakeDeudas.deudas, isEmpty);
    },
  );

  test(
    'no se puede eliminar una cuenta con movimientos, y su deuda vinculada '
    '(si tuviera) tampoco se toca',
    () async {
      final fakeCuentas = _FakeCuentaRepository({
        'c1': const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 100,
        ),
      });
      final transaccion = Transaccion(
        id: 't1',
        cuentaId: 'c1',
        categoriaId: 'cat-1',
        monto: 50,
        moneda: Moneda.pen,
        tipo: TipoTransaccion.gasto,
        concepto: 'Algo',
        metodoPago: MetodoPago.efectivo,
        esRecurrente: false,
        fuenteCaptura: FuenteCaptura.manual,
        fecha: DateTime(2026, 1, 1),
      );
      final eliminarCuenta = EliminarCuenta(
        cuentaRepository: fakeCuentas,
        transaccionRepository: _FakeTransaccionRepository([transaccion]),
        pagoDeudaRepository: _FakePagoDeudaRepository(),
        deudaRepository: _FakeDeudaRepository([]),
      );

      await expectLater(
        () => eliminarCuenta(cuentaId: 'c1'),
        throwsStateError,
      );
      expect(fakeCuentas.cuentas, contains('c1'));
    },
  );
}
