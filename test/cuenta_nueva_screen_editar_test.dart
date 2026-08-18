import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
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

final _cuentaFixture = const Cuenta(
  id: 'cta-1',
  nombre: 'Efectivo',
  tipo: TipoCuenta.efectivo,
  moneda: Moneda.pen,
  saldoActual: 250,
);

Future<_FakeCuentaRepository> _pumpScreen(
  WidgetTester tester, {
  List<Transaccion> transacciones = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeCuentas = _FakeCuentaRepository({'cta-1': _cuentaFixture});

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(fakeCuentas),
        transaccionRepositoryProvider.overrideWithValue(
          _FakeTransaccionRepository(transacciones),
        ),
        pagoDeudaRepositoryProvider.overrideWithValue(
          _FakePagoDeudaRepository(),
        ),
      ],
      child: const MaterialApp(home: CuentaNuevaScreen(cuentaId: 'cta-1')),
    ),
  );
  await tester.pumpAndSettle();

  return fakeCuentas;
}

void main() {
  testWidgets(
    'el modo edición precarga los datos de la cuenta y el saldo es de solo lectura',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      expect(find.text('Editar cuenta'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);

      final campoNombre = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
      );
      expect(campoNombre.controller?.text, 'Efectivo');

      expect(find.text('Saldo actual'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Saldo inicial'), findsNothing);
    },
  );

  testWidgets(
    'eliminar una cuenta con movimientos registrados muestra el error en un diálogo',
    (WidgetTester tester) async {
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
      final fakeCuentas = await _pumpScreen(
        tester,
        transacciones: [movimiento],
      );

      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Eliminar cuenta'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Eliminar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo eliminar'), findsOneWidget);
      expect(
        find.text(
          'No se puede eliminar una cuenta con movimientos registrados',
        ),
        findsOneWidget,
      );
      expect(fakeCuentas.cuentas.containsKey('cta-1'), isTrue);
    },
  );
}
