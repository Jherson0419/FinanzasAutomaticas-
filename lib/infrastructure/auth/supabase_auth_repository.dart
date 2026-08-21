import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../domain/repositories/auth_repository.dart';

/// Adapter de `AuthRepository` sobre Supabase Auth. Traduce los errores
/// crudos de Supabase a mensajes en español, accionables, sin exponer el
/// error técnico al usuario final (sí se loguea con `debugPrint`).
class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  bool get haySesionActiva => _client.auth.currentSession != null;

  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      debugPrint('SupabaseAuthRepository.iniciarSesion: ${error.message}');
      throw StateError(_mensajeError(error, alIniciarSesion: true));
    } catch (error) {
      debugPrint('SupabaseAuthRepository.iniciarSesion: $error');
      throw StateError(
        'No se pudo iniciar sesión. Revisa tu conexión a internet e intenta de nuevo.',
      );
    }
  }

  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: authEmailRedirectUrl,
      );
    } on AuthException catch (error) {
      debugPrint('SupabaseAuthRepository.crearCuenta: ${error.message}');
      throw StateError(_mensajeError(error, alIniciarSesion: false));
    } catch (error) {
      debugPrint('SupabaseAuthRepository.crearCuenta: $error');
      throw StateError(
        'No se pudo crear la cuenta. Revisa tu conexión a internet e intenta de nuevo.',
      );
    }
  }

  /// Fase 56 — usa `signInWithOAuth` (parte de `supabase_flutter`, ya una
  /// dependencia) en vez de un paquete nativo tipo `google_sign_in`: abre
  /// el navegador externo del sistema con la pantalla de consentimiento de
  /// Google, y Supabase redirige de vuelta a la app por
  /// `authEmailRedirectUrl` (el mismo esquema `finzo://login-callback` que
  /// ya escucha `SupabaseAuth` internamente desde la Fase 54) — nada de
  /// integración nativa de Google adicional en el proyecto Xcode/Gradle.
  /// Este método solo abre esa pantalla; no espera a que el login termine
  /// (`haySesionActivaProvider` reacciona solo cuando la sesión llegue).
  @override
  Future<void> iniciarSesionConGoogle() async {
    try {
      final seAbrio = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: authEmailRedirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      if (!seAbrio) {
        throw StateError(
          'No se pudo abrir la pantalla de Google. Intenta de nuevo.',
        );
      }
    } on AuthException catch (error) {
      debugPrint('SupabaseAuthRepository.iniciarSesionConGoogle: ${error.message}');
      throw StateError(_mensajeError(error, alIniciarSesion: true));
    } on StateError {
      rethrow;
    } catch (error) {
      debugPrint('SupabaseAuthRepository.iniciarSesionConGoogle: $error');
      throw StateError(
        'No se pudo continuar con Google. Revisa tu conexión a internet e '
        'intenta de nuevo.',
      );
    }
  }

  @override
  Future<void> cerrarSesion() => _client.auth.signOut();

  /// El SDK de `supabase_flutter` no expone una forma de que un usuario
  /// borre su propia cuenta de autenticación: `auth.admin.deleteUser`
  /// existe en el paquete, pero solo funciona con un cliente inicializado
  /// con la service role key (nunca debe viajar al dispositivo del
  /// usuario). Por eso esto invoca una Edge Function propia
  /// (`supabase/functions/eliminar-cuenta/`, ver ese directorio) que corre
  /// server-side con la service role key, identifica al usuario por el JWT
  /// de la petición (nunca por un id que mande el cliente) y borra
  /// exactamente esa cuenta. Tras el borrado remoto, limpia también la
  /// sesión local para que `haySesionActiva` pase a `false` de inmediato.
  @override
  Future<void> eliminarCuenta() async {
    try {
      // `invoke` lanza `FunctionException` en cualquier respuesta que no
      // sea 2xx — si esto retorna sin lanzar, la Edge Function ya borró la
      // cuenta server-side.
      await _client.functions.invoke('eliminar-cuenta');
    } on FunctionException catch (error) {
      debugPrint('SupabaseAuthRepository.eliminarCuenta: ${error.details}');
      throw StateError(
        'No se pudo eliminar la cuenta. Revisa tu conexión a internet e '
        'intenta de nuevo.',
      );
    } catch (error) {
      debugPrint('SupabaseAuthRepository.eliminarCuenta: $error');
      throw StateError(
        'No se pudo eliminar la cuenta. Revisa tu conexión a internet e '
        'intenta de nuevo.',
      );
    }
    await _client.auth.signOut();
  }

  String _mensajeError(AuthException error, {required bool alIniciarSesion}) {
    final mensaje = error.message.toLowerCase();
    if (mensaje.contains('invalid login credentials') ||
        mensaje.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (mensaje.contains('already registered') ||
        mensaje.contains('user already exists')) {
      return 'Ese correo ya está registrado. Inicia sesión en vez de crear una cuenta nueva.';
    }
    if (mensaje.contains('password') &&
        (mensaje.contains('short') || mensaje.contains('at least'))) {
      return 'La contraseña es muy corta (mínimo 6 caracteres).';
    }
    if (mensaje.contains('email') && mensaje.contains('invalid')) {
      return 'El correo no tiene un formato válido.';
    }
    if (mensaje.contains('network') || mensaje.contains('socket')) {
      return 'Sin conexión a internet. Intenta de nuevo.';
    }
    return alIniciarSesion
        ? 'No se pudo iniciar sesión: ${error.message}'
        : 'No se pudo crear la cuenta: ${error.message}';
  }
}
