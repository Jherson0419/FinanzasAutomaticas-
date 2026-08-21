import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/perfil.dart';
import '../../../domain/repositories/perfil_repository.dart';
import 'supabase_errores.dart';

/// Se lanza cuando `guardarNick` choca con la constraint `UNIQUE` de
/// `usuarios.nick` — puede pasar aunque `nickDisponible` haya dicho que sí
/// estaba libre (condición de carrera: alguien más lo tomó en el medio).
class NickNoDisponibleError extends StateError {
  NickNoDisponibleError() : super('Ese nick ya está en uso. Elige otro.');
}

/// Adapter de `PerfilRepository` sobre la tabla `usuarios` de Supabase
/// (Fase 31, ampliado en la Fase 56). `nickDisponible` no puede hacer un
/// `SELECT` directo contra `usuarios` — RLS solo deja leer la fila propia
/// (`auth.uid() = id`), así que consultar si el nick de OTRO usuario existe
/// necesita una función de Postgres `SECURITY DEFINER` (`nick_disponible`,
/// SQL en el reporte de la Fase 31) que corre con más privilegio que el
/// usuario que la invoca, pero solo devuelve un `bool` — nunca expone el
/// resto de la fila de nadie.
class PerfilRepositorySupabase implements PerfilRepository {
  final SupabaseClient _client;

  PerfilRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<Perfil> obtenerPerfil() {
    return conManejoDeErroresSupabase('usuarios.obtenerPerfil', () async {
      final fila = await _client
          .from('usuarios')
          .select(
            'nick, avatar_id, instagram, nombre_completo, celular, otra_red_social',
          )
          .eq('id', _userId)
          .single();
      return aDominio(fila);
    });
  }

  /// Público solo para poder testear el mapeo de columnas sin red real
  /// (mismo criterio que los adapters de datos financieros).
  @visibleForTesting
  Perfil aDominio(Map<String, dynamic> fila) {
    return Perfil(
      nick: fila['nick'] as String?,
      avatarId: fila['avatar_id'] as String?,
      instagram: fila['instagram'] as String?,
      nombreCompleto: fila['nombre_completo'] as String?,
      celular: fila['celular'] as String?,
      otraRedSocial: fila['otra_red_social'] as String?,
    );
  }

  @override
  Future<bool> nickDisponible(String nick) {
    return conManejoDeErroresSupabase('usuarios.nickDisponible', () async {
      final disponible = await _client.rpc(
        'nick_disponible',
        params: {'p_nick': nick},
      );
      return disponible as bool;
    });
  }

  @override
  Future<void> guardarNick(String nick) async {
    try {
      await _client.from('usuarios').update({'nick': nick}).eq('id', _userId);
    } catch (error) {
      throw traducirErrorGuardarNick(error);
    }
  }

  /// Público solo para poder testear la traducción de errores sin red real
  /// — separado de `guardarNick` porque construir un `PostgrestException`
  /// real de un conflicto de unicidad no necesita ninguna llamada de red,
  /// solo el objeto de error en sí.
  @visibleForTesting
  Object traducirErrorGuardarNick(Object error) {
    if (error is PostgrestException) {
      if (error.code == '23505') return NickNoDisponibleError();
      debugPrint('Supabase (usuarios.guardarNick): ${error.message}');
      return StateError('No se pudo guardar, intenta de nuevo.');
    }
    debugPrint('Supabase (usuarios.guardarNick): $error');
    return StateError('No se pudo guardar, intenta de nuevo.');
  }

  @override
  Future<void> guardarAvatarId(String avatarId) {
    return conManejoDeErroresSupabase('usuarios.guardarAvatarId', () async {
      await _client
          .from('usuarios')
          .update({'avatar_id': avatarId})
          .eq('id', _userId);
    });
  }

  /// Fase 56 — sube al bucket `avatares` (SQL para crearlo en el reporte de
  /// esta fase) en la carpeta `<user_id>/`, siempre con el mismo nombre de
  /// archivo (`upsert: true`) para no ir acumulando fotos viejas cada vez
  /// que el usuario cambia de avatar.
  @override
  Future<String> subirFotoAvatar(
    List<int> bytes, {
    required String extension,
  }) {
    return conManejoDeErroresSupabase('avatares.subirFotoAvatar', () async {
      final ruta = '$_userId/avatar.$extension';
      await _client.storage
          .from('avatares')
          .uploadBinary(
            ruta,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/$extension',
            ),
          );
      return _client.storage.from('avatares').getPublicUrl(ruta);
    });
  }

  @override
  Future<void> guardarInstagram(String? instagram) {
    return conManejoDeErroresSupabase('usuarios.guardarInstagram', () async {
      await _client
          .from('usuarios')
          .update({'instagram': instagram})
          .eq('id', _userId);
    });
  }

  @override
  Future<void> guardarNombreCompleto(String? nombreCompleto) {
    return conManejoDeErroresSupabase(
      'usuarios.guardarNombreCompleto',
      () async {
        await _client
            .from('usuarios')
            .update({'nombre_completo': nombreCompleto})
            .eq('id', _userId);
      },
    );
  }

  @override
  Future<void> guardarCelular(String? celular) {
    return conManejoDeErroresSupabase('usuarios.guardarCelular', () async {
      await _client
          .from('usuarios')
          .update({'celular': celular})
          .eq('id', _userId);
    });
  }

  @override
  Future<void> guardarOtraRedSocial(String? otraRedSocial) {
    return conManejoDeErroresSupabase(
      'usuarios.guardarOtraRedSocial',
      () async {
        await _client
            .from('usuarios')
            .update({'otra_red_social': otraRedSocial})
            .eq('id', _userId);
      },
    );
  }
}
