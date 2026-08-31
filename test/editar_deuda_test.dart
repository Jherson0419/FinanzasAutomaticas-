import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_deuda.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

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
  final List<PagoDeuda> pagos = [];
  @override
  Future<void> crear(PagoDeuda pago) async => pagos.add(pago);
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async =>
      pagos.where((p) => p.deudaId == deudaId).toList();
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

Deuda _deudaVinculada({String id = 'd2'}) => Deuda(
  id: id,
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

void main() {
  test('permite editar una deuda normal (cuentaId null)', () async {
    final fakeDeudas = _FakeDeudaRepository({'d1': _deudaNormal()});
    final editarDeuda = EditarDeuda(
      deudaRepository: fakeDeudas,
      pagoDeudaRepository: _FakePagoDeudaRepository(),
    );

    final actualizada = await editarDeuda(
      deudaId: 'd1',
      nombreDeuda: 'Préstamo personal (renombrado)',
      tipoDeuda: TipoDeuda.prestamoPersonal,
      tipoAcreedor: TipoAcreedor.entidadFinanciera,
      nombreAcreedor: 'BCP',
      moneda: Moneda.pen,
      montoTotal: 1200,
      estructuraPago: EstructuraPago.pagoLibre,
      fechaInicio: DateTime(2026, 1, 1),
    );

    expect(actualizada.nombreDeuda, 'Préstamo personal (renombrado)');
    expect(actualizada.montoTotal, 1200);
  });

  test(
    'Fase 62: rechaza editar una deuda vinculada a una tarjeta de crédito',
    () async {
      final fakeDeudas = _FakeDeudaRepository({'d2': _deudaVinculada()});
      final editarDeuda = EditarDeuda(
        deudaRepository: fakeDeudas,
        pagoDeudaRepository: _FakePagoDeudaRepository(),
      );

      await expectLater(
        () => editarDeuda(
          deudaId: 'd2',
          nombreDeuda: 'Otro nombre',
          tipoDeuda: TipoDeuda.tarjetaCredito,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: 'Visa BCP',
          moneda: Moneda.pen,
          montoTotal: 3000,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime(2026, 1, 1),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cuenta de crédito directamente'),
          ),
        ),
      );
      // Nada cambió: el rechazo ocurrió antes de escribir.
      expect(fakeDeudas.deudas['d2']!.montoTotal, 2000);
    },
  );

  test('Fase 64: editar una deuda puede vincularla a un amigo', () async {
    final fakeDeudas = _FakeDeudaRepository({'d1': _deudaNormal()});
    final editarDeuda = EditarDeuda(
      deudaRepository: fakeDeudas,
      pagoDeudaRepository: _FakePagoDeudaRepository(),
    );

    final actualizada = await editarDeuda(
      deudaId: 'd1',
      nombreDeuda: 'Préstamo personal',
      tipoDeuda: TipoDeuda.deudaInformal,
      tipoAcreedor: TipoAcreedor.personaNatural,
      nombreAcreedor: 'jherson23',
      moneda: Moneda.pen,
      montoTotal: 1000,
      estructuraPago: EstructuraPago.pagoLibre,
      fechaInicio: DateTime(2026, 1, 1),
      amigoUsuarioId: 'user-amigo',
    );

    expect(actualizada.amigoUsuarioId, 'user-amigo');
  });

  test(
    'Fase 64: no pasar amigoUsuarioId al editar la desvincula (queda null)',
    () async {
      final deudaVinculada = _deudaNormal().copyWith();
      final fakeDeudas = _FakeDeudaRepository({
        'd1': Deuda(
          id: deudaVinculada.id,
          nombreDeuda: deudaVinculada.nombreDeuda,
          tipoDeuda: deudaVinculada.tipoDeuda,
          tipoAcreedor: TipoAcreedor.personaNatural,
          nombreAcreedor: 'jherson23',
          moneda: deudaVinculada.moneda,
          montoTotal: deudaVinculada.montoTotal,
          montoPagado: deudaVinculada.montoPagado,
          tieneInteres: deudaVinculada.tieneInteres,
          estructuraPago: deudaVinculada.estructuraPago,
          fechaInicio: deudaVinculada.fechaInicio,
          enMora: deudaVinculada.enMora,
          estado: deudaVinculada.estado,
          amigoUsuarioId: 'user-amigo',
        ),
      });
      final editarDeuda = EditarDeuda(
        deudaRepository: fakeDeudas,
        pagoDeudaRepository: _FakePagoDeudaRepository(),
      );

      final actualizada = await editarDeuda(
        deudaId: 'd1',
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'jherson23',
        moneda: Moneda.pen,
        montoTotal: 1000,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
      );

      expect(actualizada.amigoUsuarioId, isNull);
    },
  );
}
