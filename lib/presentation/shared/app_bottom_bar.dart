import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pestañas del [AppBottomBar] que sí representan "la pantalla actual".
/// Gasto/Deuda son acciones (abren un formulario), no destinos, así que
/// nunca se resaltan (Fase 19.6).
enum AppBottomTab { consejos, perfil }

/// Barra inferior de 4 botones (Fase 17), compartida por [DashboardScreen],
/// `ConsejosFinancierosScreen` y `MiPerfilScreen` para que el botón de la
/// pantalla actual se pueda resaltar en `colorSuccess` con negrita (Fase
/// 19.6). El resto de los botones queda en `textSecondary`.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, this.actual});

  /// Pestaña que representa la pantalla donde se está mostrando esta barra.
  /// `null` cuando se muestra desde el dashboard (que no es "Consejos" ni
  /// "Perfil").
  final AppBottomTab? actual;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _BotonInferior(
            icono: Icons.remove_circle_outline,
            etiqueta: 'Gasto',
            activo: false,
            onTap: () =>
                Navigator.of(context).pushNamed('/transacciones/nueva'),
          ),
          _BotonInferior(
            icono: Icons.credit_card,
            etiqueta: 'Deuda',
            activo: false,
            onTap: () => Navigator.of(context).pushNamed('/deudas/nueva'),
          ),
          _BotonInferior(
            icono: Icons.lightbulb_outline,
            etiqueta: 'Consejos',
            activo: actual == AppBottomTab.consejos,
            onTap: actual == AppBottomTab.consejos
                ? () {}
                : () => Navigator.of(context).pushNamed('/consejos'),
          ),
          _BotonInferior(
            icono: Icons.person_outline,
            etiqueta: 'Perfil',
            activo: actual == AppBottomTab.perfil,
            onTap: actual == AppBottomTab.perfil
                ? () {}
                : () => Navigator.of(context).pushNamed('/perfil'),
          ),
        ],
      ),
    );
  }
}

class _BotonInferior extends StatelessWidget {
  const _BotonInferior({
    required this.icono,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = activo ? colorSuccess : textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: activo ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
