import '../entities/amistad.dart';

abstract class AmistadRepository {
  /// `null` si no existe ningún usuario con ese nick.
  Future<PerfilPublico?> buscarPorNick(String nick);

  Future<void> enviarSolicitud(String paraUsuarioId);

  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas();

  /// Perfiles públicos de los amigos ya aceptados (en cualquiera de los 2
  /// sentidos: de mí hacia ellos, o de ellos hacia mí).
  Future<List<PerfilPublico>> obtenerAmigos();

  Future<void> aceptarSolicitud(String solicitudId);

  Future<void> rechazarSolicitud(String solicitudId);

  /// Notifica a un amigo que se le registró un pago en una deuda vinculada
  /// a él (Fase 64, `Deuda.amigoUsuarioId`) — vía la función `SECURITY
  /// DEFINER` `notificar_pago_a_amigo`, mismo motivo que el resto de
  /// escrituras en `notificaciones`: el cliente no tiene permiso de
  /// `INSERT` directo en esa tabla.
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  });
}
