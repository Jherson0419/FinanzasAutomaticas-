import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/movimientos_cuenta_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  _FakeTransaccionRepository(this.transacciones);

  @override
  Future<void> actualizar(Transaccion transaccion) async {}

  @override
  Future<void> crear(Transaccion transaccion) async {}

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

const _categoriaComida = Categoria(
  id: 'cat-comida',
  nombre: 'Comida',
  tipo: TipoCategoria.gasto,
  iconName: 'restaurant',
);

const _categoriaAjusteIngreso = Categoria(
  id: 'cat-ajuste-ingreso',
  nombre: 'Ajuste de saldo',
  tipo: TipoCategoria.ingreso,
  iconName: 'tune',
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required List<Transaccion> transacciones,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        transaccionRepositoryProvider.overrideWithValue(
          _FakeTransaccionRepository(transacciones),
        ),
        categoriaRepositoryProvider.overrideWithValue(
          _FakeCategoriaRepository([_categoriaComida, _categoriaAjusteIngreso]),
        ),
      ],
      child: const MaterialApp(
        home: MovimientosCuentaScreen(cuentaId: 'cta-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lista solo los movimientos de la cuenta indicada', (
    WidgetTester tester,
  ) async {
    final deEstaCuenta = Transaccion(
      id: 'tx-1',
      cuentaId: 'cta-1',
      categoriaId: 'cat-comida',
      monto: 25,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      concepto: 'Almuerzo',
      metodoPago: MetodoPago.efectivo,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime(2026, 3, 1),
    );
    final deOtraCuenta = Transaccion(
      id: 'tx-2',
      cuentaId: 'cta-2',
      categoriaId: 'cat-comida',
      monto: 999,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      concepto: 'No debería aparecer',
      metodoPago: MetodoPago.efectivo,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime(2026, 3, 2),
    );

    await _pumpScreen(tester, transacciones: [deEstaCuenta, deOtraCuenta]);

    expect(find.text('Almuerzo'), findsOneWidget);
    expect(find.text('No debería aparecer'), findsNothing);
  });

  testWidgets('ordena los movimientos por fecha descendente', (
    WidgetTester tester,
  ) async {
    final antiguo = Transaccion(
      id: 'tx-1',
      cuentaId: 'cta-1',
      categoriaId: 'cat-comida',
      monto: 25,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      concepto: 'Antiguo',
      metodoPago: MetodoPago.efectivo,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime(2026, 1, 1),
    );
    final reciente = Transaccion(
      id: 'tx-2',
      cuentaId: 'cta-1',
      categoriaId: 'cat-comida',
      monto: 40,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      concepto: 'Reciente',
      metodoPago: MetodoPago.efectivo,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime(2026, 3, 1),
    );

    await _pumpScreen(tester, transacciones: [antiguo, reciente]);

    final dyReciente = tester.getTopLeft(find.text('Reciente')).dy;
    final dyAntiguo = tester.getTopLeft(find.text('Antiguo')).dy;
    expect(dyReciente, lessThan(dyAntiguo));
  });

  testWidgets('un movimiento de ajuste muestra el badge "Ajuste"', (
    WidgetTester tester,
  ) async {
    final ajuste = Transaccion(
      id: 'tx-1',
      cuentaId: 'cta-1',
      categoriaId: 'cat-ajuste-ingreso',
      monto: 500,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.ingreso,
      concepto: 'Ajuste de saldo',
      metodoPago: MetodoPago.otro,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.ajuste,
      fecha: DateTime(2026, 3, 1),
    );

    await _pumpScreen(tester, transacciones: [ajuste]);

    expect(find.text('Ajuste'), findsOneWidget);
  });

  testWidgets('muestra el estado vacío cuando no hay movimientos', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, transacciones: []);

    expect(
      find.text('Todavía no hay movimientos registrados en esta cuenta.'),
      findsOneWidget,
    );
  });
}
