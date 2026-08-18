import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/preferencias_repository.dart';

/// Adapter de `PreferenciasRepository` sobre `shared_preferences`.
/// Vive fuera de `infrastructure/persistence/drift/` a propósito: no es
/// dato financiero del dominio, es configuración de la app en sí.
class PreferenciasRepositorySharedPrefs implements PreferenciasRepository {
  static const _claveNombre = 'nombre_usuario';
  static const _claveOnboardingCompletado = 'onboarding_completado';
  static const _claveApiKeyGemini = 'api_key_gemini';
  static const _clavePinHash = 'pin_hash';
  static const _claveBloqueoBiometricoActivo = 'bloqueo_biometrico_activo';
  static const _claveBloqueoOmitido = 'bloqueo_omitido';

  /// Pública a propósito (Fase 21): `providers.dart` necesita leer este
  /// mismo valor de forma síncrona (los providers de repositorios de datos
  /// financieros son `Provider`, no pueden esperar un `Future`) sin
  /// duplicar el nombre de la clave por su cuenta.
  static const claveDatosEnLaNube = 'datos_en_la_nube';

  final SharedPreferences _prefs;

  PreferenciasRepositorySharedPrefs(this._prefs);

  @override
  Future<String?> obtenerNombre() async => _prefs.getString(_claveNombre);

  @override
  Future<void> guardarNombre(String nombre) async {
    await _prefs.setString(_claveNombre, nombre);
  }

  @override
  Future<bool> onboardingCompletado() async =>
      _prefs.getBool(_claveOnboardingCompletado) ?? false;

  @override
  Future<void> marcarOnboardingCompletado() async {
    await _prefs.setBool(_claveOnboardingCompletado, true);
  }

  @override
  Future<String?> obtenerApiKeyGemini() async =>
      _prefs.getString(_claveApiKeyGemini);

  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {
    await _prefs.setString(_claveApiKeyGemini, apiKey);
  }

  @override
  Future<String?> obtenerPinHash() async => _prefs.getString(_clavePinHash);

  @override
  Future<void> guardarPinHash(String hash) async {
    await _prefs.setString(_clavePinHash, hash);
  }

  @override
  Future<bool> obtenerBloqueoBiometricoActivo() async =>
      _prefs.getBool(_claveBloqueoBiometricoActivo) ?? false;

  @override
  Future<void> guardarBloqueoBiometricoActivo(bool activo) async {
    await _prefs.setBool(_claveBloqueoBiometricoActivo, activo);
  }

  @override
  Future<bool> bloqueoOmitido() async =>
      _prefs.getBool(_claveBloqueoOmitido) ?? false;

  @override
  Future<void> marcarBloqueoOmitido() async {
    await _prefs.setBool(_claveBloqueoOmitido, true);
  }

  @override
  Future<bool> datosEnLaNube() async =>
      _prefs.getBool(claveDatosEnLaNube) ?? false;

  @override
  Future<void> marcarDatosEnLaNube() async {
    await _prefs.setBool(claveDatosEnLaNube, true);
  }

  @override
  Future<void> limpiarTodo() async {
    await _prefs.remove(_claveNombre);
    await _prefs.remove(_claveOnboardingCompletado);
    await _prefs.remove(_claveApiKeyGemini);
    await _prefs.remove(_clavePinHash);
    await _prefs.remove(_claveBloqueoBiometricoActivo);
    await _prefs.remove(_claveBloqueoOmitido);
    await _prefs.remove(claveDatosEnLaNube);
  }
}
