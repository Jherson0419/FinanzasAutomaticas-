import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';

import 'helpers/deuda_campos.dart';

void main() {
  group('totalAPagar / saldoPendiente (Fase 79)', () {
    test('cuotasFijas con interés: total = cuota × número de cuotas', () {
      final deuda = deudaConTodosLosCampos(
        estructuraPago: EstructuraPago.cuotasFijas,
        montoTotal: 2000, // capital
        montoCuota: 210,
        numeroCuotasTotal: 12,
        montoPagado: 630,
      );
      expect(totalAPagar(deuda), 2520);
      expect(saldoPendiente(deuda), 1890);
      expect(estaSaldada(deuda), isFalse);
    });

    test('cuotasFijas sin interés: total = capital', () {
      final deuda = deudaConTodosLosCampos(
        estructuraPago: EstructuraPago.cuotasFijas,
        montoTotal: 2520,
        montoCuota: 210,
        numeroCuotasTotal: 12,
        montoPagado: 630,
      );
      expect(totalAPagar(deuda), 2520);
      expect(saldoPendiente(deuda), 1890);
    });

    test('cuotasFijas sin cuota/número de cuotas cae a montoTotal', () {
      final deuda = deudaConTodosLosCampos(
        estructuraPago: EstructuraPago.cuotasFijas,
        montoTotal: 500,
        montoCuota: null,
        numeroCuotasTotal: null,
        montoPagado: 100,
      );
      expect(totalAPagar(deuda), 500);
      expect(saldoPendiente(deuda), 400);
    });

    test('pagoLibre: total = montoTotal (aunque tenga cuota/cuotas cargadas)', () {
      final deuda = deudaConTodosLosCampos(
        estructuraPago: EstructuraPago.pagoLibre,
        montoTotal: 250,
        montoPagado: 100,
        montoCuota: 50,
        numeroCuotasTotal: 20,
      );
      expect(totalAPagar(deuda), 250);
      expect(saldoPendiente(deuda), 150);
    });

    test('nunca negativo y con tolerancia de 0.01', () {
      final pagadaDeMas = deudaConTodosLosCampos(
        montoTotal: 100,
        montoPagado: 120,
      );
      expect(saldoPendiente(pagadaDeMas), 0);
      expect(estaSaldada(pagadaDeMas), isTrue);

      final casi = deudaConTodosLosCampos(montoTotal: 100, montoPagado: 99.995);
      expect(estaSaldada(casi), isTrue);
      final falta = deudaConTodosLosCampos(montoTotal: 100, montoPagado: 99.98);
      expect(estaSaldada(falta), isFalse);
    });

    test('versión por campos (para filas sin Deuda completa)', () {
      expect(
        saldoPendienteDe(
          estructuraPago: EstructuraPago.cuotasFijas,
          montoTotal: 3800,
          montoPagado: 3520,
          montoCuota: 440,
          numeroCuotasTotal: 10,
        ),
        880,
      );
    });
  });

  test('Deuda.copyWith cubre cada campo', () {
    final original = deudaConTodosLosCampos();
    final copia = original.copyWith(
      nombreDeuda: 'n',
      tipoDeuda: TipoDeuda.hipoteca,
      tipoAcreedor: TipoAcreedor.comercio,
      nombreAcreedor: 'Otro',
      moneda: Moneda.usd,
      montoTotal: 1,
      montoPagado: 2,
      tieneInteres: false,
      tasaInteres: 9,
      tipoTasa: TipoTasa.variable,
      estructuraPago: EstructuraPago.cuotasFijas,
      numeroCuotasTotal: 99,
      numeroCuotasPagadas: 98,
      montoCuota: 7,
      pagoMinimo: 8,
      periodicidadCuotas: PeriodicidadCuota.quincenal,
      interesTotal: 3,
      fechaInicio: DateTime(2020),
      fechaVencimientoFinal: DateTime(2030),
      diaPago: 1,
      proximaFechaPago: DateTime(2029),
      enMora: true,
      diasMora: 6,
      tasaInteresMoratorio: 4,
      estado: EstadoDeuda.refinanciada,
      notas: 'otra',
      cuentaId: 'c2',
      amigoUsuarioId: 'a2',
      direccion: DireccionDeuda.meDeben,
      montoAbonadoCapital: 55,
      montoUltimaCuota: 6,
    );
    expect(camposDeuda(copia), {
      'id': original.id,
      'nombreDeuda': 'n',
      'tipoDeuda': TipoDeuda.hipoteca,
      'tipoAcreedor': TipoAcreedor.comercio,
      'nombreAcreedor': 'Otro',
      'moneda': Moneda.usd,
      'montoTotal': 1.0,
      'montoPagado': 2.0,
      'tieneInteres': false,
      'tasaInteres': 9.0,
      'tipoTasa': TipoTasa.variable,
      'estructuraPago': EstructuraPago.cuotasFijas,
      'numeroCuotasTotal': 99,
      'numeroCuotasPagadas': 98,
      'montoCuota': 7.0,
      'pagoMinimo': 8.0,
      'periodicidadCuotas': PeriodicidadCuota.quincenal,
      'interesTotal': 3.0,
      'fechaInicio': DateTime(2020),
      'fechaVencimientoFinal': DateTime(2030),
      'diaPago': 1,
      'proximaFechaPago': DateTime(2029),
      'enMora': true,
      'diasMora': 6,
      'tasaInteresMoratorio': 4.0,
      'estado': EstadoDeuda.refinanciada,
      'notas': 'otra',
      'cuentaId': 'c2',
      'amigoUsuarioId': 'a2',
      'direccion': DireccionDeuda.meDeben,
      'montoAbonadoCapital': 55.0,
      'montoUltimaCuota': 6.0,
    });
  });
}
