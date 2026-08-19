import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finanzas_automaticas/infrastructure/persistence/supabase/perfil_repository_supabase.dart';

/// Cliente Supabase "de mentira": nunca se llama a ningún método que haga
/// red — solo existe para poder instanciar el adapter y llamar directamente
/// a sus métodos `aDominio`/`traducirErrorGuardarNick` (`@visibleForTesting`),
/// funciones puras que no leen `auth.currentUser`. Mismo criterio que
/// `supabase_adapters_mapeo_test.dart`.
final _clienteFalso = SupabaseClient(
  'https://example.supabase.co',
  'clave-de-prueba',
);

void main() {
  final repo = PerfilRepositorySupabase(_clienteFalso);

  group('aDominio', () {
    test('mapea nick/avatar_id/instagram cuando los tres tienen valor', () {
      final perfil = repo.aDominio({
        'nick': 'jherson_v',
        'avatar_id': 'cohete',
        'instagram': '@jherson.finanzas',
      });

      expect(perfil.nick, 'jherson_v');
      expect(perfil.avatarId, 'cohete');
      expect(perfil.instagram, '@jherson.finanzas');
    });

    test('mapea nulos correctamente (perfil recién creado, sin nada aún)', () {
      final perfil = repo.aDominio({
        'nick': null,
        'avatar_id': null,
        'instagram': null,
      });

      expect(perfil.nick, isNull);
      expect(perfil.avatarId, isNull);
      expect(perfil.instagram, isNull);
    });
  });

  group('traducirErrorGuardarNick', () {
    test(
      'un conflicto de unicidad (23505) se traduce a NickNoDisponibleError',
      () {
        final error = repo.traducirErrorGuardarNick(
          PostgrestException(
            message:
                'duplicate key value violates unique constraint '
                '"usuarios_nick_key"',
            code: '23505',
          ),
        );

        expect(error, isA<NickNoDisponibleError>());
      },
    );

    test('un PostgrestException distinto de 23505 da un error genérico', () {
      final error = repo.traducirErrorGuardarNick(
        PostgrestException(message: 'permission denied', code: '42501'),
      );

      expect(error, isA<StateError>());
      expect(error, isNot(isA<NickNoDisponibleError>()));
      expect(
        (error as StateError).message,
        'No se pudo guardar, intenta de nuevo.',
      );
    });

    test('un error que no es de Postgrest también da el mensaje genérico', () {
      final error = repo.traducirErrorGuardarNick(const SocketExceptionFake());

      expect(error, isA<StateError>());
      expect(error, isNot(isA<NickNoDisponibleError>()));
    });
  });
}

/// Excepción simple para simular un fallo que no viene de Postgrest (mismo
/// patrón que `edge_function_consejos_repository_test.dart`).
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
  @override
  String toString() => 'SocketExceptionFake';
}
