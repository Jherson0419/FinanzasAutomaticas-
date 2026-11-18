import 'dart:math' as math;

import 'entities/cuenta.dart';
import 'entities/deuda.dart';

/// Saldo de una deuda (Fase 79) — único lugar que sabe cuánto falta pagar.
///
/// En `cuotasFijas`, `Deuda.montoTotal` es el CAPITAL: el interés se deriva
/// (`interesTotal = montoCuota × numeroCuotasTotal − montoTotal`, ver
/// `RegistrarDeuda`) y cada pago suma la cuota completa a `montoPagado`.
/// Comparar `montoPagado` contra `montoTotal` marcaba la deuda como pagada
/// antes de tiempo y subestimaba el saldo; lo que hay que pagar en total es
/// `montoCuota × numeroCuotasTotal`.
///
/// En `pagoLibre` el total sigue siendo `montoTotal`. Límite conocido: si un
/// `pagoLibre` tiene interés, ese interés se acumula en la vida real y hoy
/// no se modela (ver CONTEXTO.md).

/// Diferencia máxima que se considera "ya saldada" (redondeo de céntimos).
const toleranciaSaldoDeuda = 0.01;

/// Versión por campos, para cuando no hay una `Deuda` completa (p. ej. las
/// filas reducidas de "Te deben" en `DeudaRepositorySupabase`).
double totalAPagarDe({
  required EstructuraPago estructuraPago,
  required double montoTotal,
  double? montoCuota,
  int? numeroCuotasTotal,
  double montoAbonadoCapital = 0,
  double? montoUltimaCuota,
}) {
  if (estructuraPago == EstructuraPago.cuotasFijas &&
      montoCuota != null &&
      numeroCuotasTotal != null) {
    // Fase 84: tras un abono, `numeroCuotasTotal` ya es el nuevo (menor)
    // y lo abonado se suma aparte: `montoPagado` también lo incluye.
    // Fase 84b: si el abono dejó la última cuota menor, esa cuenta F.
    if (montoUltimaCuota != null && numeroCuotasTotal > 0) {
      return montoCuota * (numeroCuotasTotal - 1) +
          montoUltimaCuota +
          montoAbonadoCapital;
    }
    return montoCuota * numeroCuotasTotal + montoAbonadoCapital;
  }
  return montoTotal;
}

double saldoPendienteDe({
  required EstructuraPago estructuraPago,
  required double montoTotal,
  required double montoPagado,
  double? montoCuota,
  int? numeroCuotasTotal,
  double montoAbonadoCapital = 0,
  double? montoUltimaCuota,
}) {
  final total = totalAPagarDe(
    estructuraPago: estructuraPago,
    montoTotal: montoTotal,
    montoCuota: montoCuota,
    numeroCuotasTotal: numeroCuotasTotal,
    montoAbonadoCapital: montoAbonadoCapital,
    montoUltimaCuota: montoUltimaCuota,
  );
  return math.max(total - montoPagado, 0);
}

/// `cuotasFijas` → `montoCuota × numeroCuotasTotal`; si no → `montoTotal`.
double totalAPagar(Deuda deuda) => totalAPagarDe(
  estructuraPago: deuda.estructuraPago,
  montoTotal: deuda.montoTotal,
  montoCuota: deuda.montoCuota,
  numeroCuotasTotal: deuda.numeroCuotasTotal,
  montoAbonadoCapital: deuda.montoAbonadoCapital,
  montoUltimaCuota: deuda.montoUltimaCuota,
);

/// `max(totalAPagar − montoPagado, 0)`.
double saldoPendiente(Deuda deuda) =>
    math.max(totalAPagar(deuda) - deuda.montoPagado, 0);

/// Suma de [saldoPendiente] por moneda de las deudas con [direccion]
/// (Fase 82): "Total que debes" usa `debo` y "Total que te deben" usa
/// `meDeben`; nunca se mezclan. No convierte monedas.
Map<Moneda, double> saldoPendientePorMoneda(
  Iterable<Deuda> deudas,
  DireccionDeuda direccion,
) {
  final total = <Moneda, double>{};
  for (final d in deudas) {
    if (d.direccion != direccion) continue;
    final saldo = saldoPendiente(d);
    total.update(d.moneda, (v) => v + saldo, ifAbsent: () => saldo);
  }
  return total;
}

/// `true` si [montoPagado] (por defecto el de la deuda) ya cubre
/// [totalAPagar], con [toleranciaSaldoDeuda] de margen.
bool estaSaldada(Deuda deuda, {double? montoPagado}) =>
    (montoPagado ?? deuda.montoPagado) >=
    totalAPagar(deuda) - toleranciaSaldoDeuda;
