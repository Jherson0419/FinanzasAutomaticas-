import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'selector_avatar.dart';

/// Iniciales para el avatar (Fase 80): primera letra de las dos primeras
/// palabras del nombre, en mayúsculas. `null` si no hay nombre.
String? inicialesDe(String? nombre) {
  // Primera LETRA de cada palabra (Fase 81: ignora signos, p. ej.
  // "Luis (primo)" → "LP").
  final letra = RegExp(r'\p{L}', unicode: true);
  final iniciales = (nombre ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .map((p) => letra.firstMatch(p)?.group(0))
      .whereType<String>()
      .take(2)
      .toList();
  if (iniciales.isEmpty) return null;
  return iniciales.map((l) => l.toUpperCase()).join();
}

/// Avatar de 44 × 44 de la cabecera del dashboard que abre "Mi perfil"
/// (Fase 80 — Perfil salió de la barra inferior). Muestra el avatar
/// prediseñado/foto si el perfil tiene uno; si no, las iniciales del
/// nombre; si tampoco hay nombre, un ícono de persona. Si el perfil no
/// carga (sin red), igual se muestra con iniciales y sigue funcionando.
class AvatarPerfilBoton extends ConsumerWidget {
  const AvatarPerfilBoton({super.key});

  static const double tamano = 44;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatarId = ref.watch(perfilProvider).valueOrNull?.avatarId;
    final iniciales = inicialesDe(ref.watch(nombreUsuarioProvider).valueOrNull);

    final Widget contenido;
    if (avatarId != null && avatarId.isNotEmpty) {
      contenido = AvatarCirculo(avatarId: avatarId, tamano: tamano);
    } else {
      contenido = Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.successBg,
          border: Border.all(color: context.borderCard),
        ),
        child: iniciales == null
            ? Icon(Icons.person_outline, color: context.successText)
            : Text(
                iniciales,
                style: TextStyle(
                  color: context.successText,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
                textScaler: TextScaler.noScaling,
              ),
      );
    }

    return Semantics(
      button: true,
      label: 'Mi perfil',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Mi perfil',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(context).pushNamed('/perfil'),
          child: SizedBox(
            width: tamano,
            height: tamano,
            child: ClipOval(child: contenido),
          ),
        ),
      ),
    );
  }
}
