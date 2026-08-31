import 'dart:developer';

import '../repositories/push_notification_repository.dart';
import '../repositories/token_dispositivo_repository.dart';

/// Fase 71 — se llama al cerrar sesión, antes de `AuthRepository.
/// cerrarSesion()` (mientras todavía hay sesión activa: la RLS de
/// `tokens_dispositivo` solo deja borrar la fila propia). Sin esto, un
/// dispositivo seguiría recibiendo pushes de una cuenta de la que ya
/// cerró sesión.
///
/// Mismo criterio de resiliencia que `RegistrarTokenDispositivo`: envuelto
/// en su propio `try/catch` (`dart:developer.log`) para que un fallo aquí
/// nunca bloquee el cierre de sesión, que es la acción principal.
class EliminarTokenDispositivoActual {
  final PushNotificationRepository pushNotificationRepository;
  final TokenDispositivoRepository tokenDispositivoRepository;

  EliminarTokenDispositivoActual({
    required this.pushNotificationRepository,
    required this.tokenDispositivoRepository,
  });

  Future<void> call() async {
    try {
      final token = await pushNotificationRepository.obtenerToken();
      if (token == null) return;
      await tokenDispositivoRepository.eliminarToken(token);
    } catch (error) {
      log(
        'No se pudo eliminar el token de push: $error',
        name: 'EliminarTokenDispositivoActual',
      );
    }
  }
}
