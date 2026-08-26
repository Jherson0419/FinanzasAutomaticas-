import 'cronograma_cuotas.dart' show sumarMeses;

/// Próxima ocurrencia mensual de una fecha ancla (Fase 62): a partir de
/// [ancla] (día + mes — el año es solo el punto de partida, nunca se vuelve
/// a leer directamente), avanza de a un mes calendario exacto hasta llegar
/// a una fecha `>= desde`. Reutiliza `sumarMeses` de `cronograma_cuotas.dart`
/// (Fase 14) — misma aritmética de fin de mes (ej. un ancla el 31 de enero
/// cae el 28/29 de febrero, no se desborda a marzo).
///
/// A diferencia de `proximaFecha` (`proxima_fecha_dia_mes.dart`, que solo
/// conoce el día del mes, sin año ni mes ancla), esto conserva la fecha
/// ancla completa — necesario para que corte y pago avancen de forma
/// independiente entre sí (ej. pago el 27 de un mes, corte el 7 del mes
/// siguiente) sin importar cuál día numérico sea mayor.
DateTime proximaOcurrenciaMensual(DateTime ancla, DateTime desde) {
  final anclaSinHora = DateTime(ancla.year, ancla.month, ancla.day);
  final desdeSinHora = DateTime(desde.year, desde.month, desde.day);

  var meses = 0;
  var candidato = anclaSinHora;
  while (candidato.isBefore(desdeSinHora)) {
    meses++;
    candidato = sumarMeses(anclaSinHora, meses);
  }
  return candidato;
}
