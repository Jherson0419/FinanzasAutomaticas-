enum RolMensajeConsejo { usuario, asistente }

/// Un turno del chat de consejos financieros (Fase 30) — persiste en
/// `mensajes_consejos` (Supabase). El primer mensaje de `usuario` de una
/// conversación nueva lo arma la Edge Function `generar-consejos` a partir
/// de un `ResumenParaConsejos` (agregado y anonimizado), no lo escribe el
/// usuario a mano.
class MensajeConsejo {
  final String id;
  final RolMensajeConsejo rol;
  final String contenido;
  final DateTime fecha;

  const MensajeConsejo({
    required this.id,
    required this.rol,
    required this.contenido,
    required this.fecha,
  });
}
