import 'dart:math' as math;

import 'abono_capital.dart';
import 'costo_deuda.dart';
import 'entities/cuenta.dart';
import 'entities/deuda.dart';
import 'saldo_deuda.dart';

/// Plan de pago (Fase 83). SOLO cálculo: no registra pagos ni modifica
/// deudas. Todo resultado es una ESTIMACIÓN (supone pagos a tiempo y que
/// las tasas ingresadas son correctas). Dart puro, sin Flutter.

/// Estrategias de pago.
/// - [avalancha]: primero la de mayor tasa efectiva anual (ahorra más).
/// - [bolaDeNieve]: primero la de menor capital pendiente (victorias
///   rápidas).
/// - [base]: "sin plan": solo los mínimos, sin extra y sin reasignar las
///   cuotas que se liberan. Sirve de comparación.
enum EstrategiaPago { avalancha, bolaDeNieve, base }

/// Tope de la simulación: 50 años.
const mesesMaximosSimulacion = 600;

/// Si la diferencia de interés entre avalancha y bola de nieve es menor que
/// esto (en la moneda del plan) o que [umbralRelativoCasiIgual] del interés
/// de la avalancha, se considera "casi igual".
const umbralAbsolutoCasiIgual = 30.0;
const umbralRelativoCasiIgual = 0.05;

const _epsilon = 0.005;

/// Tasa mensual equivalente a una efectiva anual: `(1 + TEA)^(1/12) − 1`.
double tasaMensualDesdeAnual(double tea) => math.pow(1 + tea, 1 / 12) - 1;

/// Tasa por período de cuota (misma convención que `costo_deuda.dart`):
/// mensual `(1 + TEA)^(1/12) − 1`; quincenal `(1 + TEA)^(15/365) − 1`.
double tasaPorPeriodo(double tea, PeriodicidadCuota periodicidad) =>
    math.pow(1 + tea, 1 / periodosPorAnio(periodicidad)) - 1;

/// Capital que falta devolver hoy.
/// - Cuotas fijas con tasa > 0: valor presente de las cuotas RESTANTES a la
///   tasa por período (lo que costaría saldarla hoy, sin los intereses
///   futuros que todavía no corren).
/// - Cuotas fijas sin tasa o al 0 %, y pago libre: `saldoPendiente`.
double capitalPendiente(Deuda deuda) {
  final saldo = saldoPendiente(deuda);
  if (deuda.estructuraPago != EstructuraPago.cuotasFijas) return saldo;
  final tea = tasaEfectivaAnual(deuda);
  final cuota = deuda.montoCuota;
  final total = deuda.numeroCuotasTotal;
  final periodicidad = deuda.periodicidadCuotas;
  if (tea == null ||
      tea <= 0 ||
      cuota == null ||
      total == null ||
      periodicidad == null) {
    return saldo;
  }
  final restantes = total - (deuda.numeroCuotasPagadas ?? 0);
  if (restantes <= 0) return 0;
  // Fase 84b: contando la última cuota parcial que dejó un abono.
  return capitalPendienteCuotas(
    cuota: cuota,
    restantes: restantes,
    i: tasaPorPeriodo(tea, periodicidad),
    ultima: deuda.montoUltimaCuota,
  );
}

/// Pago mínimo MENSUAL de una deuda.
/// - Cuotas fijas mensuales: la cuota.
/// - Cuotas fijas quincenales: `cuota × (365/15) / 12`, el equivalente
///   mensual de pagar cada 15 días (≈ 2.03 cuotas por mes).
/// - Pago libre: `pagoMinimo`, o 0 si no tiene.
double pagoMinimoMensual(Deuda deuda) {
  if (deuda.estructuraPago == EstructuraPago.cuotasFijas) {
    final cuota = deuda.montoCuota ?? 0;
    return deuda.periodicidadCuotas == PeriodicidadCuota.quincenal
        ? cuota * periodosPorAnio(PeriodicidadCuota.quincenal) / 12
        : cuota;
  }
  return deuda.pagoMinimo ?? 0;
}

/// Deudas que entran al plan: SOLO lo que debo (`direccion == debo`),
/// activas o en mora, con saldo pendiente. Nunca "me deben".
List<Deuda> deudasParaPlan(Iterable<Deuda> deudas) => [
  for (final d in deudas)
    if (d.direccion == DireccionDeuda.debo &&
        (d.estado == EstadoDeuda.activa || d.estado == EstadoDeuda.enMora) &&
        saldoPendiente(d) > _epsilon)
      d,
];

/// Resultado de una deuda dentro de un plan.
class ResultadoDeudaPlan {
  final Deuda deuda;

  /// Posición en el orden de ataque (1 = "Paga primero").
  final int orden;
  final double capitalInicial;

