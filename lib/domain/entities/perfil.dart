/// Datos de perfil social del usuario (Fase 31) — viven en `public.usuarios`
/// (Supabase), no en `PreferenciasRepository` local: a diferencia del
/// nombre o el tema, tienen sentido en la nube (por ejemplo, para que un
/// futuro sistema social pueda buscar a alguien por su `nick`).
class Perfil {
  final String? nick;
  final String? avatarId;
  final String? instagram;

  const Perfil({this.nick, this.avatarId, this.instagram});
}
