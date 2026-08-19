/// Puerto para el token de webhook por usuario (Fase 25) — identifica de
/// forma segura de quién es cada envío externo (Atajo de iOS, regla de
/// correo) hacia la Edge Function `capturar-transaccion`. Deliberadamente
/// no bifurca Drift/Supabase como los 5 repositorios de datos financieros:
/// el token de webhook es un concepto que solo existe una vez que los
/// datos ya viven en la nube, no tiene equivalente local.
abstract class AutomatizacionRepository {
  /// El token actual del usuario — nunca cambia salvo que se regenere.
  Future<String> obtenerTokenWebhook();

  /// Genera un token nuevo y lo reemplaza en el servidor, invalidando el
  /// anterior de inmediato (cualquier automatización que lo tuviera
  /// configurado deja de funcionar). Devuelve el token nuevo.
  Future<String> regenerarTokenWebhook();
}
