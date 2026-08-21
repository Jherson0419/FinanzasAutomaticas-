import 'package:flutter/material.dart';

/// Un avatar prediseñado (Fase 31) — ícono simple sobre un círculo de color
/// sólido. Fase 56: dejó de ser la forma principal de elegir avatar (ahora
/// es una foto real, ver `AvatarCirculo` en `selector_avatar.dart`); este
/// catálogo se conserva solo como respaldo visual para cuentas que todavía
/// tengan guardado un id de este catálogo en `usuarios.avatar_id` en vez de
/// una URL de foto.
class AvatarOption {
  final String id;
  final IconData icono;
  final Color color;

  const AvatarOption({
    required this.id,
    required this.icono,
    required this.color,
  });
}

const List<AvatarOption> avataresDisponibles = [
  AvatarOption(id: 'zorro', icono: Icons.pets, color: Color(0xFFC26440)),
  AvatarOption(
    id: 'cohete',
    icono: Icons.rocket_launch,
    color: Color(0xFF2F5FA6),
  ),
  AvatarOption(id: 'estrella', icono: Icons.star, color: Color(0xFFC98A2C)),
  AvatarOption(id: 'rayo', icono: Icons.bolt, color: Color(0xFF5DCAA5)),
  AvatarOption(id: 'diamante', icono: Icons.diamond, color: Color(0xFF5B3690)),
  AvatarOption(id: 'planta', icono: Icons.eco, color: Color(0xFF1E7B6C)),
  AvatarOption(id: 'corazon', icono: Icons.favorite, color: Color(0xFFD9707D)),
  AvatarOption(
    id: 'balon',
    icono: Icons.sports_soccer,
    color: Color(0xFF3A6EA5),
  ),
  AvatarOption(
    id: 'trofeo',
    icono: Icons.emoji_events,
    color: Color(0xFFB08B2E),
  ),
  AvatarOption(id: 'ancla', icono: Icons.anchor, color: Color(0xFF34495E)),
  AvatarOption(
    id: 'flor',
    icono: Icons.local_florist,
    color: Color(0xFFAD5A8A),
  ),
  AvatarOption(id: 'alcancia', icono: Icons.savings, color: Color(0xFF7A6248)),
];

/// El primero del catálogo — usado como valor por defecto antes de que el
/// usuario elija uno en el onboarding o en "Mi perfil".
AvatarOption get avatarPorDefecto => avataresDisponibles.first;

AvatarOption avatarPorId(String? id) {
  if (id == null) return avatarPorDefecto;
  for (final avatar in avataresDisponibles) {
    if (avatar.id == id) return avatar;
  }
  return avatarPorDefecto;
}
