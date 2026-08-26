/// Perfil público mínimo de OTRO usuario — nunca expone más que nick y
/// avatar (mismo criterio de anonimización que `nick_disponible`, Fase 31:
/// una función `SECURITY DEFINER` puede confirmar/leer estos 2 campos de
/// cualquier usuario sin exponerle el resto de su fila de `usuarios`).
class PerfilPublico {
  final String usuarioId;
  final String? nick;
  final String? avatarId;

  const PerfilPublico({required this.usuarioId, this.nick, this.avatarId});
}

/// Una solicitud de amistad recibida, con el perfil público de quien la
/// envió ya resuelto — para no obligar a la UI a cruzar `solicitudes_
/// amistad` con `usuarios` por su cuenta.
class SolicitudRecibida {
  final String solicitudId;
  final PerfilPublico deQuien;

  const SolicitudRecibida({required this.solicitudId, required this.deQuien});
}
