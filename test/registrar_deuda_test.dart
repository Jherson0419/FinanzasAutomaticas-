import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_deuda.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas = {};

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);

  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values.toList();

  @override
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();
}

void main() {
  test(
    'cuotasFijas: interesTotal = monto de cuota × número de cuotas − monto total',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 4,
        montoCuota: 300,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
      );

      // 300 * 4 - 1000 = 200
      expect(deuda.interesTotal, 200);
      expect(deuda.tieneInteres, isTrue);
    },
  );

  test(
    'cuotasFijas: interesTotal <= 0 se reporta como "sin interés" (tieneInteres=false)',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Compra a cuotas sin interés',
        tipoDeuda: TipoDeuda.compraCuotas,
        tipoAcreedor: TipoAcreedor.comercio,
        nombreAcreedor: 'Falabella',
        moneda: Moneda.pen,
        montoTotal: 1200,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 4,
        montoCuota: 300,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
      );

      // 300 * 4 - 1200 = 0 → sin interés.
      expect(deuda.interesTotal, 0);
      expect(deuda.tieneInteres, isFalse);
    },
  );

  test(
    'cuotasFijas: no acepta tasaInteres/tipoTasa manuales ni diaPago (siempre null)',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 4,
        montoCuota: 300,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
      );

      expect(deuda.tasaInteres, isNull);
      expect(deuda.tipoTasa, isNull);
      expect(deuda.diaPago, isNull);
    },
  );

  test(
    'cuotasFijas: proximaFechaPago y fechaVencimientoFinal se derivan del cronograma, no de diaPago',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Préstamo personal',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 4,
        montoCuota: 300,
        periodicidadCuotas: PeriodicidadCuota.quincenal,
        fechaInicio: DateTime(2026, 1, 1),
      );

      expect(deuda.proximaFechaPago, DateTime(2026, 1, 1));
      expect(deuda.fechaVencimientoFinal, DateTime(2026, 2, 15));
    },
  );

  test(
    'pagoLibre: conserva el switch manual de tieneInteres/tasaInteres',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Tarjeta de crédito',
        tipoDeuda: TipoDeuda.tarjetaCredito,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BBVA',
        moneda: Moneda.pen,
        montoTotal: 500,
        estructuraPago: EstructuraPago.pagoLibre,
        tieneInteres: true,
        tasaInteres: 15,
        tipoTasa: TipoTasa.variable,
        fechaInicio: DateTime(2026, 1, 1),
      );

      expect(deuda.tieneInteres, isTrue);
      expect(deuda.tasaInteres, 15);
      expect(deuda.tipoTasa, TipoTasa.variable);
      expect(deuda.interesTotal, isNull);
      expect(deuda.periodicidadCuotas, isNull);
      expect(deuda.proximaFechaPago, isNull);
      expect(deuda.fechaVencimientoFinal, isNull);
    },
  );

  test(
    'Fase 64: amigoUsuarioId se guarda tal cual cuando se vincula a un amigo',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Préstamo de un amigo',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'jherson23',
        moneda: Moneda.pen,
        montoTotal: 100,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        amigoUsuarioId: 'user-amigo',
      );

      expect(deuda.amigoUsuarioId, 'user-amigo');
    },
  );

  test(
    'Fase 64: amigoUsuarioId queda null cuando no se pasa (default)',
    () async {
      final fake = _FakeDeudaRepository();
      final registrarDeuda = RegistrarDeuda(deudaRepository: fake);

      final deuda = await registrarDeuda(
        nombreDeuda: 'Préstamo de un conocido',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'Alguien',
        moneda: Moneda.pen,
        montoTotal: 100,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
      );

      expect(deuda.amigoUsuarioId, isNull);
    },
  );
}
