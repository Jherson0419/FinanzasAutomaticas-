import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Encabezado de sección con ícono + etiqueta en mayúsculas (Fase 19.3):
/// ícono pequeño (14-16px, `textSecondary` por defecto o un color
/// semántico como `colorSuccess`/`colorDanger`) junto a un texto que usa
/// [sectionLabelTextStyle].
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String label;

  /// `null` usa `context.textSecondary` (Fase 31: ya no puede ser un valor
  /// por defecto constante porque depende del tema activo).
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor ?? context.textSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: sectionLabelTextStyle.copyWith(color: context.textMuted),
        ),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
