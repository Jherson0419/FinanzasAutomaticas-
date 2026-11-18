import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';

/// Fase 86 (C) — simulador "¿Y si…?" con pago único.
///
/// Script Python independiente (Decimal; reimplementa mes a mes: interés,
/// mínimos, pozo a la prioritaria, cuota liberada). Deudas: A S/ 3,000
/// al 60 % TEA (mínimo 150) y B S/ 1,500 al 20 % TEA (mínimo 100):
///   actual (avalancha, extra 100): 17 meses, interés 1383.864024415883
///   único (mes 1, 500): 15 meses, interés 996.7181286320537
///                       ahorro 387.1458957838291, 2 meses antes
///   único (mes 4, 500): 15 meses, interés 1090.3609419064061
///                       ahorro 293.5030825094767, 2 meses antes
///   extra 300: 10 meses, interés 724.5365775608404
Deuda _deuda(String id, double capital, double tea, double minimo) => Deuda(
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'Banco',
  moneda: Moneda.pen,
  montoTotal: capital,
  montoPagado: 0,
  tieneInteres: true,
  tasaInteres: tea,
  estructuraPago: EstructuraPago.pagoLibre,
  pagoMinimo: minimo,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

void main() {
  final deudas = [_deuda('A', 3000, 60, 150), _deuda('B', 1500, 20, 100)];

  ComparacionEscenario simular({
    double extra = 100,
    PagoUnico? unico,
    EstrategiaPago estrategia = EstrategiaPago.avalancha,
  }) => simularEscenario(
    deudas: deudas,
    moneda: Moneda.pen,
    extraActual: 100,
    estrategiaActual: EstrategiaPago.avalancha,
    extraEscenario: extra,
    estrategiaEscenario: estrategia,
    pagoUnico: unico,
  );

  test('plan actual verificado', () {
    final c = simular();
    expect(c.actual.meses, 17);
    expect(c.actual.interesTotal, closeTo(1383.864024415883, 1e-6));
  });

  test('sin pago único y con lo mismo: idéntico al plan actual', () {
    final c = simular();
    expect(c.escenario.meses, c.actual.meses);
    expect(c.escenario.interesTotal, c.actual.interesTotal);
    expect(c.mesesAntes, 0);
    expect(c.interesAhorrado, 0);
    // simularPlan sin pagoUnico = el de siempre, deuda por deuda.
    final a = simularPlan(
      deudas: deudas,
      moneda: Moneda.pen,
      estrategia: EstrategiaPago.avalancha,
      extraMensual: 100,
    );
    for (var i = 0; i < a.deudas.length; i++) {
      expect(c.escenario.deudas[i].mesLibre, a.deudas[i].mesLibre);
      expect(c.escenario.deudas[i].totalPagado, a.deudas[i].totalPagado);
    }
  });

  test('pago único de 500 en el mes 1', () {
    final c = simular(unico: PagoUnico(mes: 1, monto: 500));
    expect(c.escenario.meses, 15);
    expect(c.escenario.interesTotal, closeTo(996.7181286320537, 1e-6));
    expect(c.interesAhorrado, closeTo(387.1458957838291, 1e-6));
    expect(c.mesesAntes, 2);
  });

  test('pago único de 500 en el mes 4 (ahorra menos que en el mes 1)', () {
    final c = simular(unico: PagoUnico(mes: 4, monto: 500));
    expect(c.escenario.meses, 15);
    expect(c.escenario.interesTotal, closeTo(1090.3609419064061, 1e-6));
    expect(c.interesAhorrado, closeTo(293.5030825094767, 1e-6));
    expect(
      c.interesAhorrado,
      lessThan(simular(unico: PagoUnico(mes: 1, monto: 500)).interesAhorrado),
    );
  });

  test('extra de 300', () {
    final c = simular(extra: 300);
    expect(c.escenario.meses, 10);
    expect(c.escenario.interesTotal, closeTo(724.5365775608404, 1e-6));
  });

  test('invariantes: más dinero → igual o antes y igual o menos interés', () {
    for (final estrategia in [
      EstrategiaPago.avalancha,
      EstrategiaPago.bolaDeNieve,
    ]) {
      ComparacionEscenario? previo;
      for (final extra in [0.0, 50.0, 100.0, 250.0, 600.0, 2000.0]) {
        final c = simular(extra: extra, estrategia: estrategia);
        if (previo != null) {
          expect(
            c.escenario.meses!,
            lessThanOrEqualTo(previo.escenario.meses!),
            reason: '$estrategia extra $extra',
          );
          expect(
            c.escenario.interesTotal,
            lessThanOrEqualTo(previo.escenario.interesTotal + 1e-9),
          );
        }
        previo = c;
      }
      // Un pago único mayor nunca empeora.
      double interes(double monto) => simular(
        estrategia: estrategia,
        unico: PagoUnico(mes: 2, monto: monto),
      ).escenario.interesTotal;
      expect(interes(1000), lessThanOrEqualTo(interes(200)));
    }
  });

  test('un pago único que cubre todo salda en ese mes', () {
    final c = simular(unico: PagoUnico(mes: 1, monto: 10000));
    expect(c.escenario.meses, 1);
  });

  test('pago único inválido se rechaza', () {
    expect(() => PagoUnico(mes: 0, monto: 100), throwsArgumentError);
    expect(() => PagoUnico(mes: 1, monto: 0), throwsArgumentError);
  });

  test('en "sin plan" el pago único también se aplica (solo ese mes)', () {
    final sin = simularPlan(
      deudas: deudas,
      moneda: Moneda.pen,
      estrategia: EstrategiaPago.base,
    );
    final con = simularPlan(
      deudas: deudas,
      moneda: Moneda.pen,
      estrategia: EstrategiaPago.base,
      pagoUnico: PagoUnico(mes: 1, monto: 500),
    );
    expect(con.interesTotal, lessThan(sin.interesTotal));
  });
}
