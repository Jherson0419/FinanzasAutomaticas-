import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/costo_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';

/// Fase 83 — dominio del plan de pago.

Deuda _libre(
  String id,
  double saldo, {
  double? tea,
  double? minimo,
  Moneda moneda = Moneda.pen,
  DireccionDeuda direccion = DireccionDeuda.debo,
  EstadoDeuda estado = EstadoDeuda.activa,
  double pagado = 0,
}) => Deuda(
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.otro,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: id,
  moneda: moneda,
  montoTotal: saldo,
  montoPagado: pagado,
  tieneInteres: tea != null && tea > 0,
  tasaInteres: tea == null ? null : tea * 100,
  estructuraPago: EstructuraPago.pagoLibre,
  pagoMinimo: minimo,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: estado,
  direccion: direccion,
);

Deuda _cuotas(
  String id, {
  required double capital,
  required double cuota,
  required int n,
  int pagadas = 0,
  PeriodicidadCuota periodicidad = PeriodicidadCuota.mensual,
}) => Deuda(
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: id,
  moneda: Moneda.pen,
  montoTotal: capital,
  montoPagado: cuota * pagadas,
  tieneInteres: cuota * n > capital,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: n,
  numeroCuotasPagadas: pagadas,
  montoCuota: cuota,
  periodicidadCuotas: periodicidad,
  interesTotal: cuota * n - capital,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

/// Caso verificado con un script independiente en Python
/// (`plan_independiente.py`, misma regla mes a mes escrita desde cero):
///
///   A: S/ 1,000 al 2 % mensual (TEA = 1.02^12 − 1), mínimo S/ 100
///   B: S/ 500 sin interés, mínimo S/ 50
///   C: S/ 600 sin interés, 6 cuotas de S/ 100
///   Extra: S/ 100 al mes
///
///   avalancha libre {'A': 6, 'C': 6, 'B': 7}  interés total = 64.538227
///   bola      libre {'B': 4, 'C': 5, 'A': 7}  interés total = 94.197329
///   base      libre {'C': 6, 'B': 10, 'A': 12} interés total = 127.032822
///
/// Comprobación a mano del mes 1 de la avalancha: A = 1000 × 1.02 = 1020,
/// −100 de mínimo = 920, −100 de extra = 820; B = 450; C = 500.
final _a = _libre('A', 1000, tea: math.pow(1.02, 12) - 1, minimo: 100);
final _b = _libre('B', 500, minimo: 50);
final _c = _cuotas('C', capital: 600, cuota: 100, n: 6);

Map<String, int?> _libres(ResultadoPlan p) => {
  for (final d in p.deudas) d.deuda.id: d.mesLibre,
};

void main() {
  group('caso verificado (script independiente)', () {
    final comparacion = compararPlanes([
      _a,
      _b,
      _c,
    ], extraMensual: 100)[Moneda.pen]!;

    test('avalancha: A primero; libre en 7 meses, interés 64.54', () {
      final p = comparacion.avalancha;
      expect(p.deudas.map((d) => d.deuda.id), ['A', 'B', 'C']);
      expect(_libres(p), {'A': 6, 'B': 7, 'C': 6});
      expect(p.meses, 7);
      expect(p.interesTotal, closeTo(64.538227, 1e-5));
    });

    test('bola de nieve: B primero; libre en 7 meses, interés 94.20', () {
      final p = comparacion.bolaDeNieve;
      expect(p.deudas.map((d) => d.deuda.id), ['B', 'C', 'A']);
      expect(_libres(p), {'A': 7, 'B': 4, 'C': 5});
      expect(p.interesTotal, closeTo(94.197329, 1e-5));
    });

    test('sin plan (solo mínimos): libre en 12 meses, interés 127.03', () {
      final p = comparacion.base;
      expect(_libres(p), {'A': 12, 'B': 10, 'C': 6});
      expect(p.interesTotal, closeTo(127.032822, 1e-5));
      expect(comparacion.ahorroMeses(comparacion.avalancha), 5);
      expect(
        comparacion.ahorroInteres(comparacion.avalancha),
        closeTo(127.032822 - 64.538227, 1e-5),
      );
    });

    test(
      'recomendación: la avalancha ahorra solo 29.66 (< S/ 30) → casi igual, '
      'sugiere bola de nieve',
      () {
        // 94.20 − 64.54 = 29.66 < S/ 30 → "casi igual" por el umbral
        // absoluto: sugiere bola de nieve.
        final r = comparacion.recomendacion;
        expect(r.diferenciaInteres, closeTo(29.659102, 1e-5));
        expect(r.casiIgual, isTrue);
        expect(r.estrategia, EstrategiaPago.bolaDeNieve);
        expect(r.texto, contains('Casi igual: elige la que te motive'));
      },
    );
  });

  test('recomienda avalancha cuando la diferencia es grande', () {
    final caro = _libre('caro', 5000, tea: 0.60, minimo: 200);
    final barato = _libre('barato', 800, tea: 0.05, minimo: 50);
    final c = compararPlanes([caro, barato], extraMensual: 100)[Moneda.pen]!;
    expect(c.recomendacion.estrategia, EstrategiaPago.avalancha);
    expect(c.recomendacion.casiIgual, isFalse);
    expect(
      c.recomendacion.diferenciaInteres,
      greaterThan(umbralAbsolutoCasiIgual),
    );
  });

  group('invariantes', () {
    final deudas = [
      _libre('tarjeta', 2500, tea: 0.48, minimo: 150),
      _cuotas('prestamo', capital: 3800, cuota: 440, n: 10, pagadas: 2),
      _libre('informal', 250, minimo: 30),
    ];

    for (final estrategia in EstrategiaPago.values) {
      test('$estrategia: termina, capital + interés = total pagado, sin '
          'saldos negativos', () {
        final p = simularPlan(
          deudas: deudas,
          moneda: Moneda.pen,
          estrategia: estrategia,
          extraMensual: 150,
        );
        expect(p.seCompleta, isTrue);
        expect(p.meses, lessThanOrEqualTo(mesesMaximosSimulacion));
        for (final d in p.deudas) {
          expect(
            d.capitalInicial + d.interesPagado,
            closeTo(d.totalPagado, 0.01),
          );
          expect(d.interesPagado, greaterThanOrEqualTo(0));
          expect(d.totalPagado, greaterThanOrEqualTo(0));
        }
        expect(p.capitalTotal + p.interesTotal, closeTo(p.totalPagado, 0.01));
      });
    }

    test('extra 0 = base en meses e interés (sin cuotas liberadas que '
        'reasignar cuando todas terminan juntas)', () {
      final una = [_libre('x', 1000, tea: 0.30, minimo: 100)];
      final sinExtra = simularPlan(
        deudas: una,
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.avalancha,
      );
      final base = simularPlan(
        deudas: una,
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.base,
        extraMensual: 500, // base ignora el extra
      );
      expect(sinExtra.meses, base.meses);
      expect(sinExtra.interesTotal, closeTo(base.interesTotal, 1e-9));
    });

    test('más extra ⇒ fecha igual o anterior e interés igual o menor', () {
      int? mesesPrevio;
      double? interesPrevio;
      for (final extra in [0.0, 50.0, 100.0, 200.0, 400.0, 1000.0]) {
        for (final e in [
          EstrategiaPago.avalancha,
          EstrategiaPago.bolaDeNieve,
        ]) {
          final p = simularPlan(
            deudas: deudas,
            moneda: Moneda.pen,
            estrategia: e,
            extraMensual: extra,
          );
          if (e == EstrategiaPago.avalancha) {
            if (mesesPrevio != null) {
              expect(p.meses!, lessThanOrEqualTo(mesesPrevio));
              expect(p.interesTotal, lessThanOrEqualTo(interesPrevio! + 1e-9));
            }
            mesesPrevio = p.meses;
            interesPrevio = p.interesTotal;
          }
        }
      }
    });

    test('las cuotas liberadas se reasignan (bola de nieve) aun sin extra', () {
      final corta = _cuotas('corta', capital: 300, cuota: 100, n: 3);
      final larga = _libre('larga', 2000, tea: 0.40, minimo: 100);
      final conPlan = simularPlan(
        deudas: [corta, larga],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.avalancha,
      );
      final sinPlan = simularPlan(
        deudas: [corta, larga],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.base,
      );
      int mesDe(ResultadoPlan p, String id) =>
          p.deudas.firstWhere((d) => d.deuda.id == id).mesLibre!;
      expect(mesDe(conPlan, 'corta'), mesDe(sinPlan, 'corta'));
      expect(mesDe(conPlan, 'larga'), lessThan(mesDe(sinPlan, 'larga')));
    });
  });

  group('casos borde', () {
    test('deuda sin tasa: se simula al 0 % y queda marcada', () {
      final sinTasa = _libre(
        's',
        600,
        minimo: 100,
      ).copyWith(tieneInteres: true); // tiene interés pero sin tasa
      final p = simularPlan(
        deudas: [sinTasa],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.avalancha,
      );
      expect(p.deudas.single.faltaTasa, isTrue);
      expect(p.hayDeudasSinTasa, isTrue);
      expect(p.meses, 6);
      expect(p.interesTotal, 0);
    });

    test('mínimos que no cubren el interés: "no se paga a este ritmo" sin '
        'llegar al tope', () {
      final reloj = Stopwatch()..start();
      // 1,000 al 60 % anual ≈ 3.99 % mensual = 39.9 de interés > mínimo 30.
      final p = simularPlan(
        deudas: [_libre('impagable', 1000, tea: 0.60, minimo: 30)],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.base,
      );
      expect(p.seCompleta, isFalse);
      expect(p.meses, isNull);
      expect(p.deudas.single.seSalda, isFalse);
      expect(reloj.elapsedMilliseconds, lessThan(1000));
    });

    test('con extra suficiente, esa misma deuda sí se paga', () {
      final p = simularPlan(
        deudas: [_libre('impagable', 1000, tea: 0.60, minimo: 30)],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.avalancha,
        extraMensual: 100,
      );
      expect(p.seCompleta, isTrue);
    });

    test('pago libre sin mínimo ni extra: no se paga a este ritmo', () {
      final p = simularPlan(
        deudas: [_libre('x', 300)],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.avalancha,
      );
      expect(p.seCompleta, isFalse);
    });

    test('deudas pagadas, ya saldadas o "me deben" nunca entran', () {
      final entra = deudasParaPlan([
        _libre('ok', 100, minimo: 10),
        _libre('pagada', 100, estado: EstadoDeuda.pagada),
        _libre('saldada', 100, pagado: 100),
        _libre('cobro', 380, direccion: DireccionDeuda.meDeben, minimo: 10),
        _libre('mora', 100, minimo: 10, estado: EstadoDeuda.enMora),
      ]).map((d) => d.id);
      expect(entra, ['ok', 'mora']);
      final c = compararPlanes([
        _libre('cobro', 380, direccion: DireccionDeuda.meDeben, minimo: 10),
      ], extraMensual: 100);
      expect(c, isEmpty);
    });

    test('quincenal: mínimo mensual = cuota × 365/15/12', () {
      final q = _cuotas(
        'q',
        capital: 1000,
        cuota: 100,
        n: 12,
        periodicidad: PeriodicidadCuota.quincenal,
      );
      expect(pagoMinimoMensual(q), closeTo(100 * (365 / 15) / 12, 1e-9));
      final p = simularPlan(
        deudas: [q],
        moneda: Moneda.pen,
        estrategia: EstrategiaPago.base,
      );
      expect(p.seCompleta, isTrue);
      expect(p.meses, lessThanOrEqualTo(7)); // ~12 cuotas a ~2.03 por mes
    });

    test('multimoneda: una simulación por moneda; el extra solo en soles', () {
      final c = compararPlanes([
        _libre('pen', 1000, tea: 0.30, minimo: 100),
        _libre('usd', 500, tea: 0.20, minimo: 50, moneda: Moneda.usd),
      ], extraMensual: 200);
      expect(c.keys, [Moneda.pen, Moneda.usd]);
      expect(c[Moneda.pen]!.avalancha.deudas.single.deuda.id, 'pen');
      expect(c[Moneda.usd]!.avalancha.deudas.single.deuda.id, 'usd');
      expect(c[Moneda.pen]!.avalancha.extraMensual, 200);
      expect(c[Moneda.usd]!.avalancha.extraMensual, 0);
    });
  });

  group('capitalPendiente', () {
    test('cuotas con tasa: valor presente de las cuotas restantes', () {
      final d = _cuotas('p', capital: 3800, cuota: 440, n: 10, pagadas: 8);
      final tea = tasaEfectivaAnual(d)!;
      final i = tasaPorPeriodo(tea, PeriodicidadCuota.mensual);
      // Independiente: 440/(1+i) + 440/(1+i)^2.
      final esperado = 440 / (1 + i) + 440 / math.pow(1 + i, 2);
      expect(capitalPendiente(d), closeTo(esperado, 1e-6));
      expect(capitalPendiente(d), lessThan(880)); // sin intereses futuros
    });

    test('cuotas sin interés y pago libre: saldo pendiente', () {
      expect(
        capitalPendiente(
          _cuotas('z', capital: 2520, cuota: 210, n: 12, pagadas: 3),
        ),
        1890,
      );
      expect(capitalPendiente(_libre('l', 250, pagado: 100)), 150);
    });

    test('convención de tasas: quincenal = (1+TEA)^(15/365) − 1', () {
      expect(
        tasaPorPeriodo(0.40, PeriodicidadCuota.quincenal),
        closeTo(math.pow(1.40, 15 / 365) - 1, 1e-12),
      );
      expect(
        tasaPorPeriodo(0.40, PeriodicidadCuota.mensual),
        closeTo(math.pow(1.40, 1 / 12) - 1, 1e-12),
      );
    });
  });
}
