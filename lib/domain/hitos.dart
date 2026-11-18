import 'avance.dart';
import 'entities/cuenta.dart';
import 'entities/deuda.dart';
import 'entities/pago_deuda.dart';
import 'entities/transaccion.dart';

/// Hitos de "Mi avance" (Fase 87). Dart puro.
///
/// Un hito alcanzado se GUARDA (id y fecha) y no se pierde ni se vuelve a
/// celebrar aunque después el porcentaje baje (p. ej. por una deuda
/// nueva). La fecha es la del evento cuando se deriva de los datos (primer
/// pago, primer abono, deuda saldada, libre de deudas); si no (25/50/75 %,
/// racha, tarjeta), la fecha en que se detectó.

/// Umbrales de avance (fracción, inclusive: 25 % exacto ya cuenta).
const umbralesHitoAvance = {
  Hito.avance25: 0.25,
  Hito.avance50: 0.50,
  Hito.avance75: 0.75,
};

/// Meses de racha para el hito.
const mesesRachaHito = 3;

/// Uso de la línea por DEBAJO del cual una tarjeta logra el hito.
const usoTarjetaHito = 0.30;

enum Hito {
  primerPago,
  avance25,
  avance50,
  avance75,
  primeraDeudaSaldada,
  primerAbono,
  racha3,
  tarjetaBajo30,
  libreDeDeudas,
}

String tituloHito(Hito h) => switch (h) {
  Hito.primerPago => 'Primer pago',
  Hito.avance25 => '25 % pagado',
  Hito.avance50 => 'Mitad del camino',
  Hito.avance75 => '75 % pagado',
  Hito.primeraDeudaSaldada => 'Primera deuda saldada',
  Hito.primerAbono => 'Primer abono a capital',
  Hito.racha3 => '3 meses a tiempo',
  Hito.tarjetaBajo30 => 'Tarjeta bajo el 30 %',
  Hito.libreDeDeudas => 'Libre de deudas',
};

String descripcionHito(Hito h) => switch (h) {
  Hito.primerPago => 'Registraste tu primer pago a una deuda.',
  Hito.avance25 => 'Ya pagaste la cuarta parte de tus deudas.',
  Hito.avance50 => 'Ya pagaste la mitad de tus deudas.',
  Hito.avance75 => 'Ya pagaste tres cuartas partes de tus deudas.',
  Hito.primeraDeudaSaldada => 'Terminaste de pagar una deuda.',
  Hito.primerAbono => 'Hiciste tu primer abono a capital.',
  Hito.racha3 =>
    'Pagaste todas tus cuotas a tiempo $mesesRachaHito meses seguidos.',
  Hito.tarjetaBajo30 =>
    'Usas menos del ${(usoTarjetaHito * 100).round()} % de la línea de una '
        'tarjeta.',
  Hito.libreDeDeudas => 'Pagaste todas tus deudas.',
};

class HitoLogrado {
  final Hito hito;
  final DateTime fecha;

  /// `true` cuando ya se mostró la celebración (nunca se repite).
  final bool celebrado;

  const HitoLogrado({
    required this.hito,
    required this.fecha,
    this.celebrado = false,
  });

  HitoLogrado comoCelebrado() =>
      HitoLogrado(hito: hito, fecha: fecha, celebrado: true);
}

/// Datos que miran los hitos.
class ContextoHitos {
  final DateTime ahora;
  final List<Deuda> deudas;
  final Map<String, List<PagoDeuda>> pagosPorDeuda;
  final List<Cuenta> cuentas;
  final List<Transaccion> transacciones;

  const ContextoHitos({
    required this.ahora,
    required this.deudas,
    required this.pagosPorDeuda,
    required this.cuentas,
    this.transacciones = const [],
  });
}

DateTime? _minimo(Iterable<DateTime> fechas) =>
    fechas.isEmpty ? null : fechas.reduce((a, b) => a.isBefore(b) ? a : b);

DateTime? _maximo(Iterable<DateTime> fechas) =>
    fechas.isEmpty ? null : fechas.reduce((a, b) => a.isAfter(b) ? a : b);

