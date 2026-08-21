import 'package:flutter/material.dart';

import 'avatares.dart';

/// Círculo de avatar — usado en "Mi perfil" (tamaño grande, tocable).
///
/// Fase 56: reemplaza la selección de un ícono prediseñado por una foto
/// real subida a Supabase Storage. [avatarId] ahora casi siempre es una URL
/// (`http...`); si lo es, se carga con `Image.network` recortada a círculo.
/// Los usuarios que todavía tengan un id de ícono prediseñado guardado de
/// antes de esta fase (`avataresDisponibles`, Fase 31) siguen viendo su
/// ícono de siempre — `avatarPorId` seguía existiendo justo para este
/// respaldo — hasta que cambien de foto por primera vez.
class AvatarCirculo extends StatelessWidget {
  const AvatarCirculo({super.key, required this.avatarId, this.tamano = 40});

  final String? avatarId;
  final double tamano;

  bool get _esFoto => avatarId != null && avatarId!.startsWith('http');

  @override
  Widget build(BuildContext context) {
    if (!_esFoto) return _iconoRespaldo();

    return ClipOval(
      child: Image.network(
        avatarId!,
        width: tamano,
        height: tamano,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _iconoRespaldo(),
        loadingBuilder: (context, child, progreso) {
          if (progreso == null) return child;
          return _placeholderCargando(context);
        },
      ),
    );
  }

  Widget _iconoRespaldo() {
    final avatar = avatarPorId(avatarId);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(shape: BoxShape.circle, color: avatar.color),
      child: Icon(avatar.icono, color: Colors.white, size: tamano * 0.5),
    );
  }

  Widget _placeholderCargando(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Center(
        child: SizedBox(
          width: tamano * 0.35,
          height: tamano * 0.35,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
