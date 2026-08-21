import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:finanzas_automaticas/config/supabase_config.dart';
import 'package:finanzas_automaticas/infrastructure/auth/supabase_auth_repository.dart';

/// Fake de `UrlLauncherPlatform` (Fase 59): permite comprobar CON QUÉ url y
/// modo `iniciarSesionConGoogle` intenta abrir el navegador, sin abrir nada
/// de verdad. `Fake` + `MockPlatformInterfaceMixin` es el mecanismo propio
/// de `plugin_platform_interface` para fakear un `PlatformInterface` (lo usa
/// el propio paquete `url_launcher` en sus tests) — no es un framework de
/// mocks tipo mockito/mocktail.
class _FakeUrlLauncherPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? urlLanzada;
  PreferredLaunchMode? modoLanzado;
  bool respuesta = true;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urlLanzada = url;
    modoLanzado = options.mode;
    return respuesta;
  }
}

/// Storage en memoria para el code verifier PKCE que genera
/// `getOAuthSignInUrl` — sin `pkceAsyncStorage`, `SupabaseClient` no tiene
/// dónde guardarlo y `signInWithOAuth` lanza un `assert` antes de construir
/// la URL. En la app real esto lo provee `Supabase.initialize` (respaldado
/// por `SharedPreferences`); aquí basta un mapa en memoria.
class _FakeGotrueAsyncStorage extends GotrueAsyncStorage {
  final Map<String, String> _valores = {};

  @override
  Future<String?> getItem({required String key}) async => _valores[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _valores[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _valores.remove(key);
  }
}

/// Cliente Supabase "de mentira": la construcción de la URL de OAuth
/// (`GoTrueClient.getOAuthSignInUrl`) es puramente local — arma la query
/// string con el `redirect_to` pedido y un `code_challenge` PKCE generado
/// en el dispositivo, sin ninguna llamada de red — así que instanciar el
/// cliente contra esta URL de ejemplo no toca la red real. Mismo criterio
/// que `perfil_repository_supabase_test.dart`/`supabase_adapters_mapeo_test.dart`.
final _clienteFalso = SupabaseClient(
  'https://example.supabase.co',
  'clave-de-prueba',
  authOptions: AuthClientOptions(pkceAsyncStorage: _FakeGotrueAsyncStorage()),
);

void main() {
  late _FakeUrlLauncherPlatform fakeUrlLauncher;
  late UrlLauncherPlatform plataformaOriginal;

  setUp(() {
    plataformaOriginal = UrlLauncherPlatform.instance;
    fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = plataformaOriginal;
  });

  group(
    'iniciarSesionConGoogle (Fase 56; redirect corregido/confirmado en la Fase 59)',
    () {
      test(
        'pasa redirect_to=authEmailRedirectUrl y abre en modo externalApplication',
        () async {
          final repo = SupabaseAuthRepository(_clienteFalso);

          await repo.iniciarSesionConGoogle();

          expect(fakeUrlLauncher.urlLanzada, isNotNull);
          final uri = Uri.parse(fakeUrlLauncher.urlLanzada!);
          expect(uri.queryParameters['redirect_to'], authEmailRedirectUrl);
          expect(uri.queryParameters['provider'], 'google');
          expect(
            fakeUrlLauncher.modoLanzado,
            PreferredLaunchMode.externalApplication,
          );
        },
      );

      test(
        'si el navegador no se pudo abrir, lanza un StateError explícito',
        () async {
          fakeUrlLauncher.respuesta = false;
          final repo = SupabaseAuthRepository(_clienteFalso);

          await expectLater(
            () => repo.iniciarSesionConGoogle(),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('No se pudo abrir la pantalla de Google'),
              ),
            ),
          );
        },
      );
    },
  );
}
