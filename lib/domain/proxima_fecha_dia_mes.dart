/// Próxima ocurrencia de [diaDelMes] (1-31) a partir de [desde] (inclusive):
/// si [diaDelMes] ya pasó este mes, cae en el mes siguiente. Mismo enfoque
/// de aritmética de fechas que `cronograma_cuotas.dart` — respeta fin de
/// mes (ej. día 31 en febrero cae el 28/29, no se desborda a marzo).
///
/// Función pura de dominio, reutilizada por `ObtenerAlertasTarjetasCredito`
/// (Fase 29) para calcular la próxima fecha de corte/pago de una tarjeta de
/// crédito a partir de `Cuenta.diaCorte`/`Cuenta.diaPago`.
DateTime proximaFecha(int diaDelMes, DateTime desde) {
  final hoy = DateTime(desde.year, desde.month, desde.day);
  var candidato = _fechaEnMes(hoy.year, hoy.month, diaDelMes);
  if (candidato.isBefore(hoy)) {
    final siguienteMes = hoy.month == 12 ? 1 : hoy.month + 1;
    final siguienteAnio = hoy.month == 12 ? hoy.year + 1 : hoy.year;
    candidato = _fechaEnMes(siguienteAnio, siguienteMes, diaDelMes);
  }
  return candidato;
}

/// Igual que `_sumarMeses` de `cronograma_cuotas.dart`: si [dia] no existe
/// en [mes] (ej. 31 de febrero), se recorta al último día real de ese mes.
DateTime _fechaEnMes(int anio, int mes, int dia) {
  final ultimoDiaDelMes = DateTime(anio, mes + 1, 0).day;
  final diaRecortado = dia > ultimoDiaDelMes ? ultimoDiaDelMes : dia;
  return DateTime(anio, mes, diaRecortado);
}
