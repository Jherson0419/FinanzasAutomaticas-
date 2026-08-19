import 'package:flutter/material.dart';

import 'avatares.dart';

/// Círculo de avatar (ícono sobre color sólido) — usado tanto en "Mi
/// perfil" (tamaño grande, tocable) como dentro del grid selector.
class AvatarCirculo extends StatelessWidget {
  const AvatarCirculo({
    super.key,
    required this.avatar,
    this.tamano = 40,
    this.destacado = false,
  });

  final AvatarOption avatar;
  final double tamano;

  /// Borde blanco translúcido más grueso — usado para marcar la selección
  /// actual dentro del grid (mismo espíritu que `_IconoChip` en
  /// `categoria_formulario.dart`, Fase 20).
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatar.color,
        border: destacado ? Border.all(color: Colors.white, width: 2.5) : null,
      ),
      child: Icon(avatar.icono, color: Colors.white, size: tamano * 0.5),
    );
  }
}

/// Grid seleccionable de avatares — mismo patrón que el selector de íconos
/// de categorías (Fase 20, `_SelectorIcono`/`_IconoChip` en
/// `categoria_formulario.dart`).
class SelectorAvatarGrid extends StatelessWidget {
  const SelectorAvatarGrid({
    super.key,
    required this.seleccionado,
    required this.onSeleccionar,
  });

  final String? seleccionado;
  final ValueChanged<String> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final avatar in avataresDisponibles)
          InkWell(
            onTap: () => onSeleccionar(avatar.id),
            borderRadius: BorderRadius.circular(32),
            child: AvatarCirculo(
              avatar: avatar,
              tamano: 56,
              destacado: avatar.id == seleccionado,
            ),
          ),
      ],
    );
  }
}

/// Abre el selector de avatar como un bottom sheet — devuelve el `id`
/// elegido, o `null` si el usuario lo cerró sin elegir nada.
Future<String?> abrirSelectorAvatar(
  BuildContext context, {
  required String? avatarActual,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Elige tu avatar',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SelectorAvatarGrid(
              seleccionado: avatarActual,
              onSeleccionar: (id) => Navigator.of(context).pop(id),
            ),
          ],
        ),
      );
    },
  );
}
