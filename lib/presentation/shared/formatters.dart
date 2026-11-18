import 'package:intl/intl.dart';

import '../../domain/entities/cuenta.dart';

final _numeroFormatter = NumberFormat('#,##0.00');

String simboloMoneda(Moneda moneda) {
  switch (moneda) {
    case Moneda.pen:
      return 'S/';
    case Moneda.usd:
      return r'US$';
  }
}

String formatearMonto(double monto, Moneda moneda) {
  return '${simboloMoneda(moneda)} ${_numeroFormatter.format(monto)}';
}

String formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// Monto con signo explícito (Fase 81): "+S/ 3,200.00" / "−S/ 18.00".
/// Usa el signo menos tipográfico (U+2212), no el guion. El signo es parte
/// del mensaje — nunca se comunica ingreso/gasto solo con color.
String formatearMontoConSigno(
  double monto,
  Moneda moneda, {
  required bool positivo,
}) {
  return '${positivo ? '+' : '−'}${formatearMonto(monto.abs(), moneda)}';
}

// Fase 81 — nombres en español escritos a mano: la app nunca inicializa
// los datos de fecha de `intl` por locale (solo usa `NumberFormat` sin
// locale), y hacerlo exigiría tocar `main.dart`. Así funciona igual en
// pruebas, en modo local y sin red.
const _diasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];
const _mesesLargos = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _mesesCortos = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sept',
  'oct',
  'nov',
  'dic',
];

String _capitalizar(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// "Lunes 16 de noviembre" (cabecera del Inicio).
String formatearFechaLarga(DateTime fecha) =>
    '${_capitalizar(_diasSemana[fecha.weekday - 1])} ${fecha.day} de '
    '${_mesesLargos[fecha.month - 1]}';

/// "24 nov" — y "24 nov 2025" si no es del año de [ahora].
String formatearDiaMesCorto(DateTime fecha, {DateTime? ahora}) {
  final base = '${fecha.day} ${_mesesCortos[fecha.month - 1]}';
  final hoy = ahora ?? DateTime.now();
  return fecha.year == hoy.year ? base : '$base ${fecha.year}';
}

/// "Hoy" / "Ayer" / "14 nov" (por día de calendario, no por 24 h).
String formatearDiaRelativo(DateTime fecha, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final dias = DateTime(
    hoy.year,
    hoy.month,
    hoy.day,
  ).difference(DateTime(fecha.year, fecha.month, fecha.day)).inDays;
  if (dias == 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  return formatearDiaMesCorto(fecha, ahora: hoy);
}

/// "Noviembre" — y "Noviembre 2025" si no es del año de [ahora].
String formatearMes(DateTime mes, {DateTime? ahora}) {
  final hoy = ahora ?? DateTime.now();
  final nombre = _capitalizar(_mesesLargos[mes.month - 1]);
  return mes.year == hoy.year ? nombre : '$nombre ${mes.year}';
}

/// "febrero 2027" (Fase 83, plan de pago): siempre con año, en minúscula.
String formatearMesAnio(DateTime fecha) =>
    '${_mesesLargos[fecha.month - 1]} ${fecha.year}';

/// "feb 2027" (Fase 83, filas del plan).
String formatearMesAnioCorto(DateTime fecha) =>
    '${_mesesCortos[fecha.month - 1]} ${fecha.year}';

/// Solo día/mes, sin año (Fase 65) — para fechas "próximas" donde el año no
/// aporta nada (ej. "Vence el 15/03" de una tarjeta de crédito).
String formatearDiaMes(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes';
}
