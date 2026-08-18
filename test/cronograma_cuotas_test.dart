import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/cronograma_cuotas.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';

Deuda _deudaCuotasFijas({
  required PeriodicidadCuota periodicidad,
  required DateTime fechaInicio,
  int numeroCuotasTotal = 4,
  double montoCuota = 300,
}) {
  return Deuda(
    id: 'd1',
    nombreDeuda: 'Préstamo',
    tipoDeuda: TipoDeuda.prestamoPersonal,
    tipoAcreedor: TipoAcreedor.entidadFinanciera,
    nombreAcreedor: 'BCP',
    moneda: Moneda.pen,
    montoTotal: montoCuota * numeroCuotasTotal,
    montoPagado: 0,
    tieneInteres: false,
    estructuraPago: EstructuraPago.cuotasFijas,
    numeroCuotasTotal: numeroCuotasTotal,
    montoCuota: montoCuota,
    periodicidadCuotas: periodicidad,
    fechaInicio: fechaInicio,
    enMora: false,
    estado: EstadoDeuda.activa,
  );
}

void main() {
  test('devuelve lista vacía para deudas pagoLibre', () {
    final deuda = Deuda(
      id: 'd1',
      nombreDeuda: 'Tarjeta',
      tipoDeuda: TipoDeuda.tarjetaCredito,
      tipoAcreedor: TipoAcreedor.entidadFinanciera,
      nombreAcreedor: 'BBVA',
      moneda: Moneda.pen,
      montoTotal: 500,
      montoPagado: 0,
      tieneInteres: false,
      estructuraPago: EstructuraPago.pagoLibre,
      fechaInicio: DateTime(2026, 1, 1),
      enMora: false,
      estado: EstadoDeuda.activa,
    );

    expect(generarCronogramaCuotas(deuda, []), isEmpty);
  });

  test(
    'periodicidad mensual: cada cuota vence un mes calendario después, respetando fin de mes',
    () {
      final deuda = _deudaCuotasFijas(
        periodicidad: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 31),
        numeroCuotasTotal: 4,
      );

      final cronograma = generarCronogramaCuotas(deuda, []);

      expect(cronograma, hasLength(4));
      expect(cronograma[0].fechaVencimiento, DateTime(2026, 1, 31));
      // Febrero 2026 no es bisiesto: el día 31 se recorta a 28.
      expect(cronograma[1].fechaVencimiento, DateTime(2026, 2, 28));
      expect(cronograma[2].fechaVencimiento, DateTime(2026, 3, 31));
      expect(cronograma[3].fechaVencimiento, DateTime(2026, 4, 30));
    },
  );

  test('periodicidad quincenal: cada cuota vence 15 días después', () {
    final deuda = _deudaCuotasFijas(
      periodicidad: PeriodicidadCuota.quincenal,
      fechaInicio: DateTime(2026, 1, 1),
      numeroCuotasTotal: 3,
    );

    final cronograma = generarCronogramaCuotas(deuda, []);

    expect(cronograma[0].fechaVencimiento, DateTime(2026, 1, 1));
    expect(cronograma[1].fechaVencimiento, DateTime(2026, 1, 16));
    expect(cronograma[2].fechaVencimiento, DateTime(2026, 1, 31));
  });

  test('un pago con numeroCuota se empareja directamente con esa cuota', () {
    final deuda = _deudaCuotasFijas(
      periodicidad: PeriodicidadCuota.mensual,
      fechaInicio: DateTime(2026, 1, 1),
      numeroCuotasTotal: 3,
    );
    final pago = PagoDeuda(
      id: 'p1',
      deudaId: 'd1',
      cuentaId: 'cta-1',
      montoPagado: 300,
      fechaPago: DateTime(2026, 2, 5),
      numeroCuota: 2,
    );

    final cronograma = generarCronogramaCuotas(deuda, [pago]);

    expect(cronograma[0].pagada, isFalse);
    expect(cronograma[1].pagada, isTrue);
    expect(cronograma[1].pago, same(pago));
    expect(cronograma[2].pagada, isFalse);
  });

  test(
    'pagos legacy sin numeroCuota se ordenan por fecha y se asignan a las primeras cuotas sin marcar',
    () {
      final deuda = _deudaCuotasFijas(
        periodicidad: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
        numeroCuotasTotal: 4,
      );
      final pagoReciente = PagoDeuda(
        id: 'p-reciente',
        deudaId: 'd1',
        cuentaId: 'cta-1',
        montoPagado: 300,
        fechaPago: DateTime(2026, 3, 1),
      );
      final pagoAntiguo = PagoDeuda(
        id: 'p-antiguo',
        deudaId: 'd1',
        cuentaId: 'cta-1',
        montoPagado: 300,
        fechaPago: DateTime(2026, 1, 1),
      );

      // Se pasan en orden "reciente, antiguo" a propósito: la función debe
      // reordenarlos por fecha antes de asignarlos.
      final cronograma = generarCronogramaCuotas(deuda, [
        pagoReciente,
        pagoAntiguo,
      ]);

      expect(cronograma[0].pagada, isTrue);
      expect(cronograma[0].pago, same(pagoAntiguo));
      expect(cronograma[1].pagada, isTrue);
      expect(cronograma[1].pago, same(pagoReciente));
      expect(cronograma[2].pagada, isFalse);
      expect(cronograma[3].pagada, isFalse);
    },
  );

  test(
    'proximaFechaPagoDesdeCronograma devuelve la primera cuota pendiente, o null si todas están pagadas',
    () {
      final deuda = _deudaCuotasFijas(
        periodicidad: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 1),
        numeroCuotasTotal: 2,
      );
      final sinPagos = generarCronogramaCuotas(deuda, []);
      expect(proximaFechaPagoDesdeCronograma(sinPagos), DateTime(2026, 1, 1));

      final pagos = [
        PagoDeuda(
          id: 'p1',
          deudaId: 'd1',
          cuentaId: 'cta-1',
          montoPagado: 300,
          fechaPago: DateTime(2026, 1, 1),
          numeroCuota: 1,
        ),
        PagoDeuda(
          id: 'p2',
          deudaId: 'd1',
          cuentaId: 'cta-1',
          montoPagado: 300,
          fechaPago: DateTime(2026, 2, 1),
          numeroCuota: 2,
        ),
      ];
      final todasPagadas = generarCronogramaCuotas(deuda, pagos);
      expect(proximaFechaPagoDesdeCronograma(todasPagadas), isNull);
      expect(
        fechaVencimientoFinalDesdeCronograma(todasPagadas),
        DateTime(2026, 2, 1),
      );
    },
  );
}
