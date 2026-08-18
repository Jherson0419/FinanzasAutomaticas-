class PagoDeuda {
  final String id;
  final String deudaId;
  final String? cuentaId;
  final double montoPagado;
  final double? montoCapital;
  final double? montoInteres;
  final DateTime fechaPago;
  final int? numeroCuota;

  const PagoDeuda({
    required this.id,
    required this.deudaId,
    this.cuentaId,
    required this.montoPagado,
    this.montoCapital,
    this.montoInteres,
    required this.fechaPago,
    this.numeroCuota,
  });
}
