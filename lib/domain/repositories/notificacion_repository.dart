import '../entities/notificacion.dart';

abstract class NotificacionRepository {
  Future<List<Notificacion>> obtenerTodas();

  Future<void> marcarLeida(String id);
}
