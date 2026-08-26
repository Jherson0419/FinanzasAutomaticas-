/// Extrae el nick de un deep link `finzo://agregar-amigo?nick=<nick>`
/// (Fase 64, compartir perfil desde "Mi perfil") — `null` si el link no es
/// de este tipo o no trae un nick no vacío. Función pura (sin `app_links`
/// ni un `Navigator` real) para poder probarla de forma aislada; quien la
/// llama (`app.dart`) es el único lugar que sí toca el listener real.
String? parsearNickDesdeLinkAgregarAmigo(Uri uri) {
  if (uri.host != 'agregar-amigo') return null;
  final nick = uri.queryParameters['nick']?.trim();
  if (nick == null || nick.isEmpty) return null;
  return nick;
}