  /// Tasa efectiva anual usada; `null` = falta la tasa (se simuló al 0 %).
  final double? tasa;
  final double pagoMinimoMensual;

  /// Mes (1 = el mes que viene) en que queda saldada; `null` si no se
  /// paga a este ritmo.
  final int? mesLibre;
  final double interesPagado;
  final double totalPagado;

  const ResultadoDeudaPlan({
    required this.deuda,
    required this.orden,
    required this.capitalInicial,
    required this.tasa,
    required this.pagoMinimoMensual,
    required this.mesLibre,
    required this.interesPagado,
    required this.totalPagado,
  });

  bool get faltaTasa => tasa == null;
  bool get seSalda => mesLibre != null;
}

/// Resultado de una estrategia en UNA moneda.
class ResultadoPlan {
  final EstrategiaPago estrategia;
  final Moneda moneda;
  final double extraMensual;

  /// En el orden de ataque.
  final List<ResultadoDeudaPlan> deudas;

  const ResultadoPlan({
    required this.estrategia,
    required this.moneda,
    required this.extraMensual,
    required this.deudas,
  });

  /// `true` si todas las deudas se saldan dentro del tope.
  bool get seCompleta => deudas.every((d) => d.seSalda);

  /// Meses hasta quedar libre de deudas; `null` si no se completa.
  int? get meses => seCompleta
      ? deudas.fold<int>(0, (m, d) => math.max(m, d.mesLibre!))
      : null;

  /// Fase 84b — suma de los pagos mínimos mensuales de las deudas del
  /// plan (el supuesto: se paga todo esto cada mes, más [extraMensual]).
  double get minimosMensuales =>
      deudas.fold(0, (s, d) => s + d.pagoMinimoMensual);

  double get capitalTotal => deudas.fold(0, (s, d) => s + d.capitalInicial);
  double get interesTotal => deudas.fold(0, (s, d) => s + d.interesPagado);
  double get totalPagado => deudas.fold(0, (s, d) => s + d.totalPagado);
  bool get hayDeudasSinTasa => deudas.any((d) => d.faltaTasa);
}

/// Fecha del mes [mes] contando desde [inicio] (mes 1 = el siguiente).
DateTime fechaDelMes(DateTime inicio, int mes) =>
    DateTime(inicio.year, inicio.month + mes);

class _Estado {
  _Estado(this.deuda, this.capital, this.tasa, this.minimo)
    : saldo = capital,
      tasaMensual = tasaMensualDesdeAnual(tasa ?? 0);

  final Deuda deuda;
  final double capital;
  final double? tasa;
  final double minimo;
  final double tasaMensual;
  double saldo;
  double interes = 0;
  double pagado = 0;
  int? mesLibre;

  bool get activa => mesLibre == null;
}

