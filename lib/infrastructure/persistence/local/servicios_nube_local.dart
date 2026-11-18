import 'package:uuid/uuid.dart';

import '../../../domain/entities/mensaje_consejo.dart';
import '../../../domain/entities/mensaje_push.dart';
import '../../../domain/repositories/automatizacion_repository.dart';
import '../../../domain/repositories/chat_consejos_repository.dart';
import '../../../domain/repositories/push_notification_repository.dart';
import '../../../domain/repositories/token_dispositivo_repository.dart';
import '../../../domain/usecases/dto/resumen_para_consejos.dart';
import 'modo_local.dart';

// Adaptadores del modo local (Fase 78) para los puertos que en producción
// son servicios de nube puros (Edge Functions, Firebase). Ninguno guarda
// datos financieros, así que van juntos en un solo archivo.

/// Webhook por usuario (Fase 25): la URL apunta a una Edge Function, no hay
/// equivalente local. No se puede ser "no-op" en un método que devuelve el
/// token (inventar uno mostraría una URL falsa), así que ambos lanzan; la
/// pantalla de Automatización queda deshabilitada en modo local.
class AutomatizacionRepositoryLocal implements AutomatizacionRepository {
  const AutomatizacionRepositoryLocal();

  @override
  Future<String> obtenerTokenWebhook() async =>
      throw noDisponibleEnModoLocal('Automatización');

  @override
  Future<String> regenerarTokenWebhook() async =>
      throw noDisponibleEnModoLocal('Automatización');
}

/// Token de push por dispositivo: no-op (no hay backend que lo guarde).
class TokenDispositivoRepositoryLocal implements TokenDispositivoRepository {
  const TokenDispositivoRepositoryLocal();

  @override
  Future<void> guardarToken({
    required String token,
    required String plataforma,
  }) async {}

  @override
  Future<void> eliminarToken(String token) async {}
}

/// Push sin Firebase: sin permiso, sin token, streams vacíos.
class PushNotificationRepositoryLocal implements PushNotificationRepository {
  const PushNotificationRepositoryLocal();

  @override
  Future<bool> solicitarPermiso() async => false;

  @override
  Future<String?> obtenerToken() async => null;

  @override
  String get plataforma => 'local';

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<MensajePush> get onMensajePrimerPlano => const Stream.empty();

  @override
  Stream<MensajePush> get onMensajeAbierto => const Stream.empty();

  @override
  Future<MensajePush?> mensajeInicial() async => null;
}

/// Chat de consejos (Fase 30): Gemini corre en la Edge Function
/// `generar-consejos`. En modo local cada mensaje recibe la misma respuesta
/// fija. El historial vive en memoria (dura lo que dura la app abierta) para
/// que la pantalla se comporte como un chat normal.
class ChatConsejosRepositoryLocal implements ChatConsejosRepository {
  static const respuestaFija =
      'Los consejos con IA requieren la nube. En modo local puedes seguir '
      'registrando y revisando tus movimientos y deudas; cuando vuelvas a '
      'la nube podré analizarlos y darte recomendaciones.';

  final List<MensajeConsejo> _historial = [];
  final Uuid _uuid;

  ChatConsejosRepositoryLocal({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  @override
  Future<List<MensajeConsejo>> obtenerHistorial() async =>
      List.unmodifiable(_historial);

  @override
  Future<void> enviarMensaje({
    required String mensaje,
    bool esPrimerMensaje = false,
    ResumenParaConsejos? resumen,
  }) async {
    final ahora = DateTime.now();
    if (!esPrimerMensaje && mensaje.trim().isNotEmpty) {
      _historial.add(
        MensajeConsejo(
          id: _uuid.v4(),
          rol: RolMensajeConsejo.usuario,
          contenido: mensaje,
          fecha: ahora,
        ),
      );
    }
    _historial.add(
      MensajeConsejo(
        id: _uuid.v4(),
        rol: RolMensajeConsejo.asistente,
        contenido: respuestaFija,
        fecha: ahora,
      ),
    );
  }
}
