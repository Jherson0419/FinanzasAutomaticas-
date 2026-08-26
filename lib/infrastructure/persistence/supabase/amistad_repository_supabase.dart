import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/amistad.dart';
import '../../../domain/repositories/amistad_repository.dart';
import '../../../domain/validar_solicitud_amistad.dart';
import 'supabase_errores.dart';

/// Se lanza cuando `enviarSolicitud` choca con la constraint `UNIQUE
/// (de_usuario_id, para_usuario_id)` de `solicitudes_amistad` — ya le
/// habías mandado una solicitud a este mismo usuario antes.
class SolicitudYaEnviadaError extends StateError {
  SolicitudYaEnviadaError()
    : super('Ya le enviaste una solicitud a este usuario.');
}

/// Adapter de `AmistadRepository` sobre las tablas `solicitudes_amistad` y
/// `usuarios` de Supabase (Fase 63). Buscar por nick y resolver nick/avatar
/// de otros usuarios no puede hacer un `SELECT` directo contra `usuarios`
/// — RLS solo deja leer la fila propia — así que usa 2 funciones de
/// Postgres `SECURITY DEFINER` (`buscar_usuario_por_nick`,
/// `perfiles_publicos`, SQL en el reporte de esta fase) que nunca exponen
/// más que `id`/`nick`/`avatar_id`, mismo criterio que `nick_disponible`
/// (Fase 31). Aceptar una solicitud también necesita `SECURITY DEFINER`
/// porque además de actualizar `estado` crea una notificación para quien
/// la envió, y el cliente no tiene permiso de `INSERT` en `notificaciones`
/// (ver `NotificacionRepositorySupabase`) — todo eso vive en la función
/// `aceptar_solicitud_amistad`, atómica.
class AmistadRepositorySupabase implements AmistadRepository {
  final SupabaseClient _client;

  AmistadRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<PerfilPublico?> buscarPorNick(String nick) {
    return conManejoDeErroresSupabase('amistad.buscarPorNick', () async {
      final filas = await _client.rpc(
        'buscar_usuario_por_nick',
        params: {'p_nick': nick},
      );
      final lista = filas as List<dynamic>;
      if (lista.isEmpty) return null;
      return aDominioPerfilPublico(lista.first as Map<String, dynamic>);
    });
  }

  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {
    validarSolicitudAmistad(
      miUsuarioId: _userId,
      paraUsuarioId: paraUsuarioId,
    );
    try {
      await _client.from('solicitudes_amistad').insert({
        'de_usuario_id': _userId,
        'para_usuario_id': paraUsuarioId,
      });
    } catch (error) {
      throw traducirErrorEnviarSolicitud(error);
    }
  }

  /// Público solo para poder testear la traducción de errores sin red real
  /// — mismo patrón que `PerfilRepositorySupabase.traducirErrorGuardarNick`.
  @visibleForTesting
  Object traducirErrorEnviarSolicitud(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') return SolicitudYaEnviadaError();
      debugPrint('Supabase (amistad.enviarSolicitud): ${error.message}');
      return StateError('No se pudo enviar la solicitud, intenta de nuevo.');
    }
    debugPrint('Supabase (amistad.enviarSolicitud): $error');
    return StateError('No se pudo enviar la solicitud, intenta de nuevo.');
  }

  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() {
    return conManejoDeErroresSupabase(
      'amistad.obtenerSolicitudesRecibidas',
      () async {
        final filas = await _client
            .from('solicitudes_amistad')
            .select('id, de_usuario_id')
            .eq('para_usuario_id', _userId)
            .eq('estado', 'pendiente');

        final idsRemitentes = filas
            .map((f) => f['de_usuario_id'] as String)
            .toList();
        final perfiles = await _perfilesPublicosPorIds(idsRemitentes);

        return [
          for (final fila in filas)
            SolicitudRecibida(
              solicitudId: fila['id'] as String,
              deQuien:
                  perfiles[fila['de_usuario_id'] as String] ??
                  PerfilPublico(usuarioId: fila['de_usuario_id'] as String),
            ),
        ];
      },
    );
  }

  @override
  Future<List<PerfilPublico>> obtenerAmigos() {
    return conManejoDeErroresSupabase('amistad.obtenerAmigos', () async {
      final filas = await _client
          .from('solicitudes_amistad')
          .select('de_usuario_id, para_usuario_id')
          .eq('estado', 'aceptada')
          .or('de_usuario_id.eq.$_userId,para_usuario_id.eq.$_userId');

      final idsAmigos = filas
          .map((f) {
            final de = f['de_usuario_id'] as String;
            final para = f['para_usuario_id'] as String;
            return de == _userId ? para : de;
          })
          .toSet()
          .toList();

      final perfiles = await _perfilesPublicosPorIds(idsAmigos);
      return idsAmigos.map((id) => perfiles[id] ?? PerfilPublico(usuarioId: id)).toList();
    });
  }

  Future<Map<String, PerfilPublico>> _perfilesPublicosPorIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final filas = await _client.rpc(
      'perfiles_publicos',
      params: {'p_ids': ids},
    );
    final lista = filas as List<dynamic>;
    return {
      for (final fila in lista)
        (fila as Map<String, dynamic>)['id'] as String: aDominioPerfilPublico(
          fila,
        ),
    };
  }

  /// Público solo para poder testear el mapeo de columnas sin red real.
  @visibleForTesting
  PerfilPublico aDominioPerfilPublico(Map<String, dynamic> fila) {
    return PerfilPublico(
      usuarioId: fila['id'] as String,
      nick: fila['nick'] as String?,
      avatarId: fila['avatar_id'] as String?,
    );
  }

  @override
  Future<void> aceptarSolicitud(String solicitudId) {
    return conManejoDeErroresSupabase('amistad.aceptarSolicitud', () async {
      await _client.rpc(
        'aceptar_solicitud_amistad',
        params: {'p_solicitud_id': solicitudId},
      );
    });
  }

  @override
  Future<void> rechazarSolicitud(String solicitudId) {
    return conManejoDeErroresSupabase('amistad.rechazarSolicitud', () async {
      await _client
          .from('solicitudes_amistad')
          .update({'estado': 'rechazada'})
          .eq('id', solicitudId)
          .eq('para_usuario_id', _userId);
    });
  }

  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) {
    return conManejoDeErroresSupabase('amistad.notificarPago', () async {
      await _client.rpc(
        'notificar_pago_a_amigo',
        params: {
          'p_amigo_id': amigoUsuarioId,
          'p_monto': monto,
          'p_nombre_deuda': nombreDeuda,
        },
      );
    });
  }
}
