import '../entities/perfil.dart';

/// Puerto para los datos de perfil social del usuario (`nick`, `avatarId`,
/// `instagram`, Fase 31; `nombreCompleto`/`celular`/`otraRedSocial`, Fase
/// 56) — viven en `public.usuarios` (Supabase), nunca en
/// `PreferenciasRepository` local. Deliberadamente no bifurca Drift/Supabase
/// (mismo criterio que `AutomatizacionRepository`, Fase 25): estos campos
/// solo existen una vez que hay una cuenta en la nube.
abstract class PerfilRepository {
  Future<Perfil> obtenerPerfil();

  /// `true` si [nick] todavía no lo tiene nadie. No lanza si [nick] es el
  /// nick actual del propio usuario — quien llama decide si eso importa.
  Future<bool> nickDisponible(String nick);

  /// Falla si [nick] ya está en uso (constraint `UNIQUE` en la base de
  /// datos) — validar con [nickDisponible] antes es una optimización de UX
  /// (feedback en vivo), no una garantía; la base de datos es la fuente de
  /// verdad final contra condiciones de carrera.
  Future<void> guardarNick(String nick);

  /// Fase 56: [avatarId] es la URL pública de la foto ya subida a Supabase
  /// Storage (ver `subirFotoAvatar`) — este método solo persiste esa URL en
  /// `usuarios.avatar_id`, no toca el archivo.
  Future<void> guardarAvatarId(String avatarId);

  /// Sube [bytes] al bucket `avatares` de Supabase Storage, en una carpeta
  /// por `user_id` (evita colisiones entre usuarios y hace trivial borrar
  /// las fotos de alguien si borra su cuenta). Devuelve la URL pública ya
  /// lista para guardar con [guardarAvatarId] — separado de ese método
  /// porque subir el archivo y persistir la URL son pasos independientes
  /// (permite, por ejemplo, reintentar solo el que falle).
  Future<String> subirFotoAvatar(List<int> bytes, {required String extension});

  Future<void> guardarInstagram(String? instagram);

  Future<void> guardarNombreCompleto(String? nombreCompleto);

  Future<void> guardarCelular(String? celular);

  Future<void> guardarOtraRedSocial(String? otraRedSocial);
}
