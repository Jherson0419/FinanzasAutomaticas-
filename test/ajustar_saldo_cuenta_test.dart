import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/ajustar_saldo_cuenta.dart';

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
  final List<Transaccion> transacciones = [];

  @override
  Future<void> crear(Transaccion transaccion) async =>
      transacciones.add(transaccion);

  @override
  Future<void> actualizar(Transaccion transaccion) async {}

  @override
  Future<void> eliminar(String id) async {}

  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;

  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async =>
      transacciones.where((t) => t.cuentaId == cuentaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      transacciones.where((t) => t.categoriaId == categoriaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];

  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];

  @override
  Future<List<Transaccion>> obtenerTodas() async => transacciones;
}

class _FakeCategoriaRepository implements CategoriaRepository {
  final List<Categoria> categorias;
  _FakeCategoriaRepository(this.categorias);

  @override
  Future<Categoria?> obtenerPorId(String id) async {
    for (final c in categorias) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<Categoria>> obtenerTodas() async => categorias;

  @override
  Future<void> crear(Categoria categoria) async {}

  @override
  Future<void> actualizar(Categoria categoria) async {}

  @override
  Future<void> eliminar(String id) async {}
}

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas = [];

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

final _categoriasAjuste = const [
  Categoria(
    id: 'cat-ajuste-ingreso',
    nombre: 'Ajuste de saldo',
    tipo: TipoCategoria.ingreso,
    iconName: 'tune',
  ),
  Categoria(
    id: 'cat-ajuste-gasto',
    nombre: 'Ajuste de saldo',
    tipo: TipoCategoria.gasto,
    iconName: 'tune',
  ),
];

void main() {
  test(
    'diferencia positiva: crea una transacción tipo ingreso con la categoría de ajuste',
    () async {
      final fakeCuentas = _FakeCuentaRepository({
        'cta-1': const Cuenta(
          id: 'cta-1',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 100,
        ),
      });
      final fakeTransacciones = _FakeTransaccionRepository();
      final ajustarSaldo = AjustarSaldoCuenta(
        cuentaRepository: fakeCuentas,
        transaccionRepository: fakeTransacciones,
        categoriaRepository: _FakeCategoriaRepository(_categoriasAjuste),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resultado = await ajustarSaldo(cuentaId: 'cta-1', saldoReal: 150);

      expect(resultado, isNotNull);
      expect(resultado!.tipo, TipoTransaccion.ingreso);
      expect(resultado.monto, 50);
      expect(resultado.categoriaId, 'cat-ajuste-ingreso');
      expect(resultado.fuenteCaptura, FuenteCaptura.ajuste);
      expect(fakeTransacciones.transacciones, hasLength(1));
      expect(fakeCuentas.cuentas['cta-1']!.saldoActual, 150);
    },
  );

  test(
    'diferencia negativa: crea una transacción tipo gasto con la categoría de ajuste',
    () async {
      final fakeCuentas = _FakeCuentaRepository({
        'cta-1': const Cuenta(
          id: 'cta-1',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 100,
        ),
      });
      final fakeTransacciones = _FakeTransaccionRepository();
      final ajustarSaldo = AjustarSaldoCuenta(
        cuentaRepository: fakeCuentas,
        transaccionRepository: fakeTransacciones,
        categoriaRepository: _FakeCategoriaRepository(_categoriasAjuste),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resultado = await ajustarSaldo(cuentaId: 'cta-1', saldoReal: 30);

      expect(resultado, isNotNull);
      expect(resultado!.tipo, TipoTransaccion.gasto);
      expect(resultado.monto, 70);
      expect(resultado.categoriaId, 'cat-ajuste-gasto');
      expect(resultado.fuenteCaptura, FuenteCaptura.ajuste);
      expect(fakeCuentas.cuentas['cta-1']!.saldoActual, 30);
    },
  );

  test(
    'diferencia cero: no crea ninguna transacción ni modifica el saldo',
    () async {
      final fakeCuentas = _FakeCuentaRepository({
        'cta-1': const Cuenta(
          id: 'cta-1',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 100,
        ),
      });
      final fakeTransacciones = _FakeTransaccionRepository();
      final ajustarSaldo = AjustarSaldoCuenta(
        cuentaRepository: fakeCuentas,
        transaccionRepository: fakeTransacciones,
        categoriaRepository: _FakeCategoriaRepository(_categoriasAjuste),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resultado = await ajustarSaldo(cuentaId: 'cta-1', saldoReal: 100);

      expect(resultado, isNull);
      expect(fakeTransacciones.transacciones, isEmpty);
      expect(fakeCuentas.cuentas['cta-1']!.saldoActual, 100);
    },
  );
}
