import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/enum_mapeo_supabase.dart';

/// Verifica, enum por enum y valor por valor, que la conversión hacia y
/// desde Supabase coincide EXACTO con el `CHECK` real de cada columna
/// (confirmado consultando el proyecto de Supabase enlazado — no
/// asumido). Esto es justo lo que debió existir desde la Fase 21: un test
/// que fije el string exacto, no solo "no truena" — así, si alguien
/// vuelve a escribir `Moneda.pen.name` en vez de `monedaAFila(Moneda.pen)`
/// en algún adapter nuevo, un test como este (aplicado a ese adapter) lo
/// atrapa antes de llegar a producción.
void main() {
  group('Moneda (cuentas.moneda, deudas.moneda, transacciones.moneda)', () {
    test('CHECK real: moneda = ANY (ARRAY[\'PEN\', \'USD\'])', () {
      expect(monedaAFila(Moneda.pen), 'PEN');
      expect(monedaAFila(Moneda.usd), 'USD');
      expect(monedaDeFila('PEN'), Moneda.pen);
      expect(monedaDeFila('USD'), Moneda.usd);
    });

    test(
      'rechaza un valor legacy en minúscula en vez de aceptarlo silenciosamente',
      () {
        expect(() => monedaDeFila('pen'), throwsFormatException);
      },
    );
  });

  group('TipoCuenta (cuentas.tipo)', () {
    test(
      'CHECK real: tipo = ANY (ARRAY[\'debito\',\'credito\',\'billetera\',\'efectivo\'])',
      () {
        for (final (valor, esperado) in [
          (TipoCuenta.debito, 'debito'),
          (TipoCuenta.credito, 'credito'),
          (TipoCuenta.billetera, 'billetera'),
          (TipoCuenta.efectivo, 'efectivo'),
        ]) {
          expect(tipoCuentaAFila(valor), esperado);
          expect(tipoCuentaDeFila(esperado), valor);
        }
      },
    );
  });

  group('TipoCategoria (categorias.tipo)', () {
    test('CHECK real: tipo = ANY (ARRAY[\'ingreso\', \'gasto\'])', () {
      expect(tipoCategoriaAFila(TipoCategoria.ingreso), 'ingreso');
      expect(tipoCategoriaAFila(TipoCategoria.gasto), 'gasto');
      expect(tipoCategoriaDeFila('ingreso'), TipoCategoria.ingreso);
      expect(tipoCategoriaDeFila('gasto'), TipoCategoria.gasto);
    });
  });

  group('TipoTransaccion (transacciones.tipo)', () {
    test('CHECK real: tipo = ANY (ARRAY[\'ingreso\', \'gasto\'])', () {
      expect(tipoTransaccionAFila(TipoTransaccion.ingreso), 'ingreso');
      expect(tipoTransaccionAFila(TipoTransaccion.gasto), 'gasto');
      expect(tipoTransaccionDeFila('ingreso'), TipoTransaccion.ingreso);
      expect(tipoTransaccionDeFila('gasto'), TipoTransaccion.gasto);
    });
  });

  group('MetodoPago (transacciones.metodo_pago)', () {
    test(
      'CHECK real: metodo_pago = ANY (ARRAY[\'efectivo\',\'transferencia\',\'tarjeta\',\'yape\',\'plin\',\'otro\'])',
      () {
        for (final (valor, esperado) in [
          (MetodoPago.efectivo, 'efectivo'),
          (MetodoPago.transferencia, 'transferencia'),
          (MetodoPago.tarjeta, 'tarjeta'),
          (MetodoPago.yape, 'yape'),
          (MetodoPago.plin, 'plin'),
          (MetodoPago.otro, 'otro'),
        ]) {
          expect(metodoPagoAFila(valor), esperado);
          expect(metodoPagoDeFila(esperado), valor);
        }
      },
    );
  });

  group('FuenteCaptura (transacciones.fuente_captura)', () {
    test(
      'CHECK real (más webhook_atajo, Fase 25/26 — ver nota sobre el ALTER TABLE pendiente)',
      () {
        for (final (valor, esperado) in [
          (FuenteCaptura.manual, 'manual'),
          (FuenteCaptura.notificacionAndroid, 'notificacion_android'),
          (FuenteCaptura.correoIOS, 'correo_ios'),
          (FuenteCaptura.ocrIOS, 'ocr_ios'),
          (FuenteCaptura.ajuste, 'ajuste'),
          (FuenteCaptura.webhookAtajo, 'webhook_atajo'),
        ]) {
          expect(fuenteCapturaAFila(valor), esperado);
          expect(fuenteCapturaDeFila(esperado), valor);
        }
      },
    );

    test(
      'nunca el nombre del enum de Dart en camelCase (el bug real de esta fase)',
      () {
        expect(
          fuenteCapturaAFila(FuenteCaptura.notificacionAndroid),
          isNot('notificacionAndroid'),
        );
        expect(fuenteCapturaAFila(FuenteCaptura.correoIOS), isNot('correoIOS'));
        expect(fuenteCapturaAFila(FuenteCaptura.ocrIOS), isNot('ocrIOS'));
      },
    );
  });

  group('TipoDeuda (deudas.tipo_deuda)', () {
    test(
      'CHECK real: 8 valores en snake_case (el bug real de esta fase para los de más de una palabra)',
      () {
        for (final (valor, esperado) in [
          (TipoDeuda.tarjetaCredito, 'tarjeta_credito'),
          (TipoDeuda.prestamoPersonal, 'prestamo_personal'),
          (TipoDeuda.prestamoVehicular, 'prestamo_vehicular'),
          (TipoDeuda.hipoteca, 'hipoteca'),
          (TipoDeuda.prestamoEstudiantil, 'prestamo_estudiantil'),
          (TipoDeuda.compraCuotas, 'compra_cuotas'),
          (TipoDeuda.deudaInformal, 'deuda_informal'),
          (TipoDeuda.otro, 'otro'),
        ]) {
          expect(tipoDeudaAFila(valor), esperado);
          expect(tipoDeudaDeFila(esperado), valor);
        }
      },
    );
  });

  group('TipoAcreedor (deudas.tipo_acreedor)', () {
    test(
      'CHECK real: ARRAY[\'entidad_financiera\',\'persona_natural\',\'comercio\']',
      () {
        for (final (valor, esperado) in [
          (TipoAcreedor.entidadFinanciera, 'entidad_financiera'),
          (TipoAcreedor.personaNatural, 'persona_natural'),
          (TipoAcreedor.comercio, 'comercio'),
        ]) {
          expect(tipoAcreedorAFila(valor), esperado);
          expect(tipoAcreedorDeFila(esperado), valor);
        }
      },
    );
  });

  group('TipoTasa (deudas.tipo_tasa)', () {
    test('CHECK real: ARRAY[\'fija\', \'variable\']', () {
      expect(tipoTasaAFila(TipoTasa.fija), 'fija');
      expect(tipoTasaAFila(TipoTasa.variable), 'variable');
      expect(tipoTasaDeFila('fija'), TipoTasa.fija);
      expect(tipoTasaDeFila('variable'), TipoTasa.variable);
    });
  });

  group('EstructuraPago (deudas.estructura_pago)', () {
    test(
      'CHECK real: ARRAY[\'cuotas_fijas\', \'pago_libre\'] (el bug real de esta fase)',
      () {
        expect(estructuraPagoAFila(EstructuraPago.cuotasFijas), 'cuotas_fijas');
        expect(estructuraPagoAFila(EstructuraPago.pagoLibre), 'pago_libre');
        expect(
          estructuraPagoDeFila('cuotas_fijas'),
          EstructuraPago.cuotasFijas,
        );
        expect(estructuraPagoDeFila('pago_libre'), EstructuraPago.pagoLibre);
      },
    );
  });

  group('PeriodicidadCuota (deudas.periodicidad_cuotas)', () {
    test('CHECK real: ARRAY[\'mensual\', \'quincenal\']', () {
      expect(periodicidadCuotaAFila(PeriodicidadCuota.mensual), 'mensual');
      expect(periodicidadCuotaAFila(PeriodicidadCuota.quincenal), 'quincenal');
      expect(periodicidadCuotaDeFila('mensual'), PeriodicidadCuota.mensual);
      expect(periodicidadCuotaDeFila('quincenal'), PeriodicidadCuota.quincenal);
    });
  });

  group('EstadoDeuda (deudas.estado)', () {
    test(
      'CHECK real: 5 valores; "en_mora" es el bug real de esta fase (Dart: enMora)',
      () {
        for (final (valor, esperado) in [
          (EstadoDeuda.activa, 'activa'),
          (EstadoDeuda.pagada, 'pagada'),
          (EstadoDeuda.enMora, 'en_mora'),
          (EstadoDeuda.refinanciada, 'refinanciada'),
          (EstadoDeuda.cancelada, 'cancelada'),
        ]) {
          expect(estadoDeudaAFila(valor), esperado);
          expect(estadoDeudaDeFila(esperado), valor);
        }
      },
    );

    test('nunca "enMora" (el nombre del enum de Dart tal cual)', () {
      expect(estadoDeudaAFila(EstadoDeuda.enMora), isNot('enMora'));
    });
  });
}
