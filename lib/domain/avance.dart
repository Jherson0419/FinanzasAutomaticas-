import 'cronograma_cuotas.dart';
import 'entities/cuenta.dart';
import 'entities/deuda.dart';
import 'entities/pago_deuda.dart';
import 'saldo_deuda.dart';

/// "Mi avance" (Fase 87). Dart puro, solo lectura, sobre tus datos locales.
///
/// - Solo deudas que DEBES (`direccion == debo`). Las tarjetas
///   (`cuentaId != null`) quedan FUERA del porcentaje: se muestran aparte
///   como uso de la línea.
/// - Dato principal (nunca baja): lo que has pagado, con desglose capital /
///   interés solo donde el pago lo trae.
/// - El porcentaje puede BAJAR si registras una deuda nueva (sube el
///   total). Por eso los hitos de 25/50/75 % se guardan al alcanzarse y no
///   se pierden (ver `hitos.dart`).

/// Días de gracia para contar una cuota como "pagada a tiempo": pago con
/// fecha ≤ vencimiento + esta tolerancia.
const diasToleranciaATiempo = 3;

/// Moneda del avance: soles si debes algo en soles; si no, la primera.
Moneda monedaAvance(Iterable<Deuda> deudas) {
  final debo = deudas.where((d) => d.direccion == DireccionDeuda.debo);
  if (debo.any((d) => d.moneda == Moneda.pen) || debo.isEmpty) {
    return Moneda.pen;
  }
  return debo.first.moneda;
}

/// Lo que has pagado (dato principal).
class TotalPagado {
  final double total;

  /// Suma de capital e interés de los pagos que traen desglose (si trae
  /// solo uno de los dos, el otro es el resto del pago: aritmética, no
  /// estimación).
  final double capital;
  final double interes;

  /// Pagos SIN desglose: no se reparte nada, se muestran como tales.
  final double sinDesglose;

  const TotalPagado({
    required this.total,
    required this.capital,
    required this.interes,
    required this.sinDesglose,
  });
}

/// Racha de meses con todas las cuotas vencidas pagadas a tiempo.
class Racha {
  final int actual;
  final int mejor;

  const Racha({required this.actual, required this.mejor});
}

class Avance {
  final Moneda moneda;
  final TotalPagado pagado;

  /// Pagado / total de las deudas del período (incluye saldadas, excluye
  /// canceladas y tarjetas), entre 0 y 1. `null` sin deudas.
  final double? fraccion;

  /// Numerador y denominador de [fraccion].
  final double pagadoDeTotal;
  final double totalDeudas;

  /// Uso de tarjetas: usado y línea total (en [moneda]); `null` sin
  /// tarjetas con línea.
  final ({double usado, double linea})? tarjetas;

  final Racha racha;

  const Avance({
    required this.moneda,
    required this.pagado,
    required this.fraccion,
    required this.pagadoDeTotal,
    required this.totalDeudas,
    required this.tarjetas,
    required this.racha,
  });

  /// Porcentaje entero hacia abajo (nunca "100 %" con algo pendiente).
  int? get porcentaje => fraccion == null ? null : (fraccion! * 100).floor();

  bool get sinDatos => totalDeudas <= 0 && pagado.total <= 0;
}

bool _cuentaParaAvance(Deuda d, Moneda m) =>
    d.direccion == DireccionDeuda.debo && d.moneda == m && d.cuentaId == null;

/// Suma de pagos a deudas que debes en [moneda] (incluye canceladas: lo
/// pagado, pagado está).
TotalPagado totalPagado(
  Iterable<Deuda> deudas,
  Map<String, List<PagoDeuda>> pagosPorDeuda,
  Moneda moneda,
) {
  var total = 0.0, capital = 0.0, interes = 0.0, sin = 0.0;
  for (final d in deudas) {
    if (!_cuentaParaAvance(d, moneda)) continue;
    for (final p in pagosPorDeuda[d.id] ?? const <PagoDeuda>[]) {
      total += p.montoPagado;
      final c = p.montoCapital;
      final i = p.montoInteres;
      if (c == null && i == null) {
        sin += p.montoPagado;
      } else {
        capital += c ?? (p.montoPagado - i!);
        interes += i ?? (p.montoPagado - c!);
      }
    }
  }
  return TotalPagado(
    total: total,
    capital: capital,
    interes: interes,
    sinDesglose: sin,
  );
}

