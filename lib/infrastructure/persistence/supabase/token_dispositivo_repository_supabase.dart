import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/repositories/token_dispositivo_repository.dart';
import 'supabase_errores.dart';

/// Adapter de `TokenDispositivoRepository` sobre `tokens_dispositivo`
/// (Fase 71, SQL en el reporte). Siempre apunta a Supabase directo, mismo
/// criterio que `AutomatizacionRepositorySupabase`: el token de push de
/// "este dispositivo" no existe en modo local (Drift).
class TokenDispositivoRepositorySupabase implements TokenDispositivoRepository {
  final SupabaseClient _client;

  TokenDispositivoRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  /// `upsert` por `token` (columna `unique`, no por `id`): si este mismo
  /// dispositivo ya había guardado un token antes, la fila se actualiza en
  /// vez de duplicarse — cubre también el caso de un dispositivo que
  /// cambia de cuenta (`usuario_id` se reasigna a quien acaba de iniciar
  /// sesión).
  @override
  Future<void> guardarToken({required String token, required String plataforma}) {
    return conManejoDeErroresSupabase(
      'tokens_dispositivo.guardarToken',
      () async {
        await _client.from('tokens_dispositivo').upsert({
          'usuario_id': _userId,
          'token': token,
          'plataforma': plataforma,
        }, onConflict: 'token');
      },
    );
  }

  @override
  Future<void> eliminarToken(String token) {
    return conManejoDeErroresSupabase(
      'tokens_dispositivo.eliminarToken',
      () async {
        await _client.from('tokens_dispositivo').delete().eq('token', token);
      },
    );
  }
}
