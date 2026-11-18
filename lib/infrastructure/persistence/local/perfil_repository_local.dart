import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/perfil.dart';
import '../../../domain/repositories/perfil_repository.dart';
import 'modo_local.dart';

/// `PerfilRepository` del modo local (Fase 78) sobre `SharedPreferences`.
///
/// - `nickDisponible` siempre es `true`: no hay otros usuarios contra
///   quienes chocar.
/// - `subirFotoAvatar` lanza [UnsupportedError]: la foto vive en Supabase
///   Storage. `guardarAvatarId` sí funciona (avatares prediseñados).
class PerfilRepositoryLocal implements PerfilRepository {
  static const claveNick = '${prefijoModoLocal}perfil.nick';
  static const claveAvatarId = '${prefijoModoLocal}perfil.avatar_id';
  static const claveInstagram = '${prefijoModoLocal}perfil.instagram';
  static const claveNombreCompleto =
      '${prefijoModoLocal}perfil.nombre_completo';
  static const claveCelular = '${prefijoModoLocal}perfil.celular';
  static const claveOtraRedSocial = '${prefijoModoLocal}perfil.otra_red_social';

  final SharedPreferences _prefs;

  PerfilRepositoryLocal(this._prefs);

  @override
  Future<Perfil> obtenerPerfil() async => Perfil(
    nick: _prefs.getString(claveNick),
    avatarId: _prefs.getString(claveAvatarId),
    instagram: _prefs.getString(claveInstagram),
    nombreCompleto: _prefs.getString(claveNombreCompleto),
    celular: _prefs.getString(claveCelular),
    otraRedSocial: _prefs.getString(claveOtraRedSocial),
  );

  @override
  Future<bool> nickDisponible(String nick) async => true;

  @override
  Future<void> guardarNick(String nick) => _guardar(claveNick, nick);

  @override
  Future<void> guardarAvatarId(String avatarId) =>
      _guardar(claveAvatarId, avatarId);

  @override
  Future<String> subirFotoAvatar(
    List<int> bytes, {
    required String extension,
  }) async => throw noDisponibleEnModoLocal('Subir foto de perfil');

  @override
  Future<void> guardarInstagram(String? instagram) =>
      _guardar(claveInstagram, instagram);

  @override
  Future<void> guardarNombreCompleto(String? nombreCompleto) =>
      _guardar(claveNombreCompleto, nombreCompleto);

  @override
  Future<void> guardarCelular(String? celular) =>
      _guardar(claveCelular, celular);

  @override
  Future<void> guardarOtraRedSocial(String? otraRedSocial) =>
      _guardar(claveOtraRedSocial, otraRedSocial);

  Future<void> _guardar(String clave, String? valor) async {
    if (valor == null) {
      await _prefs.remove(clave);
    } else {
      await _prefs.setString(clave, valor);
    }
  }
}
