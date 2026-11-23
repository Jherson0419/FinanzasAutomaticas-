import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/recordatorios.dart';
import '../../domain/repositories/notificaciones_locales_repository.dart';

/// Hora de pared [pared] en la zona [zona] (Fase 87). Pública para
/// probarla sin el plugin.
tz.TZDateTime enZona(DateTime pared, tz.Location zona) => tz.TZDateTime(
  zona,
  pared.year,
  pared.month,
  pared.day,
  pared.hour,
  pared.minute,
);

/// Adaptador de `NotificacionesLocalesRepository` sobre
/// `flutter_local_notifications` (Fase 87).
///
/// Se inicializa de forma PEREZOSA en la primera llamada (zonas horarias,
/// zona local del teléfono vía `flutter_timezone` y el plugin): no hace
/// falta tocar `main.dart` ni `main_local.dart`. No pide permisos al
/// inicializar; solo [pedirPermiso] los pide.
///
/// iOS: sin un `UNUserNotificationCenter.delegate` en `AppDelegate`, un
/// recordatorio que llega con la app ABIERTA no se muestra como banner (sí
/// con la app en segundo plano o cerrada, que es el caso normal). No se
/// tocó `AppDelegate.swift` para no interferir con `firebase_messaging`.
class NotificacionesLocalesPlugin implements NotificacionesLocalesRepository {
  NotificacionesLocalesPlugin([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<tz.Location>? _inicio;

  static const _canal = AndroidNotificationDetails(
    'recordatorios',
    'Recordatorios',
    channelDescription: 'Vencimientos, cobros y tu revisión semanal',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  Future<tz.Location> _asegurar() => _inicio ??= _inicializar();

  Future<tz.Location> _inicializar() async {
    tz_data.initializeTimeZones();
    var zona = tz.UTC;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      zona = tz.getLocation(info.identifier);
    } catch (_) {
      // Sin zona reconocible: se usa el desfase actual del teléfono (UTC
      // si tampoco se puede); la hora puede correrse con cambios de
      // horario de verano.
      final desfase = DateTime.now().timeZoneOffset;
      zona = tz.Location('local', [tz.minTime], [0], [
        tz.TimeZone(desfase.inMilliseconds, isDst: false, abbreviation: 'LOC'),
      ]);
    }
    tz.setLocalLocation(zona);
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    return zona;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<EstadoPermisoNotificaciones> estadoPermiso() async {
    await _asegurar();
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() == true
          ? EstadoPermisoNotificaciones.concedido
          : EstadoPermisoNotificaciones.denegado;
    }
    final ios = _ios;
    if (ios != null) {
      final opciones = await ios.checkPermissions();
      return opciones?.isEnabled == true
          ? EstadoPermisoNotificaciones.concedido
          : EstadoPermisoNotificaciones.denegado;
    }
    return EstadoPermisoNotificaciones.denegado;
  }

  @override
  Future<bool> pedirPermiso() async {
    await _asegurar();
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() == true;
    }
    final ios = _ios;
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: false,
            sound: true,
          ) ==
          true;
    }
    return false;
  }

  @override
  Future<List<int>> pendientes() async {
    await _asegurar();
    return [for (final p in await _plugin.pendingNotificationRequests()) p.id];
  }

  @override
  Future<void> programar(Recordatorio r) async {
    final zona = await _asegurar();
    await _plugin.zonedSchedule(
      r.id,
      r.titulo,
      r.cuerpo,
      enZona(r.fecha, zona),
      const NotificationDetails(
        android: _canal,
        iOS: DarwinNotificationDetails(),
      ),
      // Sin alarmas exactas (no exige el permiso especial de Android 12+);
      // puede llegar unos minutos tarde, suficiente para un recordatorio.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: r.clave,
    );
  }

  @override
  Future<void> cancelar(int id) async {
    await _asegurar();
    await _plugin.cancel(id);
  }

  /// Fase 89 — sin `permission_handler`:
  /// - iOS: `app-settings:` (abre los ajustes de Finzo, donde están sus
  ///   notificaciones) con `url_launcher`.
  /// - Android: canal propio `finzo/ajustes` (ver `MainActivity.kt`), que
  ///   abre `APP_NOTIFICATION_SETTINGS` de la app.
  @override
  Future<void> abrirAjustes() => abrirAjustesDelSistema();
}

/// Canal nativo de Android para abrir los ajustes de notificaciones.
const canalAjustesAndroid = MethodChannel('finzo/ajustes');

/// Abre los ajustes de notificaciones de la app en el sistema. Pública
/// para probarla con un `launchUrl`/canal falsos. Devuelve `false` si no
/// se pudo abrir.
Future<bool> abrirAjustesDelSistema({
  TargetPlatform? plataforma,
  Future<bool> Function(Uri)? abrirUrl,
  MethodChannel canal = canalAjustesAndroid,
}) async {
  switch (plataforma ?? defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return (abrirUrl ?? launchUrl)(Uri.parse('app-settings:'));
    case TargetPlatform.android:
      try {
        return await canal.invokeMethod<bool>('abrirAjustesNotificaciones') ??
            false;
      } on PlatformException {
        return false;
      } on MissingPluginException {
        return false;
      }
    default:
      return false;
  }
}
