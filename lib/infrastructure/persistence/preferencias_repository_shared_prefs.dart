import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/tema_app.dart';
import '../../domain/repositories/preferencias_repository.dart';

/// Adapter de `PreferenciasRepository` sobre `shared_preferences`.
/// Vive fuera de `infrastructure/persistence/drift/` a propósito: no es
/// dato financiero del dominio, es configuración de la app en sí.
class PreferenciasRepositorySharedPrefs implements PreferenciasRepository {
  static const _claveNombre = 'nombre_usuario';
  static const _claveOnboardingCompletado = 'onboarding_completado';
  static const _claveApiKeyGemini = 'api_key_gemini';

  /// Pública a propósito (Fase 31): `providers.dart` necesita leer este
  /// mismo valor de forma síncrona (mismo motivo que `claveDatosEnLaNube`,
  /// Fase 21 — `MaterialApp.themeMode` no puede esperar un `Future`).
  static const claveTema = 'tema_app';

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

  /// `TemaApp.oscuro` por defecto — mismo look que tenía la app antes de
  /// la Fase 31 (oscuro permanente), para no cambiarle el tema a nadie que
  /// actualice sin haber elegido nada todavía.
  @override
  Future<TemaApp> obtenerTema() async {
    final valor = _prefs.getString(claveTema);
    if (valor == null) return TemaApp.oscuro;
    return TemaApp.values.byName(valor);
  }

  @override
  Future<void> guardarTema(TemaApp tema) async {
    await _prefs.setString(claveTema, tema.name);
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
    await _prefs.remove(claveDatosEnLaNube);
    await _prefs.remove(claveTema);
  }
}
