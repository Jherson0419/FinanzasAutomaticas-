import 'dart:math' as math;

import 'costo_deuda.dart';
import 'entities/deuda.dart';

/// Abonos a capital en deudas de cuotas fijas (Fase 84). Dart puro.
///
/// Principio: el banco manda. Todo lo que se calcula aquí es una
/// ESTIMACIÓN que el usuario puede corregir con lo que diga su banco
/// (`cuotasRestantesSegunBanco` en `RegistrarPagoDeuda`).
///
/// Supuesto del cálculo: el banco aplica el abono a capital y MANTIENE la
/// cuota, reduciendo el número de cuotas (lo más común en Perú cuando el
/// cliente no pide otra cosa). Fase 84b: lo que no alcanza para liberar
/// una cuota entera baja la ÚLTIMA cuota (`Deuda.montoUltimaCuota`).

/// Margen para no contar una cuota extra por error de redondeo binario
/// (p. ej. `nper = 5.0000000001` debe ser 5, no 6).
const _margenNper = 1e-6;

/// Por debajo de esto no hay última cuota parcial (Fase 84b); a menos de
/// esto de la cuota, la última se considera completa.
const toleranciaUltimaCuota = 0.01;

/// Tasa por período de una deuda en cuotas fijas, o `null` si no se puede
/// saber. Con abonos, la tasa congelada al primer abono (ver
/// [tasaEfectivaAnual]); sin abonos, la que resulta de sus cuotas.
double? tasaPeriodicaCuotasFijas(Deuda deuda) {
  final periodicidad = deuda.periodicidadCuotas;
  if (periodicidad == null) return null;
  final tea = tasaEfectivaAnual(deuda);
  if (tea == null) return null;
  if (tea <= 0) return 0;
  return math.pow(1 + tea, 1 / periodosPorAnio(periodicidad)).toDouble() - 1;
}

/// Cuotas que faltan pagar de una deuda en cuotas fijas.
int cuotasRestantes(Deuda deuda) => math.max(
  (deuda.numeroCuotasTotal ?? 0) - (deuda.numeroCuotasPagadas ?? 0),
  0,
);

/// Capital que falta devolver: valor presente de las cuotas restantes a la
/// tasa [i] (0 % → `cuota × restantes`). Fase 84b: si la última cuota es
/// [ultima] (menor), cuenta `restantes − 1` cuotas completas más ésa.
double capitalPendienteCuotas({
  required double cuota,
  required int restantes,
  required double i,
  double? ultima,
}) {
  if (restantes <= 0) return 0;
  if (ultima == null) {
    return valorPresenteCuotas(cuota: cuota, n: restantes, i: i);
  }
  final completas = restantes - 1;
  final pvCompletas = completas <= 0
      ? 0.0
      : valorPresenteCuotas(cuota: cuota, n: completas, i: i);
  return pvCompletas + ultima / math.pow(1 + i, restantes);
}

/// Cuotas que quedan para devolver un capital, período a período
/// (Fase 84b).
class CuotasRestantesSimuladas {
  /// Cuotas completas.
  final int completas;

  /// Monto de la última cuota, menor que la cuota; `null` si no hay cuota
  /// parcial (el capital se cubre con cuotas completas).
  final double? ultima;

  const CuotasRestantesSimuladas({required this.completas, this.ultima});

  /// Total de cuotas que quedan (las completas más la parcial, si hay).
  int get total => completas + (ultima == null ? 0 : 1);
}

/// Simula la amortización de [capital]: mientras `saldo × (1 + i) >
/// cuota`, se paga una cuota completa (`saldo = saldo × (1 + i) − cuota`);
/// la última cuota es `F = saldo × (1 + i)`. `F < 0.01` → no hay parcial;
/// `F` a menos de 0.01 de la cuota → es una cuota completa más. Con
/// `i == 0` equivale a `F = C − cuota × floor(C / cuota)`.
///
/// `null` si la cuota no cubre el interés (no termina) o si harían falta
/// más de [maxCuotas] cuotas completas.
CuotasRestantesSimuladas? simularCuotasRestantes({
  required double capital,
  required double cuota,
  required double i,
  required int maxCuotas,
}) {
  if (capital <= 0.005) return const CuotasRestantesSimuladas(completas: 0);
  if (cuota <= 0 || capital * i >= cuota) return null;
  var saldo = capital;
  var completas = 0;
  while (saldo * (1 + i) > cuota) {
    saldo = saldo * (1 + i) - cuota;
    completas++;
    if (completas > maxCuotas) return null;
  }
  final ultima = saldo * (1 + i);
  if (ultima < toleranciaUltimaCuota) {
    return CuotasRestantesSimuladas(completas: completas);
  }
  if (ultima > cuota - toleranciaUltimaCuota) {
    return CuotasRestantesSimuladas(completas: completas + 1);
  }
  return CuotasRestantesSimuladas(completas: completas, ultima: ultima);
}

