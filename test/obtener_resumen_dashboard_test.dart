import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/obtener_resumen_dashboard.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final List<Cuenta> cuentas;
  _FakeCuentaRepository(this.cuentas);
  @override
  Future<void> actualizar(Cuenta cuenta) async {}
  @override
  Future<void> crear(Cuenta cuenta) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Cuenta?> obtenerPorId(String id) async => null;
  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas;
}

class _FakeTransaccionRepository implements TransaccionRepository {
  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerTodas() async => [];
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => [];
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

class _FakeCategoriaRepository implements CategoriaRepository {
  @override
  Future<Categoria?> obtenerPorId(String id) async => null;
  @override
  Future<List<Categoria>> obtenerTodas() async => [];
  @override
  Future<void> crear(Categoria categoria) async {}
  @override
  Future<void> actualizar(Categoria categoria) async {}
  @override
  Future<void> eliminar(String id) async {}
}

class _FakeDeudaRepository implements DeudaRepository {
  @override
  Future<void> actualizar(Deuda deuda) async {}
  @override
  Future<void> crear(Deuda deuda) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Deuda?> obtenerPorId(String id) async => null;
  @override
  Future<List<Deuda>> obtenerTodas() async => [];
  @override
  Future<List<Deuda>> obtenerActivas() async => [];
}

void main() {
  test(
    'Fase 62: "Saldo total" excluye cuentas de crédito, aunque su saldo '
    'esté en positivo',
    () async {
      final cuentas = [
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
        const Cuenta(
          id: 'c2',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 200,
        ),
        const Cuenta(
          id: 'c3',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          // Si esto se sumara, el total daría 2200 en vez de 1200 — el bug
          // exacto que reportó el usuario (Saldo total inflado/distorsionado
          // por una tarjeta).
          saldoActual: 1000,
          lineaCredito: 2000,
        ),
      ];

      final obtenerResumen = ObtenerResumenDashboard(
        cuentaRepository: _FakeCuentaRepository(cuentas),
        transaccionRepository: _FakeTransaccionRepository(),
        categoriaRepository: _FakeCategoriaRepository(),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resumen = await obtenerResumen();

      expect(resumen.saldoTotalPorMoneda[Moneda.pen], 1200);
    },
  );

  test(
    'Fase 62: una tarjeta con saldo negativo (usada) tampoco resta del '
    'Saldo total — sigue completamente excluida',
    () async {
      final cuentas = [
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
        const Cuenta(
          id: 'c3',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -800,
          lineaCredito: 2000,
        ),
      ];

      final obtenerResumen = ObtenerResumenDashboard(
        cuentaRepository: _FakeCuentaRepository(cuentas),
        transaccionRepository: _FakeTransaccionRepository(),
        categoriaRepository: _FakeCategoriaRepository(),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resumen = await obtenerResumen();

      expect(resumen.saldoTotalPorMoneda[Moneda.pen], 1000);
    },
  );
}
