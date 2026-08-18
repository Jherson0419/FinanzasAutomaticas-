import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/placeholders/deuda_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<void> actualizar(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);

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
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  final List<PagoDeuda> pagos;
  _FakePagoDeudaRepository(this.pagos);

  @override
  Future<void> crear(PagoDeuda pago) async => pagos.add(pago);

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async =>
      pagos.where((p) => p.cuentaId == cuentaId).toList();

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async =>
      pagos.where((p) => p.deudaId == deudaId).toList();

  @override
  Future<void> eliminar(String id) async {
    pagos.removeWhere((p) => p.id == id);
  }
}

Deuda _deudaFixture() => Deuda(
  id: 'deuda-1',
  nombreDeuda: 'Préstamo personal',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 3000,
  montoPagado: 0,
  tieneInteres: false,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: 10,
  numeroCuotasPagadas: 0,
  montoCuota: 300,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
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
        deudaRepositoryProvider.overrideWithValue(fakeDeudas),
        pagoDeudaRepositoryProvider.overrideWithValue(fakePagos),
      ],
      child: const MaterialApp(home: DeudaNuevaScreen(deudaId: 'deuda-1')),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('el modo edición precarga los datos de la deuda existente', (
    WidgetTester tester,
  ) async {
    final deuda = _deudaFixture();
    await _pumpScreen(
      tester,
      fakeDeudas: _FakeDeudaRepository({'deuda-1': deuda}),
      fakePagos: _FakePagoDeudaRepository([]),
    );

    expect(find.text('Editar deuda'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);

    final campoNombre = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Nombre de la deuda'),
    );
    expect(campoNombre.controller?.text, 'Préstamo personal');

    final campoMontoTotal = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Monto total'),
    );
    expect(campoMontoTotal.controller?.text, '3000.00');
  });

  testWidgets(
    'eliminar una deuda con pagos registrados muestra el error en un diálogo',
    (WidgetTester tester) async {
      final deuda = _deudaFixture();
      final pago = PagoDeuda(
        id: 'pago-1',
        deudaId: 'deuda-1',
        cuentaId: 'cta-1',
        montoPagado: 300,
        fechaPago: DateTime(2026, 2, 1),
      );
      final fakeDeudas = _FakeDeudaRepository({'deuda-1': deuda});
      await _pumpScreen(
        tester,
        fakeDeudas: fakeDeudas,
        fakePagos: _FakePagoDeudaRepository([pago]),
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo eliminar'), findsOneWidget);
      expect(
        find.text('No se puede eliminar una deuda con pagos registrados'),
        findsOneWidget,
      );
      // La deuda no se borró.
      expect(fakeDeudas.deudas.containsKey('deuda-1'), isTrue);
    },
  );
}
