import '../../../domain/entities/amistad.dart';
import '../../../domain/repositories/amistad_repository.dart';
import 'modo_local.dart';

/// `AmistadRepository` del modo local (Fase 78): sin otros usuarios no hay
/// amigos. Las lecturas devuelven vacío (para que el dashboard y "Te deben"
/// se dibujen normal) y las escrituras lanzan [UnsupportedError].
class AmistadRepositoryLocal implements AmistadRepository {
  const AmistadRepositoryLocal();

  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;

  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      const [];

  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => const [];

  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async =>
      throw noDisponibleEnModoLocal('Enviar solicitud de amistad');

  @override
  Future<void> aceptarSolicitud(String solicitudId) async =>
      throw noDisponibleEnModoLocal('Aceptar solicitud de amistad');

  @override
  Future<void> rechazarSolicitud(String solicitudId) async =>
      throw noDisponibleEnModoLocal('Rechazar solicitud de amistad');

  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async => throw noDisponibleEnModoLocal('Notificar pago a un amigo');
}
