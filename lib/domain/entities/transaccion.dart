import 'cuenta.dart';

/// Fase 85: una transferencia entre cuentas propias se guarda como DOS
/// movimientos ligados por `Transaccion.transferenciaId`: la salida de la
/// cuenta origen ([transferenciaSalida], resta del saldo) y la entrada a la
/// cuenta destino ([transferenciaEntrada], suma). Ninguna de las dos es
/// ingreso ni gasto: no entran en totales, categorías, "Gasto del mes" ni
/// en el resumen para consejos. Todo código que suma ingresos/gastos debe
/// hacer un `switch` exhaustivo sobre este enum.
enum TipoTransaccion { ingreso, gasto, transferenciaSalida, transferenciaEntrada }

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

  /// `null` solo en las transferencias (Fase 85): no tienen categoría.
  final String? categoriaId;
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

  /// Fase 85 — liga los dos movimientos de una transferencia; `null` en
  /// todo lo demás.
  final String? transferenciaId;

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
    this.transferenciaId,
  });

  bool get esTransferencia => tipo.esTransferencia;
}

extension TipoTransaccionX on TipoTransaccion {
  bool get esTransferencia => switch (this) {
    TipoTransaccion.ingreso || TipoTransaccion.gasto => false,
    TipoTransaccion.transferenciaSalida ||
    TipoTransaccion.transferenciaEntrada => true,
  };
}
