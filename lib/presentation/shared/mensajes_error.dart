/// Extrae un mensaje legible de una excepción del dominio, sin el prefijo
/// técnico que agrega `Object.toString()` (p. ej. "Bad state: ...").
String mensajeDeError(Object error) {
  if (error is StateError) return error.message;
  if (error is ArgumentError) {
    final mensaje = error.message;
    if (mensaje != null) return mensaje.toString();
  }
  return error.toString();
}