DateTime _mes(DateTime f) => DateTime(f.year, f.month);
DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

/// Racha mensual. Para cada mes con cuotas que vencen (cuotas fijas que
/// debes, no canceladas): el mes "cumple" si todas sus cuotas se pagaron
/// con fecha ≤ vencimiento + [diasToleranciaATiempo].
/// - Meses SIN cuotas: no suman ni rompen (se saltan).
/// - Un mes con alguna cuota cuyo plazo (vencimiento + tolerancia) aún no
///   termina queda pendiente: no se evalúa todavía.
/// - Si se rompe, la racha vuelve a 0 (sin más).
Racha calcularRacha(
  Iterable<Deuda> deudas,
  Map<String, List<PagoDeuda>> pagosPorDeuda,
  DateTime ahora, {
  Moneda? moneda,
}) {
  final hoy = _dia(ahora);
  // mes → (todas a tiempo, alguna pendiente)
  final porMes = <DateTime, ({bool cumple, bool pendiente})>{};
  for (final d in deudas) {
    if (d.direccion != DireccionDeuda.debo ||
        d.cuentaId != null ||
        d.estado == EstadoDeuda.cancelada ||
        d.estructuraPago != EstructuraPago.cuotasFijas) {
      continue;
    }
    if (moneda != null && d.moneda != moneda) continue;
    for (final c in generarCronogramaCuotas(d, pagosPorDeuda[d.id] ?? [])) {
      final limite = c.fechaVencimiento.add(
        const Duration(days: diasToleranciaATiempo),
      );
      final mes = _mes(c.fechaVencimiento);
      final previo = porMes[mes] ?? (cumple: true, pendiente: false);
      final pago = c.pago;
      final aTiempo = pago != null && !_dia(pago.fechaPago).isAfter(limite);
      if (aTiempo) {
        porMes[mes] = previo;
      } else if (hoy.isAfter(limite)) {
        // Venció el plazo sin pagar, o se pagó tarde.
        porMes[mes] = (cumple: false, pendiente: previo.pendiente);
      } else {
        // Aún dentro del plazo y sin pagar: no se evalúa todavía.
        porMes[mes] = (cumple: previo.cumple, pendiente: true);
      }
    }
  }
  final meses = porMes.keys.toList()..sort();
  var actual = 0, mejor = 0;
  for (final m in meses) {
    final r = porMes[m]!;
    if (!r.cumple) {
      actual = 0;
      continue;
    }
    if (r.pendiente) continue; // aún no se puede evaluar
    actual++;
    if (actual > mejor) mejor = actual;
  }
  return Racha(actual: actual, mejor: mejor);
}

/// Avance completo en [moneda] (por defecto [monedaAvance]).
Avance calcularAvance({
  required Iterable<Deuda> deudas,
  required Map<String, List<PagoDeuda>> pagosPorDeuda,
  required Iterable<Cuenta> cuentas,
  required DateTime ahora,
  Moneda? moneda,
}) {
  final m = moneda ?? monedaAvance(deudas);
  var pagado = 0.0, total = 0.0;
  for (final d in deudas) {
    if (!_cuentaParaAvance(d, m) || d.estado == EstadoDeuda.cancelada) {
      continue;
    }
    final t = totalAPagar(d);
    total += t;
    pagado += d.montoPagado.clamp(0, t);
  }
  var usado = 0.0, linea = 0.0;
  for (final c in cuentas) {
    if (c.tipo != TipoCuenta.credito || c.moneda != m) continue;
    final l = c.lineaCredito ?? 0;
    if (l <= 0) continue;
    linea += l;
    usado += c.saldoActual < 0 ? -c.saldoActual : 0;
  }
  return Avance(
    moneda: m,
    pagado: totalPagado(deudas, pagosPorDeuda, m),
    fraccion: total <= 0 ? null : (pagado / total).clamp(0.0, 1.0),
    pagadoDeTotal: pagado,
    totalDeudas: total,
    tarjetas: linea <= 0 ? null : (usado: usado, linea: linea),
    racha: calcularRacha(deudas, pagosPorDeuda, ahora, moneda: m),
  );
}
