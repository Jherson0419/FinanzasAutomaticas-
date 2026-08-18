import 'cuenta.dart';

enum TipoTransaccion { ingreso, gasto }

enum MetodoPago { efectivo, transferencia, tarjeta, yape, plin, otro }

enum FuenteCaptura { manual, notificacionAndroid, correoIOS, ocrIOS, ajuste }

class Transaccion {
  final String id;
  final String cuentaId;
  final String categoriaId;
  final double monto;
  final Moneda moneda;
  final TipoTransaccion tipo;
  final String concepto;
  final MetodoPago metodoPago;
  final bool esRecurrente;
  final String? comprobanteUrl;
  final FuenteCaptura fuenteCaptura;
  final String? dataRaw;
  final DateTime fecha;

  const Transaccion({
    required this.id,
    required this.cuentaId,
    required this.categoriaId,
    required this.monto,
    required this.moneda,
    required this.tipo,
    required this.concepto,
    required this.metodoPago,
    required this.esRecurrente,
    this.comprobanteUrl,
    required this.fuenteCaptura,
    this.dataRaw,
    required this.fecha,
  });
}