/// Simula [estrategia] mes a mes para deudas de UNA misma moneda.
///
/// Cada mes, en este orden:
/// 1. Se suma el interés del mes al saldo de cada deuda viva.
/// 2. Se paga el mínimo de cada una (nunca más que su saldo).
/// 3. Salvo en [EstrategiaPago.base], el "pozo" = [extraMensual] + los
///    mínimos de las deudas YA saldadas (bola de nieve: la cuota liberada
///    sigue trabajando) + lo que sobró de mínimos este mes, va a la deuda
///    prioritaria; si la salda, el resto pasa a la siguiente.
/// Si en un mes ninguna deuda baja su saldo (los pagos no cubren ni el
/// interés), se detiene: las que quedan "no se pagan a este ritmo".
///
/// Fase 86: [pagoUnico] (opcional, p. ej. una gratificación) se suma al
/// pozo SOLO en su mes; también en "base" (que no tiene pozo los demás
/// meses). Sin él, el resultado es idéntico al de siempre.
ResultadoPlan simularPlan({
  required List<Deuda> deudas,
  required Moneda moneda,
  required EstrategiaPago estrategia,
  double extraMensual = 0,
  PagoUnico? pagoUnico,
}) {
  final extra = estrategia == EstrategiaPago.base
      ? 0.0
      : math.max(0.0, extraMensual);
  final estados = [
    for (final d in deudasParaPlan(deudas))
      if (d.moneda == moneda)
        _Estado(
          d,
          capitalPendiente(d),
          tasaEfectivaAnual(d),
          pagoMinimoMensual(d),
        ),
  ];

  // Orden de ataque (estable ante empates: conserva el orden de entrada).
  final indexados = [for (var i = 0; i < estados.length; i++) (i, estados[i])];
  int comparar((int, _Estado) a, (int, _Estado) b) {
    final x = a.$2, y = b.$2;
    final porCriterio = switch (estrategia) {
      EstrategiaPago.bolaDeNieve => x.capital.compareTo(y.capital),
      _ => (y.tasa ?? 0).compareTo(x.tasa ?? 0),
    };
    if (porCriterio != 0) return porCriterio;
    // Desempate: avalancha → menor capital; bola de nieve → mayor tasa.
    final desempate = estrategia == EstrategiaPago.bolaDeNieve
        ? (y.tasa ?? 0).compareTo(x.tasa ?? 0)
        : x.capital.compareTo(y.capital);
    return desempate != 0 ? desempate : a.$1.compareTo(b.$1);
  }

  indexados.sort(comparar);
  final ordenados = [for (final (_, e) in indexados) e];

  for (final e in ordenados) {
    if (e.saldo <= _epsilon) {
      e.saldo = 0;
      e.mesLibre = 0;
    }
  }

  double liberado = 0; // mínimos de deudas ya saldadas (bola de nieve)
  for (var mes = 1; mes <= mesesMaximosSimulacion; mes++) {
    final vivas = ordenados.where((e) => e.activa).toList();
    if (vivas.isEmpty) break;
    final saldoAntes = {for (final e in vivas) e: e.saldo};

    // 1) Interés del mes.
    for (final e in vivas) {
      final interes = e.saldo * e.tasaMensual;
      e.saldo += interes;
      e.interes += interes;
    }

    // 2) Mínimos.
    var sobranteMinimos = 0.0;
    for (final e in vivas) {
      final pago = math.min(e.minimo, e.saldo);
      e.saldo -= pago;
      e.pagado += pago;
      sobranteMinimos += e.minimo - pago;
    }

    // 3) Pozo para la prioritaria (no en "base", salvo el pago único).
    final unico = pagoUnico != null && pagoUnico.mes == mes
        ? pagoUnico.monto
        : 0.0;
    if (estrategia != EstrategiaPago.base || unico > 0) {
      var pozo = estrategia == EstrategiaPago.base
          ? unico
          : extra + liberado + sobranteMinimos + unico;
      for (final e in vivas) {
        if (pozo <= _epsilon) break;
        if (e.saldo <= _epsilon) continue;
        final pago = math.min(pozo, e.saldo);
        e.saldo -= pago;
        e.pagado += pago;
        pozo -= pago;
      }
    }

    // 4) Cierre del mes.
    var huboAvance = false;
    for (final e in vivas) {
      if (e.saldo <= _epsilon) {
        e.saldo = 0;
        e.mesLibre = mes;
        liberado += e.minimo;
        huboAvance = true;
      } else if (e.saldo < saldoAntes[e]! - _epsilon) {
        huboAvance = true;
      }
    }
    if (!huboAvance) break; // nadie avanza: no se paga a este ritmo
  }

  return ResultadoPlan(
    estrategia: estrategia,
    moneda: moneda,
    extraMensual: extra,
    deudas: [
      for (var i = 0; i < ordenados.length; i++)
        ResultadoDeudaPlan(
          deuda: ordenados[i].deuda,
          orden: i + 1,
          capitalInicial: ordenados[i].capital,
          tasa: ordenados[i].tasa,
          pagoMinimoMensual: ordenados[i].minimo,
          mesLibre: ordenados[i].mesLibre,
          interesPagado: ordenados[i].interes,
          totalPagado: ordenados[i].pagado,
        ),
    ],
  );
}

/// Fase 86 — un pago adicional de una sola vez (gratificación, bono) en el
/// mes [mes] de la simulación (1 = el mes que viene).
class PagoUnico {
  final int mes;
  final double monto;

  PagoUnico({required this.mes, required this.monto}) {
    if (mes < 1) throw ArgumentError('El mes del pago único empieza en 1');
    if (monto <= 0) throw ArgumentError('El pago único debe ser mayor a 0');
  }
}

/// Fase 86 — "¿Y si…?": un escenario contra el plan actual (misma moneda).
class ComparacionEscenario {
  final ResultadoPlan actual;
  final ResultadoPlan escenario;

  const ComparacionEscenario({required this.actual, required this.escenario});

  /// Meses que ganas (positivo) o pierdes (negativo); `null` si alguno no
  /// termina a ese ritmo.
  int? get mesesAntes => actual.meses == null || escenario.meses == null
      ? null
      : actual.meses! - escenario.meses!;

  /// Interés que ahorras (positivo) o pagas de más (negativo).
  double get interesAhorrado => actual.interesTotal - escenario.interesTotal;
}

/// Simula [escenario*] frente al plan actual ([extraActual] y
/// [estrategiaActual]) para las deudas de [moneda].
ComparacionEscenario simularEscenario({
  required List<Deuda> deudas,
  required Moneda moneda,
  required double extraActual,
  required EstrategiaPago estrategiaActual,
  required double extraEscenario,
  required EstrategiaPago estrategiaEscenario,
  PagoUnico? pagoUnico,
}) => ComparacionEscenario(
  actual: simularPlan(
    deudas: deudas,
    moneda: moneda,
    estrategia: estrategiaActual,
    extraMensual: extraActual,
  ),
  escenario: simularPlan(
    deudas: deudas,
    moneda: moneda,
    estrategia: estrategiaEscenario,
    extraMensual: extraEscenario,
    pagoUnico: pagoUnico,
  ),
);

