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
    this.iconColor = textSecondary,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 6),
        Text(label.toUpperCase(), style: sectionLabelTextStyle),
        if (trailing != null) ...[const Spacer(), trailing!],
      ],
    );
  }
}