/// Menor número de cuotas de [cuota] cuyo valor presente a la tasa [i]
/// cubre [capital]. Con `i == 0`, `ceil(capital / cuota)`. Capital ≤ 0 → 0.
/// `null` si la cuota no cubre ni el interés del período (nunca termina).
int? cuotasParaCubrir({
  required double capital,
  required double cuota,
  required double i,
}) {
  if (capital <= 0.005) return 0;
  if (cuota <= 0) return null;
  if (i <= 0) return (capital / cuota - _margenNper).ceil();
  final x = 1 - capital * i / cuota;
  if (x <= 0) return null;
  final nper = -math.log(x) / math.log(1 + i);
  return (nper - _margenNper).ceil();
}

/// Resultado de estimar un abono a capital.
class EstimacionAbono {
  /// Cuotas que faltaban antes del abono.
  final int cuotasRestantesAntes;

  /// Cuotas que faltarían después (estimación).
  final int cuotasRestantesDespues;

  /// Capital pendiente antes del abono (valor presente de las restantes).
  final double capitalAntes;

  /// Tasa por período usada (0 si la deuda no tiene tasa conocida).
  final double tasaPeriodica;

  /// `true` si la deuda no tiene tasa conocida y se calculó al 0 %.
  final bool sinTasa;

  /// Cuota normal de la deuda.
  final double cuota;

  /// Fase 84b — última cuota antes del abono (la parcial que ya tenía, o
  /// la cuota normal).
  final double ultimaCuotaAntes;

  /// Fase 84b — última cuota tras el abono; `null` = la cuota normal.
  final double? ultimaCuotaDespues;

  const EstimacionAbono({
    required this.cuotasRestantesAntes,
    required this.cuotasRestantesDespues,
    required this.capitalAntes,
    required this.tasaPeriodica,
    required this.sinTasa,
    required this.cuota,
    required this.ultimaCuotaAntes,
    this.ultimaCuotaDespues,
  });

  /// El abono cubre todo el capital: la deuda queda saldada.
  bool get salda => cuotasRestantesDespues == 0;

  /// Última cuota que quedaría (la normal si no hay parcial), o `null` si
  /// el abono salda la deuda.
  double? get ultimaCuotaResultante =>
      salda ? null : (ultimaCuotaDespues ?? cuota);
}

/// Estima cuántas cuotas quedan tras abonar [abono] a capital en [deuda]
/// (cuotas fijas) y de cuánto sería la última. `null` si a la deuda le
/// faltan datos de cuotas.
///
/// Fase 84b: `C' = capitalPendiente − abono` (valor presente de las
/// cuotas pendientes, contando la última parcial, a la tasa congelada) y
/// se simula período a período ([simularCuotasRestantes]): cuotas
/// completas más una última `F` menor. Sin tasa conocida se usa 0 %.
EstimacionAbono? estimarAbonoCapital(Deuda deuda, double abono) {
  final cuota = deuda.montoCuota;
  if (deuda.estructuraPago != EstructuraPago.cuotasFijas ||
      cuota == null ||
      cuota <= 0 ||
      deuda.numeroCuotasTotal == null) {
    return null;
  }
  final tasa = tasaPeriodicaCuotasFijas(deuda);
  final i = tasa ?? 0;
  final antes = cuotasRestantes(deuda);
  final ultimaAntes = antes > 0 ? deuda.montoUltimaCuota : null;
  final capital = capitalPendienteCuotas(
    cuota: cuota,
    restantes: antes,
    i: i,
    ultima: ultimaAntes,
  );
  final simulada = simularCuotasRestantes(
    capital: capital - abono,
    cuota: cuota,
    i: i,
    maxCuotas: antes,
  );
  // Un abono nunca agrega cuotas: si la simulación no termina o daría más
  // cuotas (datos incoherentes), queda como estaba.
  final valida = simulada != null && simulada.total <= antes;
  return EstimacionAbono(
    cuotasRestantesAntes: antes,
    cuotasRestantesDespues: valida ? simulada.total : antes,
    capitalAntes: capital,
    tasaPeriodica: i,
    sinTasa: tasa == null,
    cuota: cuota,
    ultimaCuotaAntes: ultimaAntes ?? cuota,
    ultimaCuotaDespues: valida ? simulada.ultima : ultimaAntes,
  );
}

/// Monto de la cuota número [numero] (1-based) de [deuda]: la última usa
/// `montoUltimaCuota` si la tiene (Fase 84b); el resto, la cuota.
double? montoDeCuota(Deuda deuda, int numero) {
  final ultima = deuda.montoUltimaCuota;
  if (ultima != null && numero == deuda.numeroCuotasTotal) return ultima;
  return deuda.montoCuota;
}

/// Suma de las próximas [cantidad] cuotas pendientes de [deuda] (adelanto
/// de cuotas), contando la última parcial si entra.
double montoAdelantoCuotas(Deuda deuda, int cantidad) {
  final pagadas = deuda.numeroCuotasPagadas ?? 0;
  var total = 0.0;
  for (var k = 1; k <= cantidad; k++) {
    total += montoDeCuota(deuda, pagadas + k) ?? 0;
  }
  return total;
}
