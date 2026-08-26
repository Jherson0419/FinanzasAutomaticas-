import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/notificacion.dart';
import '../../../domain/repositories/notificacion_repository.dart';
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
