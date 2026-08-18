import '../usecases/dto/resumen_para_consejos.dart';

/// Se lanza cuando no hay una API key de Gemini configurada. Es un tipo
/// dedicado (no un `StateError` genérico) para que la UI pueda distinguirlo
/// y ofrecer un botón directo a Ajustes en vez de un mensaje de error suelto.
class ApiKeyGeminiFaltanteError extends StateError {
  ApiKeyGeminiFaltanteError()
    : super('Configura tu API key de Gemini en Ajustes para generar consejos');
}

/// Puerto para generar consejos financieros a partir de un resumen ya
/// agregado y anonimizado. El adapter concreto (`GeminiConsejosRepository`)
/// vive en `infrastructure/` — el dominio no sabe que existe Gemini.
abstract class ConsejosFinancierosRepository {
  Future<List<String>> generarConsejos(ResumenParaConsejos resumen);
}
