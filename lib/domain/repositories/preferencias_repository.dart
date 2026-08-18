abstract class PreferenciasRepository {
  Future<String?> obtenerNombre();
  Future<void> guardarNombre(String nombre);
  Future<bool> onboardingCompletado();
  Future<void> marcarOnboardingCompletado();

  /// API key de Gemini usada por `ObtenerConsejosFinancieros` — se guarda
  /// solo localmente, nunca se envía a nada que no sea la API de Gemini.
  Future<String?> obtenerApiKeyGemini();
  Future<void> guardarApiKeyGemini(String apiKey);

  /// Bloqueo local (PIN/biométrico, Fase 18) — nunca sale de este
  /// dispositivo. El PIN se guarda hasheado (`domain/pin_hash.dart`),
  /// nunca en texto plano.
  Future<String?> obtenerPinHash();
  Future<void> guardarPinHash(String hash);
  Future<bool> obtenerBloqueoBiometricoActivo();
  Future<void> guardarBloqueoBiometricoActivo(bool activo);

  /// El usuario tocó "Omitir por ahora" en `ConfigurarBloqueoScreen" — no
  /// se le vuelve a ofrecer configurar bloqueo automáticamente.
  Future<bool> bloqueoOmitido();
  Future<void> marcarBloqueoOmitido();

  /// `true` una vez que la migración de datos financieros a Supabase
  /// (Fase 21) terminó con éxito para este dispositivo — a partir de ahí
  /// los repositorios de cuentas/categorías/transacciones/deudas/pagos
  /// resuelven siempre a los adapters de Supabase, nunca más a Drift.
  /// `false` también para una instalación nueva sin ninguna sesión previa
  /// (se marca `true` sin migrar nada si no hay datos locales que subir,
  /// ver `RootScreen`).
  Future<bool> datosEnLaNube();
  Future<void> marcarDatosEnLaNube();

  /// Borra TODAS las preferencias locales (nombre, API key de Gemini, PIN,
  /// bloqueo biométrico/omitido, onboarding completado, datos en la nube) —
  /// usado únicamente por `EliminarCuentaDeUsuario` (Fase 22) tras borrar
  /// los datos financieros y la cuenta de autenticación, para que el
  /// dispositivo quede como recién instalado.
  Future<void> limpiarTodo();
}
