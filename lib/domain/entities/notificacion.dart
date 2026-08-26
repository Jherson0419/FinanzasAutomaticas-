/// Una notificación dentro de la app (Fase 63) — nunca la crea el cliente
/// directo (RLS de `notificaciones` bloquea el `INSERT`), solo una función
/// de Postgres `SECURITY DEFINER` o una Edge Function.
class Notificacion {
  final String id;
  final String tipo;
  final String mensaje;
  final Map<String, dynamic>? data;
  final bool leida;
  final DateTime createdAt;

  const Notificacion({
    required this.id,
    required this.tipo,
    required this.mensaje,
    this.data,
    required this.leida,
    required this.createdAt,
  });
}
