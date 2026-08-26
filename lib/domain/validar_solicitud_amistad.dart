/// Compartida por `AmistadRepository.enviarSolicitud` (Fase 63): nadie
/// puede enviarse una solicitud de amistad a sí mismo. La constraint
/// `unique(de_usuario_id, para_usuario_id)` de `solicitudes_amistad` no
/// cubre este caso (una fila con `de == para` es "única" igual), así que la
/// validación vive aquí, del lado del dominio.
void validarSolicitudAmistad({
  required String miUsuarioId,
  required String paraUsuarioId,
}) {
  if (miUsuarioId == paraUsuarioId) {
    throw ArgumentError('No puedes enviarte una solicitud a ti mismo.');
  }
}
