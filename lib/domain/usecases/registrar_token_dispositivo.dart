import 'dart:developer';

import '../repositories/push_notification_repository.dart';
import '../repositories/token_dispositivo_repository.dart';

/// Fase 71 — se llama justo después de un login exitoso (nunca antes, para
/// no pedirle permiso de notificaciones a alguien que todavía no entiende
/// para qué es). Pide permiso; si se concede, guarda el token actual del
/// dispositivo en Supabase. No hace nada si el permiso se niega o no hay
/// token disponible todavía — no tiene sentido insistir en cada login.
///
/// Envuelto en su propio `try/catch` (`dart:developer.log`, no
/// `debugPrint`, para no importar Flutter en una clase de dominio — mismo
/// criterio que `RegistrarPagoDeuda` con `notificarPago`, Fase 64): el
/// registro del token es secundario frente al login, que ya se completó
/// cuando esto se llama, y nunca debe poder tumbarlo (p. ej. si Firebase
/// no llegó a inicializarse en esta build).
class RegistrarTokenDispositivo {
  final PushNotificationRepository pushNotificationRepository;
  final TokenDispositivoRepository tokenDispositivoRepository;

  RegistrarTokenDispositivo({
    required this.pushNotificationRepository,
    required this.tokenDispositivoRepository,
  });

  Future<void> call() async {
    try {
      final permisoConcedido = await pushNotificationRepository
          .solicitarPermiso();
      if (!permisoConcedido) return;

      final token = await pushNotificationRepository.obtenerToken();
      if (token == null) return;

      await tokenDispositivoRepository.guardarToken(
        token: token,
        plataforma: pushNotificationRepository.plataforma,
      );
    } catch (error) {
      log(
        'No se pudo registrar el token de push: $error',
        name: 'RegistrarTokenDispositivo',
      );
    }
  }
}
