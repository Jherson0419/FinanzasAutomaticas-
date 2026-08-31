import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/infrastructure/notificaciones_push/firebase_push_notification_repository.dart';

/// Solo prueba el mapeo puro `aDominio` — nunca se llama a
/// `FirebaseMessaging.instance` ni se inicializa Firebase de verdad.
/// `RemoteMessage`/`RemoteNotification` son clases de datos con
/// constructor `const`, no requieren ningún canal de plataforma para
/// construirse en un test.
void main() {
  group('aDominio', () {
    test('mapea título, cuerpo y data de un mensaje con notificación', () {
      const mensaje = RemoteMessage(
        notification: RemoteNotification(
          title: 'jherson23 te vinculó una deuda',
          body: 'de 500.00',
        ),
        data: {'deuda_id': 'deuda-1', 'tipo': 'deuda_vinculada'},
      );

      final resultado = FirebasePushNotificationRepository.aDominio(mensaje);

      expect(resultado.titulo, 'jherson23 te vinculó una deuda');
      expect(resultado.cuerpo, 'de 500.00');
      expect(resultado.data, {
        'deuda_id': 'deuda-1',
        'tipo': 'deuda_vinculada',
      });
    });

    test('un mensaje solo de datos (sin notification) mapea título/cuerpo nulos', () {
      const mensaje = RemoteMessage(data: {'tipo': 'cuota_vencida'});

      final resultado = FirebasePushNotificationRepository.aDominio(mensaje);

      expect(resultado.titulo, isNull);
      expect(resultado.cuerpo, isNull);
      expect(resultado.data, {'tipo': 'cuota_vencida'});
    });
  });
}
