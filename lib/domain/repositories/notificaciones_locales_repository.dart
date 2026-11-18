import '../recordatorios.dart';

/// Estado del permiso de notificaciones del sistema.
enum EstadoPermisoNotificaciones { concedido, denegado, sinPreguntar }

/// Puerto sobre el plugin de notificaciones locales (Fase 87). El cálculo
/// vive en `recordatorios.dart`; esto solo habla con el sistema.
abstract class NotificacionesLocalesRepository {
  Future<EstadoPermisoNotificaciones> estadoPermiso();

  /// Pide el permiso (muestra el diálogo del sistema). `true` si quedó
  /// concedido.
  Future<bool> pedirPermiso();

  /// Ids de las notificaciones programadas por la app.
  Future<List<int>> pendientes();

  /// Programa (o reemplaza, mismo id) un recordatorio en hora local.
  Future<void> programar(Recordatorio recordatorio);

  Future<void> cancelar(int id);

  /// Abre los ajustes de la app en el sistema.
  Future<void> abrirAjustes();
}
