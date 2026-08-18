import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/todos_los_movimientos_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Verifica explícitamente que `TransaccionRepository.obtenerTodas()` (sin
/// consumidor real hasta esta fase, según `INFORME_PROYECTO.md` §4) ahora
/// es lo que alimenta esta pantalla — no `obtenerPorCuenta` ni
/// `obtenerRecientes`.
class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  bool obtenerTodasFueLlamado = false;
  _FakeTransaccionRepository(this.transacciones);

  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async {
    throw StateError('No debería llamarse obtenerPorCuenta en esta pantalla');
  }

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      const [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async {
    throw StateError('No debería llamarse obtenerRecientes en esta pantalla');
  }

  @override
  Future<List<Transaccion>> obtenerTodas() async {
    obtenerTodasFueLlamado = true;
    return transacciones;
  }
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

void main() {
  testWidgets(
    'usa TransaccionRepository.obtenerTodas() y lista movimientos de todas las cuentas',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final deCuentaA = Transaccion(
        id: 'tx-1',
        cuentaId: 'cta-a',
        categoriaId: 'cat-1',
        monto: 25,
        moneda: Moneda.pen,
        tipo: TipoTransaccion.gasto,
        concepto: 'De cuenta A',
        metodoPago: MetodoPago.efectivo,
        esRecurrente: false,
        fuenteCaptura: FuenteCaptura.manual,
        fecha: DateTime(2026, 1, 1),
      );
      final deCuentaB = Transaccion(
        id: 'tx-2',
        cuentaId: 'cta-b',
        categoriaId: 'cat-1',
        monto: 40,
        moneda: Moneda.pen,
        tipo: TipoTransaccion.ingreso,
        concepto: 'De cuenta B',
        metodoPago: MetodoPago.transferencia,
        esRecurrente: false,
        fuenteCaptura: FuenteCaptura.manual,
        fecha: DateTime(2026, 2, 1),
      );

      final fakeTransacciones = _FakeTransaccionRepository([
        deCuentaA,
        deCuentaB,
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            datosEnLaNubeProvider.overrideWithValue(false),
            transaccionRepositoryProvider.overrideWithValue(fakeTransacciones),
            categoriaRepositoryProvider.overrideWithValue(
              _FakeCategoriaRepository(const [
                Categoria(
                  id: 'cat-1',
                  nombre: 'General',
                  tipo: TipoCategoria.gasto,
                  iconName: 'category',
                ),
              ]),
            ),
          ],
          child: const MaterialApp(home: TodosLosMovimientosScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(fakeTransacciones.obtenerTodasFueLlamado, isTrue);
      expect(find.text('De cuenta A'), findsOneWidget);
      expect(find.text('De cuenta B'), findsOneWidget);
    },
  );

  testWidgets('muestra el estado vacío cuando no hay movimientos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          datosEnLaNubeProvider.overrideWithValue(false),
          transaccionRepositoryProvider.overrideWithValue(
            _FakeTransaccionRepository([]),
          ),
          categoriaRepositoryProvider.overrideWithValue(
            _FakeCategoriaRepository(const []),
          ),
        ],
        child: const MaterialApp(home: TodosLosMovimientosScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Todavía no tienes movimientos registrados.'),
      findsOneWidget,
    );
  });
}
