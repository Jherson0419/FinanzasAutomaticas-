import 'package:flutter/material.dart';

import '../theme/app_theme.dart' show AppColorTokensContext;

/// Tarjeta de contenido estándar (Fase 19.2): fondo `bgCard`, borde
/// `borderCard` de 0.5px, `borderRadius` de 14. Reemplaza el
/// `Card(elevation: 0, color: colorScheme.surfaceContainerHigh, shape: ...)`
/// que se repetía en cada sección del dashboard y varias pantallas de
/// detalle/formulario.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderCard, width: 0.5),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
