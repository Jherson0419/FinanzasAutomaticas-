import '../entities/notificacion.dart';
import '../usecases/dto/notificacion_vencimiento_pendiente.dart';

abstract class NotificacionRepository {
  Future<List<Notificacion>> obtenerTodas();

  Future<void> marcarLeida(String id);

  /// Fase 70 — RPC `generar_notificaciones_vencimiento`: inserta una
  /// notificación de cuota por vencer/vencida por cada ítem de [items] que
  /// todavía no tenga una (el servidor decide qué es "ya existe", nunca el
  /// cliente). No-op si [items] está vacío — no hace falta llamar al RPC
  /// sin nada que insertar.
  Future<void> generarNotificacionesVencimiento(
    List<NotificacionVencimientoPendiente> items,
  );
}
