import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
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
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      const [];
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

final _cuentasFixture = [
  const Cuenta(
    id: 'cta-1',
    nombre: 'BCP Cuenta sueldo',
    tipo: TipoCuenta.debito,
    moneda: Moneda.pen,
    saldoActual: 1000,
  ),
];

final _categoriasFixture = [
  const Categoria(
    id: 'cat-gasto',
    nombre: 'Comida',
    tipo: TipoCategoria.gasto,
    iconName: 'restaurant',
  ),
  const Categoria(
    id: 'cat-ingreso',
    nombre: 'Sueldo',
    tipo: TipoCategoria.ingreso,
    iconName: 'payments',
  ),
];

Future<void> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cuentasProvider.overrideWith((ref) => _cuentasFixture),
        categoriasProvider.overrideWith((ref) => _categoriasFixture),
      ],
      child: const MaterialApp(home: TransaccionNuevaScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el botón Guardar está deshabilitado con el formulario vacío', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets(
    'el botón Guardar se habilita al completar monto, cuenta y categoría',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto'),
        '25.50',
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCP Cuenta sueldo (S/)').last);
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Categoría'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Comida').last);
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNotNull);
    },
  );

  testWidgets('guardar un gasto válido muestra el SnackBar "Gasto guardado"', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeTransacciones = _FakeTransaccionRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          datosEnLaNubeProvider.overrideWithValue(false),
          cuentaRepositoryProvider.overrideWithValue(
            _FakeCuentaRepository({
              for (final cuenta in _cuentasFixture) cuenta.id: cuenta,
            }),
          ),
          transaccionRepositoryProvider.overrideWithValue(fakeTransacciones),
          cuentasProvider.overrideWith((ref) => _cuentasFixture),
          categoriasProvider.overrideWith((ref) => _categoriasFixture),
        ],
        child: const MaterialApp(home: TransaccionNuevaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto'),
      '25.50',
    );
    await tester.pump();

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCP Cuenta sueldo (S/)').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'Categoría'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comida').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    // Sin `pumpAndSettle` todavía — dejaría avanzar también el
    // auto-cierre del SnackBar antes de poder comprobar que apareció.
    await tester.pump();
    await tester.pump();

    expect(fakeTransacciones.transacciones, hasLength(1));
    expect(fakeTransacciones.transacciones.single.monto, 25.50);
    expect(find.text('Gasto guardado'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
