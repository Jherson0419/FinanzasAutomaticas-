import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/sincronizar_deuda_tarjeta.dart';

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

Deuda _deudaVinculada({
  required String cuentaId,
  double montoTotal = 2000,
  double montoPagado = 2000,
}) {
  return Deuda(
    id: 'd1',
    nombreDeuda: 'Visa BCP',
    tipoDeuda: TipoDeuda.tarjetaCredito,
    tipoAcreedor: TipoAcreedor.entidadFinanciera,
    nombreAcreedor: 'Visa BCP',
    moneda: Moneda.pen,
    montoTotal: montoTotal,
    montoPagado: montoPagado,
    tieneInteres: false,
    estructuraPago: EstructuraPago.pagoLibre,
    fechaInicio: DateTime(2026, 1, 1),
    enMora: false,
    estado: EstadoDeuda.activa,
    cuentaId: cuentaId,
  );
}

void main() {
  test(
    'Fase 62: un gasto que deja la tarjeta con saldo negativo actualiza '
    'montoPagado de la deuda vinculada al mismo monto usado',
    () async {
      final fakeDeudas = _FakeDeudaRepository([_deudaVinculada(cuentaId: 'c1')]);
      final sincronizar = SincronizarDeudaTarjeta(deudaRepository: fakeDeudas);

      final cuenta = const Cuenta(
        id: 'c1',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: -800,
        lineaCredito: 2000,
      );

      await sincronizar(cuenta);

      final deuda = fakeDeudas.deudas.single;
      expect(deuda.montoTotal, 2000);
      expect(deuda.montoPagado, 1200);
      // El monto usado (deuda pendiente real) es exactamente lo gastado.
      expect(deuda.montoTotal - deuda.montoPagado, 800);
    },
  );

  test(
    'un ingreso (pago a la tarjeta) que reduce lo usado también actualiza '
    'montoPagado hacia arriba',
    () async {
      final fakeDeudas = _FakeDeudaRepository([
        _deudaVinculada(cuentaId: 'c1', montoPagado: 1200),
      ]);
      final sincronizar = SincronizarDeudaTarjeta(deudaRepository: fakeDeudas);

      // Se pagaron 500 de los 800 usados: saldoActual pasa de -800 a -300.
      final cuenta = const Cuenta(
        id: 'c1',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: -300,
        lineaCredito: 2000,
      );

      await sincronizar(cuenta);

      final deuda = fakeDeudas.deudas.single;
      expect(deuda.montoPagado, 1700);
      expect(deuda.montoTotal - deuda.montoPagado, 300);
    },
  );

  test('saldoActual en positivo o cero implica montoUsado 0 (todo pagado)', () async {
    final fakeDeudas = _FakeDeudaRepository([
      _deudaVinculada(cuentaId: 'c1', montoPagado: 1200),
    ]);
    final sincronizar = SincronizarDeudaTarjeta(deudaRepository: fakeDeudas);

    final cuenta = const Cuenta(
      id: 'c1',
      nombre: 'Visa BCP',
      tipo: TipoCuenta.credito,
      moneda: Moneda.pen,
      saldoActual: 0,
      lineaCredito: 2000,
    );

    await sincronizar(cuenta);

    expect(fakeDeudas.deudas.single.montoPagado, 2000);
  });

  test('no hace nada si la cuenta no es de tipo crédito', () async {
    final fakeDeudas = _FakeDeudaRepository([_deudaVinculada(cuentaId: 'c1')]);
    final sincronizar = SincronizarDeudaTarjeta(deudaRepository: fakeDeudas);

    final cuenta = const Cuenta(
      id: 'c1',
      nombre: 'Ahorros',
      tipo: TipoCuenta.debito,
      moneda: Moneda.pen,
      saldoActual: -800,
    );

    await sincronizar(cuenta);

    // La deuda (que en este caso de prueba no debería ni existir para una
    // cuenta de débito) queda intacta — el método corta antes de tocarla.
    expect(fakeDeudas.deudas.single.montoPagado, 2000);
  });

  test('no hace nada si la cuenta de crédito no tiene ninguna deuda vinculada', () async {
    final fakeDeudas = _FakeDeudaRepository([]);
    final sincronizar = SincronizarDeudaTarjeta(deudaRepository: fakeDeudas);

    final cuenta = const Cuenta(
      id: 'c1',
      nombre: 'Visa BCP',
      tipo: TipoCuenta.credito,
      moneda: Moneda.pen,
      saldoActual: -800,
      lineaCredito: 2000,
    );

    await sincronizar(cuenta);

    expect(fakeDeudas.deudas, isEmpty);
  });
}
