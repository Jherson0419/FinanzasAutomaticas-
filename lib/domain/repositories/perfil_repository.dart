import '../entities/perfil.dart';

/// Puerto para los datos de perfil social del usuario (`nick`, `avatarId`,
/// `instagram`, Fase 31) — viven en `public.usuarios` (Supabase), nunca en
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

  Future<void> guardarAvatarId(String avatarId);

  Future<void> guardarInstagram(String? instagram);
}
