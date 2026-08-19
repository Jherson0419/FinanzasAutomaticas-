enum TipoAlertaTarjeta { corte, pago }

/// Alerta de que la fecha de corte o de pago de una tarjeta de crédito está
/// próxima (3 días o menos) — ver `ObtenerAlertasTarjetasCredito`.
class AlertaTarjetaCredito {
  final String cuentaId;
  final String nombreCuenta;
  final TipoAlertaTarjeta tipo;
  final DateTime fecha;
  final int diasRestantes;

  const AlertaTarjetaCredito({
    required this.cuentaId,
    required this.nombreCuenta,
    required this.tipo,
    required this.fecha,
    required this.diasRestantes,
  });
}
