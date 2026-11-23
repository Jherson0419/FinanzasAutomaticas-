# Propuesta: banner de recordatorios con la app abierta en iOS (Fase 89 E)

**Solo propuesta. `ios/` no se modificó.**

## El problema

En iOS, una notificación que llega con la app **en primer plano** no se
muestra salvo que un `UNUserNotificationCenterDelegate` lo pida en
`userNotificationCenter(_:willPresent:withCompletionHandler:)`. Hoy
`AppDelegate.swift` no asigna ningún delegate. Por eso un recordatorio
local (Fase 87) que vence mientras usas Finzo no aparece como banner. Con
la app en segundo plano o cerrada, que es el caso normal, sí aparece.

## Cómo conviven los dos plugins

- `FlutterAppDelegate` (la clase base de `AppDelegate`) **ya implementa**
  `UNUserNotificationCenterDelegate` y **reenvía** `willPresent` /
  `didReceive` a todos los plugins registrados que los implementen.
- `flutter_local_notifications` (README, sección iOS) pide asignar ese
  delegate en `didFinishLaunchingWithOptions`:

  ```swift
  UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
  ```

  Para el push, solo responde a sus propias notificaciones (las que él
  programó); las demás las deja pasar.
- `firebase_messaging` (Fase 71) intercepta los métodos del delegate de
  notificaciones mediante *swizzling* y **reenvía al delegate original**.
  La documentación de FlutterFire indica que puede convivir con
  `flutter_local_notifications` siempre que el delegate sea el
  `FlutterAppDelegate`.

Respuesta corta: **sí hace falta asignar el delegate**, y debe ser el
propio `AppDelegate`, no un objeto nuevo.

## El cambio exacto (no aplicado)

En `ios/Runner/AppDelegate.swift`:

```swift
import Flutter
import UIKit
import UserNotifications   // ← nuevo

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Fase 89 E: los recordatorios locales también se muestran con la app
    // abierta. FlutterAppDelegate reenvía a flutter_local_notifications y
    // a firebase_messaging.
    UNUserNotificationCenter.current().delegate = self   // ← nuevo
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
```

Y al programar cada recordatorio
(`notificaciones_locales_plugin.dart`), pedir que se presente en primer
plano:

```dart
iOS: DarwinNotificationDetails(presentAlert: true, presentBanner: true,
    presentSound: true),
```

## Riesgo para el push de la Fase 71

| Riesgo | Probabilidad | Efecto |
|---|---|---|
| El push deja de llegar a `FirebaseMessaging.onMessage` con la app abierta | Baja (firebase_messaging reenvía al delegate) | No se refrescaría la campana en primer plano |
| El push empieza a mostrarse como banner con la app abierta | Media | Cambio visible: hoy no se muestra; depende de las opciones de presentación de Firebase (la app no llama `setForegroundNotificationPresentationOptions`) |
| Tocar un push deja de abrir la pantalla correcta (`onMessageOpenedApp` / `getInitialMessage`) | Baja | Navegación desde el push |
| Doble llamada al `completionHandler` | Baja | Advertencia en consola o banner duplicado |

Es un cambio de una línea que se revierte sin migraciones.

## Cómo probarlo en un teléfono

Necesita un build firmado: TestFlight (etiqueta `v*`) o Xcode en un Mac.

1. **Recordatorio con la app abierta:** en Mi perfil › Notificaciones
   activa "Revisión semanal" con día de hoy y hora dentro de 2 minutos.
   Deja la app abierta → debe aparecer el banner.
2. **Recordatorio con la app en segundo plano:** repite con la app
   minimizada → banner normal. Tocarlo abre Finzo sin errores.
3. **Push con la app abierta:** provoca un push real (p. ej. un amigo
   registra un pago de una deuda vinculada, Fase 64). La campana debe
   actualizarse como hoy. Anota si ahora además aparece un banner.
4. **Push con la app cerrada:** tocarlo abre la pantalla esperada
   (`getInitialMessage`).
5. **Push con la app en segundo plano:** tocarlo → `onMessageOpenedApp`.
6. **Sin duplicados:** ningún aviso aparece dos veces.

Si el paso 3 o 4 falla, revertir la línea del delegate.
