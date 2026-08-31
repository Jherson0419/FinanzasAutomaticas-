import '../entities/mensaje_push.dart';

/// Puerto sobre `FirebaseMessaging` (Fase 71). El dominio nunca depende de
/// Firebase directamente — `FirebasePushNotificationRepository`
/// (`infrastructure/notificaciones_push/`) es el único adapter, mismo
/// criterio que `AuthRepository`/Supabase: permite testear el registro del
/// token y el manejo de mensajes entrantes con un fake, sin Firebase real.
abstract class PushNotificationRepository {
  /// Pide permiso de notificaciones al sistema operativo. `true` si el
  /// usuario lo concedió (o ya lo tenía concedido/provisional de antes).
  Future<bool> solicitarPermiso();

  /// Token actual del dispositivo para este proyecto de Firebase, o `null`
  /// si todavía no hay uno disponible (p. ej. sin permiso concedido).
  Future<String?> obtenerToken();

  /// `'ios'` o `'android'` — de qué plataforma es este dispositivo, para
  /// guardarlo junto al token (`tokens_dispositivo.plataforma`).
  String get plataforma;

  /// Emite un token nuevo cada vez que Firebase lo rota (reinstalación,
  /// restauración de backup, expiración) — no es predecible cuándo pasa.
  Stream<String> get onTokenRefresh;

  /// Mensajes recibidos con la app en primer plano — el sistema operativo
  /// nunca muestra su notificación nativa en este caso (Fase 71: la app
  /// muestra un `SnackBar` en su lugar).
  Stream<MensajePush> get onMensajePrimerPlano;

  /// El usuario tocó la notificación del sistema con la app en segundo
  /// plano (no cerrada del todo).
  Stream<MensajePush> get onMensajeAbierto;

  /// La notificación que abrió la app desde cerrada (cold start), o `null`
  /// si la app se abrió de cualquier otra forma.
  Future<MensajePush?> mensajeInicial();
}
