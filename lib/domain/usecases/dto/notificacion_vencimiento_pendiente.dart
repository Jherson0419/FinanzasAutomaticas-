/// Un ítem a mandarle al RPC `generar_notificaciones_vencimiento` (Fase
/// 70): la fecha de vencimiento real ya se calculó del lado de Dart
/// (`domain/urgencia_deuda.dart`, mismo criterio que ordena/colorea
/// "Deudas activas" desde la Fase 68) — el servidor solo inserta si hace
/// falta, nunca recalcula la fecha por su cuenta. Evita duplicar en SQL la
/// lógica de "próxima fecha de vencimiento" (`proximaOcurrenciaMensual`,
/// la deuda automática de tarjeta resuelta contra su `Cuenta` vinculada,
/// etc.) que ya vive en un solo lugar en Dart.
class NotificacionVencimientoPendiente {
  final String deudaId;

  /// Solo fecha (sin hora) — es parte de la clave de de-duplicación que
  /// usa el RPC junto con `deudaId`/`tipo`.
  final DateTime fecha;

  /// `'cuota_vencida'` o `'cuota_por_vencer'`.
  final String tipo;

  const NotificacionVencimientoPendiente({
    required this.deudaId,
    required this.fecha,
    required this.tipo,
  });
}
