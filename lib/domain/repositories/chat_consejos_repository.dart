import '../entities/mensaje_consejo.dart';
import '../usecases/dto/resumen_para_consejos.dart';

/// Puerto del chat de consejos financieros (Fase 30) — reemplaza al
/// `generarConsejos` de un solo turno de `ConsejosFinancierosRepository`
/// (Fase 24, sigue en el repo porque `GeminiConsejosRepository` todavía lo
/// implementa como adapter desconectado, ver `CONTEXTO.md`).
abstract class ChatConsejosRepository {
  /// Historial completo de la conversación del usuario actual, ordenado por
  /// fecha ascendente. Lectura simple contra `mensajes_consejos`, sin pasar
  /// por la Edge Function — solo hay política de `SELECT` para el dueño de
  /// la fila.
  Future<List<MensajeConsejo>> obtenerHistorial();

  /// Envía un mensaje y espera la respuesta del asistente. La Edge Function
  /// guarda TANTO el mensaje del usuario como la respuesta antes de
  /// devolver éxito (o ninguno de los dos, si algo falla) — nunca deja un
  /// mensaje de usuario huérfano sin respuesta. Quien llama debe refrescar
  /// `obtenerHistorial()` después para ver los mensajes nuevos.
  ///
  /// Cuando [esPrimerMensaje] es `true`, [resumen] es obligatorio y el
  /// contenido real del primer mensaje de usuario lo arma el servidor a
  /// partir de él (formato legible, agregado y anonimizado) — [mensaje] se
  /// ignora en ese caso.
  Future<void> enviarMensaje({
    required String mensaje,
    bool esPrimerMensaje = false,
    ResumenParaConsejos? resumen,
  });
}