/// Recomendación entre avalancha y bola de nieve.
class Recomendacion {
  final EstrategiaPago estrategia;

  /// `true` si la diferencia de interés es pequeña (ver
  /// [umbralAbsolutoCasiIgual] / [umbralRelativoCasiIgual]).
  final bool casiIgual;

  /// Interés que ahorra la avalancha frente a la bola de nieve (≥ 0 en la
  /// práctica; puede ser 0).
  final double diferenciaInteres;
  final String texto;

  const Recomendacion({
    required this.estrategia,
    required this.casiIgual,
    required this.diferenciaInteres,
    required this.texto,
  });
}

/// Los tres planes de UNA moneda y la recomendación.
class ComparacionPlanes {
  final Moneda moneda;
  final ResultadoPlan base;
  final ResultadoPlan avalancha;
  final ResultadoPlan bolaDeNieve;
  final Recomendacion recomendacion;

  const ComparacionPlanes({
    required this.moneda,
    required this.base,
    required this.avalancha,
    required this.bolaDeNieve,
    required this.recomendacion,
  });

  ResultadoPlan plan(EstrategiaPago e) => switch (e) {
    EstrategiaPago.avalancha => avalancha,
    EstrategiaPago.bolaDeNieve => bolaDeNieve,
    EstrategiaPago.base => base,
  };

  /// Interés ahorrado frente a "sin plan"; `null` si sin plan no termina.
  double? ahorroInteres(ResultadoPlan plan) =>
      base.seCompleta ? base.interesTotal - plan.interesTotal : null;

  /// Meses ganados frente a "sin plan"; `null` si alguno no termina.
  int? ahorroMeses(ResultadoPlan plan) =>
      (base.meses != null && plan.meses != null)
      ? base.meses! - plan.meses!
      : null;
}

Recomendacion recomendar(ResultadoPlan avalancha, ResultadoPlan bola) {
  if (!avalancha.seCompleta && bola.seCompleta) {
    return const Recomendacion(
      estrategia: EstrategiaPago.bolaDeNieve,
      casiIgual: false,
      diferenciaInteres: 0,
      texto: 'Con este monto solo la bola de nieve llega a saldar todo.',
    );
  }
  final diferencia = bola.interesTotal - avalancha.interesTotal;
  final casiIgual =
      diferencia.abs() < umbralAbsolutoCasiIgual ||
      diferencia.abs() < umbralRelativoCasiIgual * avalancha.interesTotal;
  if (casiIgual) {
    return Recomendacion(
      estrategia: EstrategiaPago.bolaDeNieve,
      casiIgual: true,
      diferenciaInteres: diferencia,
      texto:
          'Casi igual: elige la que te motive. La bola de nieve te da '
          'victorias más rápidas.',
    );
  }
  return Recomendacion(
    estrategia: EstrategiaPago.avalancha,
    casiIgual: false,
    diferenciaInteres: diferencia,
    texto:
        'Pagas primero la deuda con mayor interés. Es la que más dinero '
        'ahorra. Recomendada para ti.',
  );
}

/// Planes por moneda (nunca se suman PEN con USD). El [extraMensual] se
/// aplica a la moneda principal (soles si hay deudas en soles; si no, la
/// primera); las demás monedas se simulan sin extra.
Map<Moneda, ComparacionPlanes> compararPlanes(
  Iterable<Deuda> deudas, {
  required double extraMensual,
}) {
  final candidatas = deudasParaPlan(deudas);
  final monedas = {for (final d in candidatas) d.moneda}.toList()
    ..sort((a, b) => a == Moneda.pen ? -1 : (b == Moneda.pen ? 1 : 0));
  if (monedas.isEmpty) return const {};
  final principal = monedas.first;

  return {
    for (final m in monedas)
      m: () {
        final extra = m == principal ? extraMensual : 0.0;
        final avalancha = simularPlan(
          deudas: candidatas,
          moneda: m,
          estrategia: EstrategiaPago.avalancha,
          extraMensual: extra,
        );
        final bola = simularPlan(
          deudas: candidatas,
          moneda: m,
          estrategia: EstrategiaPago.bolaDeNieve,
          extraMensual: extra,
        );
        return ComparacionPlanes(
          moneda: m,
          base: simularPlan(
            deudas: candidatas,
            moneda: m,
            estrategia: EstrategiaPago.base,
          ),
          avalancha: avalancha,
          bolaDeNieve: bola,
          recomendacion: recomendar(avalancha, bola),
        );
      }(),
  };
}
