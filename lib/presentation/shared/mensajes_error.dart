/// Extrae un mensaje legible de una excepción del dominio, sin el prefijo
/// técnico que agrega `Object.toString()` (p. ej. "Bad state: ...").
String mensajeDeError(Object error) {
  if (error is StateError) return error.message;
  if (error is ArgumentError) {
    final mensaje = error.message;
    if (mensaje != null) return mensaje.toString();
  }
  // Modo local (Fase 78): los adaptadores lanzan `UnsupportedError` ante
  // operaciones que requieren la nube — sin "Unsupported operation: ".
  if (error is UnsupportedError) {
    final mensaje = error.message;
    if (mensaje != null) return mensaje;
  }
  return error.toString();
}

/// Aviso común en la UI para lo que se oculta/deshabilita en modo local.
const textoDisponibleConLaNube = 'Disponible con la nube';
