/// Datos de perfil social del usuario (Fase 31, ampliado en la Fase 56) —
/// viven en `public.usuarios` (Supabase), no en `PreferenciasRepository`
/// local: a diferencia del nombre corto o el tema, tienen sentido en la
/// nube (por ejemplo, para que un futuro sistema social pueda buscar a
/// alguien por su `nick`).
class Perfil {
  final String? nick;

  /// Fase 31: id de un ícono prediseñado (`avataresDisponibles`). Fase 56:
  /// pasó a ser la URL pública de una foto subida a Supabase Storage
  /// (bucket `avatares`) — mismo campo/columna, significado nuevo; ver
  /// `CONTEXTO.md` para el detalle de la migración de significado.
  final String? avatarId;
  final String? instagram;

  /// Fase 56 — nombre completo, distinto del nombre corto local
  /// (`PreferenciasRepository`, usado en el saludo del dashboard): este
  /// vive en Supabase, pensado para un futuro uso más formal/identificable
  /// (no reemplaza al nombre corto, coexisten).
  final String? nombreCompleto;
  final String? celular;

  /// Red social adicional además de Instagram — un solo campo genérico de
  /// texto libre (Fase 56, "mantenlo simple": no una lista abierta de
  /// redes, el usuario escribe lo que quiera ahí, p. ej. un usuario de
  /// TikTok o X con su propio prefijo).
  final String? otraRedSocial;

  const Perfil({
    this.nick,
    this.avatarId,
    this.instagram,
    this.nombreCompleto,
    this.celular,
    this.otraRedSocial,
  });
}
