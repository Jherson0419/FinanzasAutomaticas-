import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/entities/mensaje_push.dart';
import '../../domain/repositories/push_notification_repository.dart';

/// Adapter de `PushNotificationRepository` sobre `firebase_messaging`
/// (Fase 71). `_messaging` se resuelve perezosamente (no en el
/// constructor): así construir esta clase nunca falla, aunque
/// `Firebase.initializeApp()` no se haya llamado todavía — solo falla el
/// método puntual que de verdad necesite `FirebaseMessaging.instance`,
/// igual que el resto de los providers de esta app fallan perezosamente
/// contra `Supabase.instance` sin `Supabase.initialize()`.
class FirebasePushNotificationRepository implements PushNotificationRepository {
  FirebasePushNotificationRepository([FirebaseMessaging? messaging])
    : _messagingOverride = messaging;

  final FirebaseMessaging? _messagingOverride;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  @override
  Future<bool> solicitarPermiso() async {
    final configuracion = await _messaging.requestPermission();
    return configuracion.authorizationStatus ==
            AuthorizationStatus.authorized ||
        configuracion.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> obtenerToken() => _messaging.getToken();

  @override
  String get plataforma => Platform.isIOS ? 'ios' : 'android';

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<MensajePush> get onMensajePrimerPlano =>
      FirebaseMessaging.onMessage.map(aDominio);

  @override
  Stream<MensajePush> get onMensajeAbierto =>
      FirebaseMessaging.onMessageOpenedApp.map(aDominio);

  @override
  Future<MensajePush?> mensajeInicial() async {
    final mensaje = await _messaging.getInitialMessage();
    return mensaje == null ? null : aDominio(mensaje);
  }

  /// Público solo para poder testear el mapeo sin construir un
  /// `RemoteMessage` real de Firebase en cada test — se prueba armando uno
  /// mínimo y llamando a esta función directo.
  static MensajePush aDominio(RemoteMessage mensaje) {
    return MensajePush(
      titulo: mensaje.notification?.title,
      cuerpo: mensaje.notification?.body,
      data: mensaje.data,
    );
  }
}
