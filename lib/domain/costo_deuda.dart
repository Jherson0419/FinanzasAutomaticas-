import 'dart:math' as math;

import 'entities/deuda.dart';

/// Costo de una deuda (Fase 82, insumo del plan de pago de la Fase 83).
/// Dart puro, sin Flutter.

/// Períodos por año según la periodicidad de las cuotas. Quincenal = cada
/// 15 días (así lo arma `generarCronogramaCuotas`), es decir 365 / 15.
double periodosPorAnio(PeriodicidadCuota periodicidad) =>
    switch (periodicidad) {
      PeriodicidadCuota.mensual => 12,
      PeriodicidadCuota.quincenal => 365 / 15,
    };

/// Valor presente de [n] cuotas vencidas de [cuota] a la tasa periódica
/// [i] (anualidad ordinaria). Con `i == 0`, `cuota × n`.
double valorPresenteCuotas({
  required double cuota,
  required int n,
  required double i,
}) {
  if (i == 0) return cuota * n;
  return cuota * (1 - math.pow(1 + i, -n)) / i;
}

/// Tasa periódica `i` tal que el valor presente de las cuotas iguala el
/// capital recibido. Bisección: el valor presente decrece en `i`, así que
/// la raíz es única. `null` si no hay solución razonable (cuotas que no
/// alcanzan a cubrir el capital).
double? tasaPeriodicaDeCuotas({
  required double capital,
  required double cuota,
  required int n,
}) {
  if (capital <= 0 || cuota <= 0 || n <= 0) return null;
  if (cuota * n <= capital + 0.005) return 0; // sin interés
  var bajo = 0.0;
  var alto = 1.0; // 100 % por período: más que cualquier caso real
  if (valorPresenteCuotas(cuota: cuota, n: n, i: alto) > capital) return null;
  for (var k = 0; k < 200; k++) {
    final medio = (bajo + alto) / 2;
    if (valorPresenteCuotas(cuota: cuota, n: n, i: medio) > capital) {
      bajo = medio;
    } else {
      alto = medio;
    }
    if (alto - bajo < 1e-12) break;
  }
  return (bajo + alto) / 2;
}

/// Tasa efectiva anual de una deuda, como FRACCIÓN (0.1268 = 12.68 %).
///
/// - **Cuotas fijas**: se resuelve la tasa del flujo — capital =
///   `montoTotal` recibido hoy, `numeroCuotasTotal` cuotas de `montoCuota`
///   al final de cada período (anualidad ordinaria: la primera cuota un
///   período después de recibir el dinero, el supuesto estándar de una
///   TCEA) — y se anualiza: `(1 + i)^(períodos por año) − 1`. Si las cuotas
///   suman lo mismo que el capital, 0.
/// - **Pago libre**: sin interés → 0; con interés → `tasaInteres / 100`.
///   DECISIÓN: el formulario pide "Tasa de interés (%)" sin decir el
///   período; se interpreta como **efectiva anual (TEA)**, que es como se
///   suele cotizar en Perú. Si algún día se pide mensual, convertir con
///   `(1 + m)^12 − 1`.
/// - **Deuda automática de tarjeta** (`cuentaId != null`): `null` — la
///   tarjeta cobra interés pero la app no guarda su TCEA (ver informe de la
///   Fase 82).
/// - **"Me deben"**: 0 (sin interés en esta fase).
/// - Sin datos suficientes: `null`.
double? tasaEfectivaAnual(Deuda deuda) {
  if (deuda.meDeben) return 0;
  if (deuda.cuentaId != null && deuda.tasaInteres == null) return null;

  if (deuda.estructuraPago == EstructuraPago.cuotasFijas) {
    // Fase 84: tras un abono a capital `numeroCuotasTotal` baja y la tasa
    // ya no se puede despejar de (capital, cuota, n). Por eso el primer
    // abono CONGELA la TEA en `tasaInteres` (en %), y desde ahí manda esa.
    if (deuda.montoAbonadoCapital > 0 && deuda.tasaInteres != null) {
      return deuda.tasaInteres! / 100;
    }
    final cuota = deuda.montoCuota;
    final n = deuda.numeroCuotasTotal;
    final periodicidad = deuda.periodicidadCuotas;
    if (cuota == null || n == null || periodicidad == null) return null;
    final i = tasaPeriodicaDeCuotas(
      capital: deuda.montoTotal,
      cuota: cuota,
      n: n,
    );
    if (i == null) return null;
    if (i == 0) return 0;
    return math.pow(1 + i, periodosPorAnio(periodicidad)).toDouble() - 1;
  }

  if (!deuda.tieneInteres) return 0;
  final tasa = deuda.tasaInteres;
  if (tasa == null || tasa < 0) return null;
  return tasa / 100;
}
