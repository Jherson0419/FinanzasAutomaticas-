/// Puerto de autenticación. El adapter concreto (`SupabaseAuthRepository`)
/// vive en `infrastructure/` — el dominio no sabe que existe Supabase.
///
/// Solo cubre autenticación: la sesión de Supabase decide si el usuario
/// puede entrar a la app, pero los datos financieros nunca pasan por este
/// puerto ni salen de este dispositivo (siguen siendo 100% Drift local).
abstract class AuthRepository {
  /// `true` si hay una sesión activa restaurada/vigente.
  bool get haySesionActiva;

  Future<void> iniciarSesion({required String email, required String password});

  Future<void> crearCuenta({required String email, required String password});

  /// Login con Google (Fase 56) — abre el flujo OAuth en el navegador
  /// externo del dispositivo; la sesión no queda activa al terminar este
  /// método (solo se abrió el navegador), sino más tarde, cuando Supabase
  /// redirige de vuelta a la app por el mismo deep link
  /// `finzo://login-callback` que ya escucha `supabase_flutter` desde la
  /// Fase 54 (`SupabaseAuth`, interno del paquete) — `haySesionActivaProvider`
  /// ya es reactivo a ese momento (Fase 54), así que ninguna pantalla tiene
  /// que esperar el resultado de este método a mano.
  Future<void> iniciarSesionConGoogle();

  Future<void> cerrarSesion();

  /// Envía el correo de recuperación de contraseña (Fase 65) — el link que
  /// trae redirige a `finzo://reset-password`, que `supabase_flutter`
  /// reconoce internamente (arma sola una sesión de recuperación y emite
  /// `AuthChangeEvent.passwordRecovery`) igual que ya hace con
  /// `login-callback` desde la Fase 54.
  Future<void> enviarLinkRecuperacion({required String email});

  /// Cambia la contraseña del usuario de la sesión activa — solo tiene
  /// sentido llamarlo con una sesión de recuperación recién armada por el
  /// deep link de arriba, pero funciona igual con cualquier sesión activa
  /// (el SDK no distingue).
  Future<void> actualizarContrasena({required String nuevaContrasena});

  /// Borra permanentemente la cuenta de autenticación del usuario actual
  /// (Fase 22, requisito de Apple — Guideline 5.1.1(v)). Solo puede borrar
  /// la sesión propia: nunca recibe ni acepta un id de usuario distinto.
  /// Debe llamarse después de borrar los datos financieros del usuario
  /// (`EliminarCuentaDeUsuario`), nunca antes — una vez que la cuenta de
  /// auth desaparece, ya no hay sesión con la que autorizar el borrado de
  /// datos vía RLS.
  Future<void> eliminarCuenta();
}
