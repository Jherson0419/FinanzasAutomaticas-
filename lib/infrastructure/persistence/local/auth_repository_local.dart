import '../../../domain/repositories/auth_repository.dart';
import 'modo_local.dart';

/// `AuthRepository` del modo local (Fase 78): siempre hay "sesión" — no
/// existe usuario remoto, el dispositivo es el usuario. Todo lo que
/// necesita Supabase Auth lanza [UnsupportedError].
class AuthRepositoryLocal implements AuthRepository {
  const AuthRepositoryLocal();

  @override
  bool get haySesionActiva => true;

  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async => throw noDisponibleEnModoLocal('Iniciar sesión');

  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async => throw noDisponibleEnModoLocal('Crear cuenta');

  @override
  Future<void> iniciarSesionConGoogle() async =>
      throw noDisponibleEnModoLocal('Iniciar sesión con Google');

  @override
  Future<void> cerrarSesion() async =>
      throw noDisponibleEnModoLocal('Cerrar sesión');

  @override
  Future<void> enviarLinkRecuperacion({required String email}) async =>
      throw noDisponibleEnModoLocal('Recuperar contraseña');

  @override
  Future<void> actualizarContrasena({required String nuevaContrasena}) async =>
      throw noDisponibleEnModoLocal('Cambiar contraseña');

  @override
  Future<void> eliminarCuenta() async =>
      throw noDisponibleEnModoLocal('Eliminar cuenta');
}
