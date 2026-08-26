import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_deuda.dart';

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
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];
  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();
  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values.toList();
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  @override
  Future<void> crear(PagoDeuda pago) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => [];
}

Deuda _deudaNormal({String id = 'd1'}) => Deuda(
  id: id,
  nombreDeuda: 'Préstamo personal',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 1000,
  montoPagado: 0,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

void main() {
  test('elimina una deuda normal sin pagos', () async {
    final fakeDeudas = _FakeDeudaRepository({'d1': _deudaNormal()});
    final eliminarDeuda = EliminarDeuda(
      deudaRepository: fakeDeudas,
      pagoDeudaRepository: _FakePagoDeudaRepository(),
    );

    await eliminarDeuda(deudaId: 'd1');

    expect(fakeDeudas.deudas, isEmpty);
  });

  test(
    'Fase 62: rechaza eliminar una deuda vinculada a una tarjeta de crédito',
    () async {
      final deudaVinculada = Deuda(
        id: 'd2',
        nombreDeuda: 'Visa BCP',
        tipoDeuda: TipoDeuda.tarjetaCredito,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'Visa BCP',
        moneda: Moneda.pen,
        montoTotal: 2000,
        montoPagado: 1200,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
        cuentaId: 'cta-credito',
      );
      final fakeDeudas = _FakeDeudaRepository({'d2': deudaVinculada});
      final eliminarDeuda = EliminarDeuda(
        deudaRepository: fakeDeudas,
        pagoDeudaRepository: _FakePagoDeudaRepository(),
      );

      await expectLater(
        () => eliminarDeuda(deudaId: 'd2'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cuenta de crédito directamente'),
          ),
        ),
      );
      expect(fakeDeudas.deudas, contains('d2'));
    },
  );
}
