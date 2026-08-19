import 'cuenta.dart';

enum TipoTransaccion { ingreso, gasto }

enum MetodoPago { efectivo, transferencia, tarjeta, yape, plin, otro }

/// `webhookAtajo` (Fase 25): transacciones capturadas por la Edge Function
/// `capturar-transaccion`, invocada por un Atajo de iOS (Apple Pay) o una
/// regla de reenvío de correo que llame al webhook con el token del
/// usuario — infraestructura receptora de la Etapa 3, ver `CONTEXTO.md`.
enum FuenteCaptura {
  manual,
  notificacionAndroid,
  correoIOS,
  ocrIOS,
  ajuste,
  webhookAtajo,
}

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
