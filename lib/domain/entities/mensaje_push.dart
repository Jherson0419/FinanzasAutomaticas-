/// Notificación push entrante (Fase 71) — versión mínima y agnóstica de
/// Firebase de un `RemoteMessage`: solo lo que la UI necesita para
/// mostrar un aviso o decidir a dónde navegar. `data` es el payload crudo
/// que vino con el mensaje (p. ej. lo que use un futuro deep-link a una
/// pantalla específica, hoy sin usar — `NotificacionesScreen` es el
/// destino único, ver `CONTEXTO.md`).
class MensajePush {
  final String? titulo;
  final String? cuerpo;
  final Map<String, dynamic> data;

  const MensajePush({this.titulo, this.cuerpo, this.data = const {}});
}
