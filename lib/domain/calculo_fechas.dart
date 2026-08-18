/// Calcula la próxima ocurrencia del día de pago (1-31) a partir de hoy:
/// si el día ya pasó este mes, cae en el mes siguiente.
///
/// Compartido entre `RegistrarDeuda` (Fase 6, formulario de nueva deuda) y
/// `RegistrarPagoDeuda` (Fase 7, recálculo tras un pago) para no duplicar
/// el cálculo.
DateTime? calcularProximaFechaPago(int? diaPago) {
  if (diaPago == null) return null;
  final ahora = DateTime.now();
  var candidato = DateTime(ahora.year, ahora.month, diaPago);
  if (candidato.isBefore(DateTime(ahora.year, ahora.month, ahora.day))) {
    candidato = DateTime(ahora.year, ahora.month + 1, diaPago);
  }
  return candidato;
}