/// Hitos que se cumplen HOY con sus fechas (derivadas o [ContextoHitos.ahora]).
Map<Hito, DateTime> hitosCumplidos(ContextoHitos c) {
  final r = <Hito, DateTime>{};
  final debo = [
    for (final d in c.deudas)
      if (d.direccion == DireccionDeuda.debo) d,
  ];
  final pagos = [for (final d in debo) ...?c.pagosPorDeuda[d.id]];

  final primerPago = _minimo(pagos.map((p) => p.fechaPago));
  if (primerPago != null) r[Hito.primerPago] = primerPago;

  final primerAbono = _minimo(
    pagos.where((p) => p.esAbonoCapital).map((p) => p.fechaPago),
  );
  if (primerAbono != null) r[Hito.primerAbono] = primerAbono;

  // Deudas propias (no tarjeta), no canceladas.
  final propias = [
    for (final d in debo)
      if (d.cuentaId == null && d.estado != EstadoDeuda.cancelada) d,
  ];
  DateTime fechaSaldada(Deuda d) =>
      _maximo((c.pagosPorDeuda[d.id] ?? []).map((p) => p.fechaPago)) ?? c.ahora;
  final saldadas = propias.where((d) => d.estado == EstadoDeuda.pagada);
  final primeraSaldada = _minimo(saldadas.map(fechaSaldada));
  if (primeraSaldada != null) r[Hito.primeraDeudaSaldada] = primeraSaldada;
  if (propias.isNotEmpty &&
      propias.every((d) => d.estado == EstadoDeuda.pagada)) {
    r[Hito.libreDeDeudas] = _maximo(propias.map(fechaSaldada))!;
  }

  final avance = calcularAvance(
    deudas: c.deudas,
    pagosPorDeuda: c.pagosPorDeuda,
    cuentas: c.cuentas,
    ahora: c.ahora,
  );
  final fraccion = avance.fraccion;
  if (fraccion != null) {
    for (final MapEntry(key: hito, value: umbral)
        in umbralesHitoAvance.entries) {
      // Con tolerancia de redondeo binario: 25 % exacto cuenta.
      if (fraccion >= umbral - 1e-9) r[hito] = c.ahora;
    }
  }
  if (avance.racha.mejor >= mesesRachaHito) r[Hito.racha3] = c.ahora;

  // Tarjeta con línea, con al menos un movimiento propio (para no premiar
  // una tarjeta que nunca se usó) y uso menor al umbral.
  final conMovimientos = {for (final t in c.transacciones) t.cuentaId};
  for (final cuenta in c.cuentas) {
    if (cuenta.tipo != TipoCuenta.credito) continue;
    final linea = cuenta.lineaCredito ?? 0;
    if (linea <= 0 || !conMovimientos.contains(cuenta.id)) continue;
    final usado = cuenta.saldoActual < 0 ? -cuenta.saldoActual : 0.0;
    if (usado / linea < usoTarjetaHito) {
      r[Hito.tarjetaBajo30] = c.ahora;
      break;
    }
  }
  return r;
}

/// Hitos nuevos para guardar: los que se cumplen y aún no estaban
/// [guardados]. Nunca devuelve uno ya guardado (idempotente).
List<HitoLogrado> hitosNuevos(
  ContextoHitos c,
  Map<Hito, HitoLogrado> guardados,
) => [
  for (final MapEntry(key: hito, value: fecha) in hitosCumplidos(c).entries)
    if (!guardados.containsKey(hito)) HitoLogrado(hito: hito, fecha: fecha),
]..sort((a, b) => a.hito.index.compareTo(b.hito.index));

/// El próximo hito por celebrar (solo uno a la vez): el no celebrado más
/// antiguo; a igual fecha, en el orden del enum.
HitoLogrado? siguienteACelebrar(Map<Hito, HitoLogrado> guardados) {
  final pendientes = guardados.values.where((h) => !h.celebrado).toList()
    ..sort((a, b) {
      final f = a.fecha.compareTo(b.fecha);
      return f != 0 ? f : a.hito.index.compareTo(b.hito.index);
    });
  return pendientes.firstOrNull;
}
