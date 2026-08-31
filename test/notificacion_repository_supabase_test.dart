import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finanzas_automaticas/domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/notificacion_repository_supabase.dart';

/// Cliente Supabase "de mentira": nunca se llama a ningún método que haga
/// red — solo existe para poder instanciar el adapter y llamar directamente
/// a su método `aDominio` (`@visibleForTesting`), función pura que no lee
/// `auth.currentUser`. Mismo criterio que `perfil_repository_supabase_test.dart`.
final _clienteFalso = SupabaseClient(
  'https://example.supabase.co',
  'clave-de-prueba',
);

void main() {
  final repo = NotificacionRepositorySupabase(_clienteFalso);

  group('aDominio', () {
    test('mapea una notificación no leída con data', () {
      final notificacion = repo.aDominio({
        'id': 'notif-1',
        'usuario_id': 'user-1',
        'tipo': 'solicitud_aceptada',
        'mensaje': 'jherson23 aceptó tu solicitud de amistad',
        'data': {'solicitud_id': 'sol-1', 'usuario_id': 'user-2'},
        'leida': false,
        'created_at': '2026-01-05T10:30:00.000Z',
      });

      expect(notificacion.id, 'notif-1');
      expect(notificacion.tipo, 'solicitud_aceptada');
      expect(notificacion.mensaje, 'jherson23 aceptó tu solicitud de amistad');
      expect(notificacion.data, {
        'solicitud_id': 'sol-1',
        'usuario_id': 'user-2',
      });
      expect(notificacion.leida, isFalse);
      expect(notificacion.createdAt, DateTime.parse('2026-01-05T10:30:00.000Z'));
    });

    test('mapea una notificación leída sin data', () {
      final notificacion = repo.aDominio({
        'id': 'notif-2',
        'usuario_id': 'user-1',
        'tipo': 'solicitud_aceptada',
        'mensaje': 'Alguien aceptó tu solicitud de amistad',
        'data': null,
        'leida': true,
        'created_at': '2026-01-06T00:00:00.000Z',
      });

      expect(notificacion.leida, isTrue);
      expect(notificacion.data, isNull);
    });
  });

  group('Fase 70 — itemAJson (generarNotificacionesVencimiento)', () {
    test('manda la fecha como yyyy-MM-dd, no como ISO 8601 completo', () {
      final json = repo.itemAJson(
        NotificacionVencimientoPendiente(
          deudaId: 'deuda-1',
          fecha: DateTime(2026, 3, 5),
          tipo: 'cuota_por_vencer',
        ),
      );

      expect(json['deuda_id'], 'deuda-1');
      expect(json['fecha'], '2026-03-05');
      expect(json['tipo'], 'cuota_por_vencer');
    });

    test('rellena con ceros mes/día de un dígito', () {
      final json = repo.itemAJson(
        NotificacionVencimientoPendiente(
          deudaId: 'deuda-1',
          fecha: DateTime(2026, 1, 9),
          tipo: 'cuota_vencida',
        ),
      );

      expect(json['fecha'], '2026-01-09');
    });
  });
}
