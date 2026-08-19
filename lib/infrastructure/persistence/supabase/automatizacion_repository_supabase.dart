import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/repositories/automatizacion_repository.dart';
import 'supabase_errores.dart';

/// Adapter de `AutomatizacionRepository` sobre la columna `token_webhook`
/// de la tabla `usuarios` (Fase 25). El token se genera del lado del
/// cliente (mismo `package:uuid` que usa el resto de la app para ids) y se
/// guarda con un `UPDATE` protegido por RLS — solo el propio usuario puede
/// leer o cambiar su fila en `usuarios` (`auth.uid() = id`).
class AutomatizacionRepositorySupabase implements AutomatizacionRepository {
  final SupabaseClient _client;
  final Uuid _uuid;

  AutomatizacionRepositorySupabase(this._client, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<String> obtenerTokenWebhook() {
    return conManejoDeErroresSupabase('usuarios.obtenerTokenWebhook', () async {
      final fila = await _client
          .from('usuarios')
          .select('token_webhook')
          .eq('id', _userId)
          .single();
      return fila['token_webhook'] as String;
    });
  }

  @override
  Future<String> regenerarTokenWebhook() {
    return conManejoDeErroresSupabase(
      'usuarios.regenerarTokenWebhook',
      () async {
        final nuevoToken = _uuid.v4();
        await _client
            .from('usuarios')
            .update({'token_webhook': nuevoToken})
            .eq('id', _userId);
        return nuevoToken;
      },
    );
  }
}
