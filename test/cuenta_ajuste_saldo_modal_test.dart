import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/cuenta_nueva_screen.dart';
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

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  _FakeTransaccionRepository(this.transacciones);

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

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  @override
  Future<void> crear(PagoDeuda pago) async {}

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => const [];

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => const [];

  @override
  Future<void> eliminar(String id) async {}
}

const _categoriasAjuste = [
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

final _cuentaFixture = const Cuenta(
  id: 'cta-1',
  nombre: 'Efectivo',
  tipo: TipoCuenta.efectivo,
  moneda: Moneda.pen,
  saldoActual: 100,
);

void main() {
  testWidgets(
    'el modal de ajuste invoca AjustarSaldoCuenta con la diferencia correcta',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeCuentas = _FakeCuentaRepository({'cta-1': _cuentaFixture});
      final fakeTransacciones = _FakeTransaccionRepository([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            datosEnLaNubeProvider.overrideWithValue(false),
            cuentaRepositoryProvider.overrideWithValue(fakeCuentas),
            transaccionRepositoryProvider.overrideWithValue(fakeTransacciones),
            categoriaRepositoryProvider.overrideWithValue(
              _FakeCategoriaRepository(_categoriasAjuste),
            ),
            pagoDeudaRepositoryProvider.overrideWithValue(
              _FakePagoDeudaRepository(),
            ),
          ],
          child: const MaterialApp(home: CuentaNuevaScreen(cuentaId: 'cta-1')),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Ajustar'));
      await tester.pumpAndSettle();

      final campoSaldoReal = find.widgetWithText(TextFormField, 'Saldo real');
      expect(campoSaldoReal, findsOneWidget);

      await tester.enterText(campoSaldoReal, '250');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar ajuste'));
      // Sin `pumpAndSettle` todavía — dejaría avanzar también el
      // auto-cierre del SnackBar antes de poder comprobar que apareció.
      await tester.pump();
      await tester.pump();

      expect(fakeTransacciones.transacciones, hasLength(1));
      final creada = fakeTransacciones.transacciones.single;
      expect(creada.tipo, TipoTransaccion.ingreso);
      expect(creada.monto, 150);
      expect(creada.fuenteCaptura, FuenteCaptura.ajuste);
      expect(fakeCuentas.cuentas['cta-1']!.saldoActual, 250);
      expect(find.text('Saldo ajustado'), findsOneWidget);

      await tester.pumpAndSettle();

      // El modal se cierra solo y vuelve a la pantalla de edición.
      expect(find.text('Ajustar saldo'), findsNothing);
      expect(find.text('S/ 250.00'), findsWidgets);
    },
  );

  testWidgets(
    'la moneda no es editable cuando la cuenta ya tiene movimientos',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final movimiento = Transaccion(
        id: 'tx-1',
        cuentaId: 'cta-1',
        categoriaId: 'cat-1',
        monto: 20,
        moneda: Moneda.pen,
        tipo: TipoTransaccion.gasto,
        concepto: 'Café',
        metodoPago: MetodoPago.efectivo,
        esRecurrente: false,
        fuenteCaptura: FuenteCaptura.manual,
        fecha: DateTime(2026, 1, 5),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            datosEnLaNubeProvider.overrideWithValue(false),
            cuentaRepositoryProvider.overrideWithValue(
              _FakeCuentaRepository({'cta-1': _cuentaFixture}),
            ),
            transaccionRepositoryProvider.overrideWithValue(
              _FakeTransaccionRepository([movimiento]),
            ),
            categoriaRepositoryProvider.overrideWithValue(
              _FakeCategoriaRepository(_categoriasAjuste),
            ),
            pagoDeudaRepositoryProvider.overrideWithValue(
              _FakePagoDeudaRepository(),
            ),
          ],
          child: const MaterialApp(home: CuentaNuevaScreen(cuentaId: 'cta-1')),
        ),
      );
      await tester.pumpAndSettle();

      final dropdownMoneda = tester.widget<DropdownButtonFormField<Moneda>>(
        find.widgetWithText(DropdownButtonFormField<Moneda>, 'Moneda'),
      );
      expect(dropdownMoneda.onChanged, isNull);
    },
  );
}
