import '../usecases/dto/resumen_para_consejos.dart';

/// Se lanza cuando no hay una API key de Gemini configurada. Es un tipo
/// dedicado (no un `StateError` genérico) para que la UI pueda distinguirlo
/// y ofrecer un botón directo a Ajustes en vez de un mensaje de error suelto.
///
/// Fase 24: solo lo lanza `GeminiConsejosRepository` (modelo de "cada
/// usuario pone su propia API key", Fase 17), que sigue en el repo pero ya
/// no está conectado en `providers.dart` — se reemplazó por
/// `EdgeFunctionConsejosRepository`, que nunca necesita una API key del
/// usuario y por lo tanto nunca lanza esto.
class ApiKeyGeminiFaltanteError extends StateError {
  ApiKeyGeminiFaltanteError()
    : super('Configura tu API key de Gemini en Ajustes para generar consejos');
}

/// Se lanza cuando el usuario ya alcanzó el límite diario de mensajes
/// (Fase 24 — 5 por día, subido a 15 en la Fase 34, controlado server-side
/// en la Edge Function
/// `generar-consejos` contra la tabla `uso_consejos`; Fase 30: el chat
/// cuenta mensajes enviados en vez de "generaciones", mismo mecanismo).
/// Tipo dedicado, mismo motivo que `ApiKeyGeminiFaltanteError`: para que la
/// UI muestre un mensaje específico en vez de un error genérico. Lo sigue
/// usando `ChatConsejosRepository` (Fase 30) además del puerto de un solo
/// turno de abajo.
class LimiteDiarioConsejosError extends StateError {
  LimiteDiarioConsejosError()
    : super('Alcanzaste el límite de mensajes por hoy. Vuelve mañana.');
}

/// Puerto para generar consejos financieros a partir de un resumen ya
/// agregado y anonimizado. El adapter concreto (`GeminiConsejosRepository`)
/// vive en `infrastructure/` — el dominio no sabe que existe Gemini.
abstract class ConsejosFinancierosRepository {
  Future<List<String>> generarConsejos(ResumenParaConsejos resumen);
}
