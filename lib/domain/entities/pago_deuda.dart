/// Fase 84 — qué es un pago de deuda.
/// - [cuota]: un pago normal (o una cuota de un cronograma). Todo pago
///   anterior a esta fase.
/// - [abonoCapital]: un pago extra que reduce el capital de una deuda en
///   cuotas fijas sin contar como cuota: no avanza `numeroCuotasPagadas`
///   ni ocupa un lugar en el cronograma; acorta el plazo.
enum TipoPagoDeuda { cuota, abonoCapital }

class PagoDeuda {
  final String id;
  final String deudaId;
  final String? cuentaId;
  final double montoPagado;
  final double? montoCapital;
  final double? montoInteres;
  final DateTime fechaPago;
  final int? numeroCuota;

  /// Fase 84 — `cuota` por defecto.
  final TipoPagoDeuda tipo;

  bool get esAbonoCapital => tipo == TipoPagoDeuda.abonoCapital;

  const PagoDeuda({
    required this.id,
    required this.deudaId,
    this.cuentaId,
    required this.montoPagado,
    this.montoCapital,
    this.montoInteres,
    required this.fechaPago,
    this.numeroCuota,
    this.tipo = TipoPagoDeuda.cuota,
  });
}
