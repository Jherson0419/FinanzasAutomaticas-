import '../entities/tema_app.dart';

abstract class PreferenciasRepository {
  Future<String?> obtenerNombre();
  Future<void> guardarNombre(String nombre);
  Future<bool> onboardingCompletado();
  Future<void> marcarOnboardingCompletado();

  /// Tema de la app (Fase 31): claro/oscuro/según el sistema. 100% local —
  /// a diferencia del nick/avatar/Instagram (Fase 31 también, pero esos
  /// viven en `usuarios` de Supabase vía `PerfilRepository`), esto no tiene
  /// ningún motivo para estar en la nube.
  Future<TemaApp> obtenerTema();
  Future<void> guardarTema(TemaApp tema);

  /// API key de Gemini usada por `ObtenerConsejosFinancieros` — se guarda
  /// solo localmente, nunca se envía a nada que no sea la API de Gemini.
  Future<String?> obtenerApiKeyGemini();
  Future<void> guardarApiKeyGemini(String apiKey);

  /// `true` una vez que la migración de datos financieros a Supabase
  /// (Fase 21) terminó con éxito para este dispositivo — a partir de ahí
  /// los repositorios de cuentas/categorías/transacciones/deudas/pagos
  /// resuelven siempre a los adapters de Supabase, nunca más a Drift.
  /// `false` también para una instalación nueva sin ninguna sesión previa
  /// (se marca `true` sin migrar nada si no hay datos locales que subir,
  /// ver `RootScreen`).
  Future<bool> datosEnLaNube();
  Future<void> marcarDatosEnLaNube();

  /// "Recuérdame" del login (Fase 65) — `true` por defecto (incluido si
  /// nunca se guardó nada, ej. instalaciones/sesiones de antes de esta
  /// fase): así nadie pierde su sesión ya iniciada solo por actualizar la
  /// app. Si queda en `false`, el próximo arranque en frío cierra la
  /// sesión de Supabase automáticamente aunque siga técnicamente vigente
  /// (ver el punto de arranque en `main.dart`), forzando el login de nuevo.
  Future<bool> recordarSesion();
  Future<void> guardarRecordarSesion(bool recordar);

  /// Última vez que se generaron notificaciones de vencimiento de deudas
  /// (Fase 70, `GenerarNotificacionesVencimiento`) — `null` si nunca se
  /// generaron en este dispositivo. Sirve para llamar al RPC
  /// `generar_notificaciones_vencimiento` como mucho una vez por día en
  /// vez de en cada apertura del dashboard: no evita duplicados por sí
  /// sola (eso lo hace el propio RPC, comparando contra notificaciones ya
  /// insertadas), pero sí evita la llamada de red innecesaria cuando ya se
  /// generaron hoy.
  Future<DateTime?> ultimaGeneracionNotificacionesVencimiento();
  Future<void> guardarUltimaGeneracionNotificacionesVencimiento(DateTime fecha);

  /// Borra TODAS las preferencias locales (nombre, API key de Gemini,
  /// onboarding completado, datos en la nube) — usado únicamente por
  /// `EliminarCuentaDeUsuario` (Fase 22) tras borrar
  /// los datos financieros y la cuenta de autenticación, para que el
  /// dispositivo quede como recién instalado.
  Future<void> limpiarTodo();
}
