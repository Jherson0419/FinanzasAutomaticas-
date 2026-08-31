import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/notificacion.dart';
import '../../../domain/repositories/notificacion_repository.dart';
import '../../../domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'supabase_errores.dart';

/// Adapter de `NotificacionRepository` sobre la tabla `notificaciones` de
/// Supabase (Fase 63). El cliente nunca inserta ahí directo — RLS solo
/// permite `SELECT`/`UPDATE` de las propias notificaciones; solo una
/// función `SECURITY DEFINER` (como `aceptar_solicitud_amistad`, ver
/// `AmistadRepositorySupabase`) puede crear una fila nueva.
class NotificacionRepositorySupabase implements NotificacionRepository {
  final SupabaseClient _client;

  NotificacionRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Notificacion>> obtenerTodas() {
    return conManejoDeErroresSupabase('notificaciones.obtenerTodas', () async {
      final filas = await _client
          .from('notificaciones')
          .select()
          .eq('usuario_id', _userId)
          .order('created_at', ascending: false);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<void> marcarLeida(String id) {
    return conManejoDeErroresSupabase('notificaciones.marcarLeida', () async {
      await _client
          .from('notificaciones')
          .update({'leida': true})
          .eq('id', id)
          .eq('usuario_id', _userId);
    });
  }

  /// Fase 70 — el RPC decide qué ya existe (por `deuda_id`+`fecha`+`tipo`
  /// dentro de `data`) y nunca duplica; el cliente solo manda la lista
  /// completa de lo que debería existir. `items` vacío no llama a la red.
  @override
  Future<void> generarNotificacionesVencimiento(
    List<NotificacionVencimientoPendiente> items,
  ) {
    if (items.isEmpty) return Future.value();
    return conManejoDeErroresSupabase(
      'notificaciones.generarNotificacionesVencimiento',
      () async {
        await _client.rpc(
          'generar_notificaciones_vencimiento',
          params: {'p_items': items.map(itemAJson).toList()},
        );
      },
    );
  }

  /// Público solo para poder testear el formato exacto sin red real —
  /// en particular, que `fecha` viaje como `yyyy-MM-dd` (lo que espera
  /// `(data->>'fecha')::date` del lado del RPC), no como un
  /// `DateTime.toIso8601String()` completo con hora.
  @visibleForTesting
  Map<String, dynamic> itemAJson(NotificacionVencimientoPendiente item) {
    final fecha = item.fecha;
    return {
      'deuda_id': item.deudaId,
      'fecha':
          '${fecha.year.toString().padLeft(4, '0')}-'
          '${fecha.month.toString().padLeft(2, '0')}-'
          '${fecha.day.toString().padLeft(2, '0')}',
      'tipo': item.tipo,
    };
  }

  /// Público solo para poder testear el mapeo de columnas sin red real.
  @visibleForTesting
  Notificacion aDominio(Map<String, dynamic> fila) {
    return Notificacion(
      id: fila['id'] as String,
      tipo: fila['tipo'] as String,
      mensaje: fila['mensaje'] as String,
      data: fila['data'] as Map<String, dynamic>?,
      leida: fila['leida'] as bool,
      createdAt: DateTime.parse(fila['created_at'] as String),
    );
  }
}
