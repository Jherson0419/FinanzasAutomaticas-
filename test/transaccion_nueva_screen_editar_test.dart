import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/placeholders/transaccion_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

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

class _FakeCategoriaRepository implements CategoriaRepository {
  final List<Categoria> categorias;
  _FakeCategoriaRepository(this.categorias);

  @override
  Future<Categoria?> obtenerPorId(String id) async {
    for (final categoria in categorias) {
      if (categoria.id == id) return categoria;
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

class _FakeTransaccionRepository implements TransaccionRepository {
  final Map<String, Transaccion> transacciones;
  _FakeTransaccionRepository(this.transacciones);

  @override
  Future<void> actualizar(Transaccion transaccion) async =>
      transacciones[transaccion.id] = transaccion;

  @override
  Future<void> crear(Transaccion transaccion) async =>
      transacciones[transaccion.id] = transaccion;

  @override
  Future<void> eliminar(String id) async => transacciones.remove(id);

  @override
  Future<Transaccion?> obtenerPorId(String id) async => transacciones[id];

  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async =>
      transacciones.values.where((t) => t.cuentaId == cuentaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      transacciones.values.where((t) => t.categoriaId == categoriaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => transacciones.values.toList();

  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async =>
      transacciones.values.toList();

  @override
  Future<List<Transaccion>> obtenerTodas() async =>
      transacciones.values.toList();
}

final _cuentaFixture = const Cuenta(
  id: 'cta-1',
  nombre: 'BCP Cuenta sueldo',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: 1000,
);

final _categoriaFixture = const Categoria(
  id: 'cat-gasto',
  nombre: 'Comida',
  tipo: TipoCategoria.gasto,
  iconName: 'restaurant',
);

final _transaccionFixture = Transaccion(
  id: 'tx-1',
  cuentaId: 'cta-1',
  categoriaId: 'cat-gasto',
  monto: 50,
  moneda: Moneda.pen,
  tipo: TipoTransaccion.gasto,
  concepto: 'Almuerzo',
  metodoPago: MetodoPago.efectivo,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: DateTime(2026, 1, 10),
);

Future<
  ({_FakeCuentaRepository cuentas, _FakeTransaccionRepository transacciones})
>
_pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeCuentas = _FakeCuentaRepository({'cta-1': _cuentaFixture});
  final fakeCategorias = _FakeCategoriaRepository([_categoriaFixture]);
  final fakeTransacciones = _FakeTransaccionRepository({
    'tx-1': _transaccionFixture,
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(fakeCuentas),
        categoriaRepositoryProvider.overrideWithValue(fakeCategorias),
        transaccionRepositoryProvider.overrideWithValue(fakeTransacciones),
      ],
      child: const MaterialApp(
        home: TransaccionNuevaScreen(transaccionId: 'tx-1'),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return (cuentas: fakeCuentas, transacciones: fakeTransacciones);
}

void main() {
  testWidgets(
    'el modo edición precarga los datos de la transacción existente',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);

      final campoMonto = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Monto'),
      );
      expect(campoMonto.controller?.text, '50.00');

      final campoConcepto = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Concepto (opcional)'),
      );
      expect(campoConcepto.controller?.text, 'Almuerzo');
    },
  );

  testWidgets(
    'eliminar con confirmación invoca EliminarTransaccion y revierte el saldo',
    (WidgetTester tester) async {
      final fakes = await _pumpScreen(tester);

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(find.text('Eliminar gasto'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(fakes.transacciones.transacciones.containsKey('tx-1'), isFalse);
      // Saldo original 1000, era un gasto de 50 -> al revertir queda 1050.
      expect(fakes.cuentas.cuentas['cta-1']!.saldoActual, 1050);
    },
  );
}
