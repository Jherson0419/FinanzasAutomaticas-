import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/pago_deuda_nuevo_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas;
  _FakeCuentaRepository(this.cuentas);

  @override
  Future<void> actualizar(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> crear(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<Cuenta?> obtenerPorId(String id) async => cuentas[id];

  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas.values.toList();

  @override
  Future<void> eliminar(String id) async => cuentas.remove(id);
}

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<void> actualizar(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values
      .where(
        (d) => d.estado == EstadoDeuda.activa || d.estado == EstadoDeuda.enMora,
      )
      .toList();

  @override
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  final List<PagoDeuda> pagos = [];

  @override
  Future<void> crear(PagoDeuda pago) async => pagos.add(pago);

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async =>
      pagos.where((p) => p.deudaId == deudaId).toList();

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async =>
      pagos.where((p) => p.cuentaId == cuentaId).toList();

  @override
  Future<void> eliminar(String id) async {
    pagos.removeWhere((p) => p.id == id);
  }
}

final _cuentaFixture = const Cuenta(
  id: 'cta-1',
  nombre: 'BCP Cuenta sueldo',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: 5000,
);

final _cuentaUsdFixture = const Cuenta(
  id: 'cta-usd',
  nombre: 'Ahorros USD',
  tipo: TipoCuenta.debito,
  moneda: Moneda.usd,
  saldoActual: 800,
);

Deuda _deudaPagoLibre({required String id}) => Deuda(
  id: id,
  nombreDeuda: 'Tarjeta BBVA',
  tipoDeuda: TipoDeuda.tarjetaCredito,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BBVA',
  moneda: Moneda.pen,
  montoTotal: 500,
  montoPagado: 400,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

Deuda _deudaConInteres({required String id}) => Deuda(
  id: id,
  nombreDeuda: 'Préstamo personal',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 3000,
  montoPagado: 600,
  tieneInteres: true,
  tasaInteres: 10,
  tipoTasa: TipoTasa.fija,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: 10,
  numeroCuotasPagadas: 2,
  montoCuota: 300,
  diaPago: 15,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

Future<_FakeDeudaRepository> _pumpScreen(
  WidgetTester tester, {
  required Deuda deuda,
  required _FakeCuentaRepository fakeCuentas,
  required _FakeDeudaRepository fakeDeudas,
  required _FakePagoDeudaRepository fakePagos,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(fakeCuentas),
        deudaRepositoryProvider.overrideWithValue(fakeDeudas),
        pagoDeudaRepositoryProvider.overrideWithValue(fakePagos),
      ],
      child: MaterialApp(home: PagoDeudaNuevoScreen(deudaId: deuda.id)),
    ),
  );
  await tester.pumpAndSettle();
  return fakeDeudas;
}

void main() {
  testWidgets('el botón Guardar está deshabilitado con el formulario vacío', (
    WidgetTester tester,
  ) async {
    final deuda = _deudaPagoLibre(id: 'deuda-1');
    await _pumpScreen(
      tester,
      deuda: deuda,
      fakeCuentas: _FakeCuentaRepository({'cta-1': _cuentaFixture}),
      fakeDeudas: _FakeDeudaRepository({'deuda-1': deuda}),
      fakePagos: _FakePagoDeudaRepository(),
    );

    final boton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(boton.onPressed, isNull);
  });

  testWidgets(
    'muestra error inline cuando capital + interés no cuadra con el monto pagado',
    (WidgetTester tester) async {
      final deuda = _deudaConInteres(id: 'deuda-2');
      await _pumpScreen(
        tester,
        deuda: deuda,
        fakeCuentas: _FakeCuentaRepository({'cta-1': _cuentaFixture}),
        fakeDeudas: _FakeDeudaRepository({'deuda-2': deuda}),
        fakePagos: _FakePagoDeudaRepository(),
      );

      // El monto pagado ya viene prellenado con el montoCuota (300).
      expect(
        find.widgetWithText(TextFormField, 'Monto pagado'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto a capital'),
        '100',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto a interés'),
        '100',
      );
      await tester.pump();

      expect(
        find.text('Capital + interés debe sumar el monto pagado'),
        findsOneWidget,
      );

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'un pago que cubre el monto total restante marca la deuda como pagada',
    (WidgetTester tester) async {
      final deuda = _deudaPagoLibre(id: 'deuda-3');
      final fakeDeudas = await _pumpScreen(
        tester,
        deuda: deuda,
        fakeCuentas: _FakeCuentaRepository({'cta-1': _cuentaFixture}),
        fakeDeudas: _FakeDeudaRepository({'deuda-3': deuda}),
        fakePagos: _FakePagoDeudaRepository(),
      );

      // La deuda debe 500 - 400 = 100.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto pagado'),
        '100',
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Cuenta de origen',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCP Cuenta sueldo (S/)').last);
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      // Sin `pumpAndSettle` todavía — dejaría avanzar también el
      // auto-cierre del SnackBar antes de poder comprobar que apareció.
      await tester.pump();
      await tester.pump();

      expect(fakeDeudas.deudas['deuda-3']!.estado, EstadoDeuda.pagada);
      expect(fakeDeudas.deudas['deuda-3']!.montoPagado, 500);
      expect(find.text('Pago registrado'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'el dropdown de cuenta solo lista cuentas en la moneda de la deuda',
    (WidgetTester tester) async {
      final deuda = _deudaPagoLibre(id: 'deuda-4');
      await _pumpScreen(
        tester,
        deuda: deuda,
        fakeCuentas: _FakeCuentaRepository({
          'cta-1': _cuentaFixture,
          'cta-usd': _cuentaUsdFixture,
        }),
        fakeDeudas: _FakeDeudaRepository({'deuda-4': deuda}),
        fakePagos: _FakePagoDeudaRepository(),
      );

      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Cuenta de origen',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('BCP Cuenta sueldo (S/)'), findsWidgets);
      expect(find.text('Ahorros USD (US\$)'), findsNothing);
    },
  );

  testWidgets(
    'sin cuentas en la moneda de la deuda muestra el mensaje y el botón queda deshabilitado',
    (WidgetTester tester) async {
      final deuda = _deudaPagoLibre(id: 'deuda-5');
      await _pumpScreen(
        tester,
        deuda: deuda,
        fakeCuentas: _FakeCuentaRepository({'cta-usd': _cuentaUsdFixture}),
        fakeDeudas: _FakeDeudaRepository({'deuda-5': deuda}),
        fakePagos: _FakePagoDeudaRepository(),
      );

      expect(
        find.textContaining('No tienes ninguna cuenta en Soles (PEN)'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto pagado'),
        '100',
      );
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'sin cuentas en la moneda: marcar el pago como retroactivo habilita el botón y no descuenta saldo',
    (WidgetTester tester) async {
      final deuda = _deudaPagoLibre(id: 'deuda-6');
      final fakeCuentas = _FakeCuentaRepository({'cta-usd': _cuentaUsdFixture});
      final fakeDeudas = _FakeDeudaRepository({'deuda-6': deuda});
      final fakePagos = _FakePagoDeudaRepository();
      await _pumpScreen(
        tester,
        deuda: deuda,
        fakeCuentas: fakeCuentas,
        fakeDeudas: fakeDeudas,
        fakePagos: fakePagos,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto pagado'),
        '100',
      );
      await tester.tap(find.text('Este pago ya ocurrió antes'));
      await tester.pumpAndSettle();

      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      // Sin `pumpAndSettle` todavía — dejaría avanzar también el
      // auto-cierre del SnackBar antes de poder comprobar que apareció.
      await tester.pump();
      await tester.pump();

      expect(fakePagos.pagos.single.cuentaId, isNull);
      expect(
        fakeCuentas.cuentas['cta-usd']!.saldoActual,
        _cuentaUsdFixture.saldoActual,
      );
      expect(find.text('Pago registrado'), findsOneWidget);

      await tester.pumpAndSettle();
    },
  );
}
