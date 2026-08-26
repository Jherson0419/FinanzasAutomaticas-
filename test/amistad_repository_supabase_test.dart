import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finanzas_automaticas/infrastructure/persistence/supabase/amistad_repository_supabase.dart';

/// Cliente Supabase "de mentira": nunca se llama a ningún método que haga
/// red — solo existe para poder instanciar el adapter y llamar directamente
/// a sus métodos `aDominioPerfilPublico`/`traducirErrorEnviarSolicitud`
/// (`@visibleForTesting`), funciones puras que no leen `auth.currentUser`.
/// Mismo criterio que `perfil_repository_supabase_test.dart`.
final _clienteFalso = SupabaseClient(
  'https://example.supabase.co',
  'clave-de-prueba',
);

void main() {
  final repo = AmistadRepositorySupabase(_clienteFalso);

  group('aDominioPerfilPublico', () {
    test('mapea id/nick/avatar_id cuando todos tienen valor', () {
      final perfil = repo.aDominioPerfilPublico({
        'id': 'user-2',
        'nick': 'jherson_v',
        'avatar_id': 'https://storage.example.com/avatares/foo/avatar.jpg',
      });

      expect(perfil.usuarioId, 'user-2');
      expect(perfil.nick, 'jherson_v');
      expect(
        perfil.avatarId,
        'https://storage.example.com/avatares/foo/avatar.jpg',
      );
    });

    test('mapea nick/avatar_id nulos (perfil sin completar)', () {
      final perfil = repo.aDominioPerfilPublico({
        'id': 'user-2',
        'nick': null,
        'avatar_id': null,
      });

      expect(perfil.usuarioId, 'user-2');
      expect(perfil.nick, isNull);
      expect(perfil.avatarId, isNull);
    });
  });

  group('traducirErrorEnviarSolicitud', () {
    test('un conflicto de unicidad (23505) se traduce a SolicitudYaEnviadaError', () {
      final error = repo.traducirErrorEnviarSolicitud(
        PostgrestException(
          message:
              'duplicate key value violates unique constraint '
              '"solicitudes_amistad_de_usuario_id_para_usuario_id_key"',
          code: '23505',
        ),
      );

      expect(error, isA<SolicitudYaEnviadaError>());
    });

    test('un PostgrestException distinto de 23505 da un error genérico', () {
      final error = repo.traducirErrorEnviarSolicitud(
        PostgrestException(message: 'permission denied', code: '42501'),
      );

      expect(error, isA<StateError>());
      expect(error, isNot(isA<SolicitudYaEnviadaError>()));
      expect(
        (error as StateError).message,
        'No se pudo enviar la solicitud, intenta de nuevo.',
      );
    });

    test('un error que no es de Postgrest también da el mensaje genérico', () {
      final error = repo.traducirErrorEnviarSolicitud(
        const SocketExceptionFake(),
      );

      expect(error, isA<StateError>());
      expect(error, isNot(isA<SolicitudYaEnviadaError>()));
    });
  });
}

/// Excepción simple para simular un fallo que no viene de Postgrest (mismo
/// patrón que `perfil_repository_supabase_test.dart`).
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
  @override
  String toString() => 'SocketExceptionFake';
}
