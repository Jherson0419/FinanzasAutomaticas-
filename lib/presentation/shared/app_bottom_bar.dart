import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Pestañas del [AppBottomBar] que sí representan "la pantalla actual".
/// Gasto/Deuda son acciones (abren un formulario), no destinos, así que
/// nunca se resaltan (Fase 19.6). `dashboard` se agrega en la Fase 32 para
/// resaltar el botón "Inicio" cuando la barra se muestra desde el dashboard.
enum AppBottomTab { dashboard, consejos, perfil }

/// Barra inferior de 5 botones (Fase 17, ampliada a 5 con "Inicio" y estilo
/// "glass" en la Fase 32), compartida por [DashboardScreen],
/// `ConsejosFinancieroScreen` y `MiPerfilScreen` para que el botón de la
/// pantalla actual se pueda resaltar (Fase 19.6). Orden: Gasto · Deuda ·
/// Inicio · Consejos · Perfil — "Inicio" queda en el centro exacto, con un
/// círculo elevado que sobresale del borde superior de la barra (Fase 32.2),
/// mientras el resto conserva el estilo plano de siempre.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, this.actual});

  /// Pestaña que representa la pantalla donde se está mostrando esta barra.
  final AppBottomTab? actual;

  static const double _alturaBarra = 72;
  static const double _diametroInicio = 60;
  static const double _protrusionInicio = 24;
  static const double _alturaTotal = _alturaBarra + _protrusionInicio;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary (Fase 32.4): el `BackdropFilter` de la barra es
    // costoso de re-pintar; aislarlo en su propia capa evita que el scroll
    // del contenido del dashboard (que vive en un `Widget` completamente
    // distinto, fuera de este árbol) fuerce un repintado de la barra, y
    // viceversa.
    return RepaintBoundary(
      child: SizedBox(
        height: _alturaTotal,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BarraVidrio(
                height: _alturaBarra,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _BotonInferior(
                      icono: Icons.remove_circle_outline,
                      etiqueta: 'Gasto',
                      activo: false,
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/transacciones/nueva'),
                    ),
                    _BotonInferior(
                      icono: Icons.credit_card,
                      etiqueta: 'Deuda',
                      activo: false,
                      onTap: () =>
                          Navigator.of(context).pushNamed('/deudas/nueva'),
                    ),
                    // Espaciador: el botón "Inicio" flota encima en el
                    // `Positioned` de más abajo, pero ocupa este ancho en
                    // la fila para quedar centrado entre Deuda y Consejos.
                    const SizedBox(width: _diametroInicio),
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
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _BotonInicio(
                  activo: actual == AppBottomTab.dashboard,
                  onTap: actual == AppBottomTab.dashboard
                      ? () {}
                      // Dashboard/Consejos/Perfil son las únicas pantallas
                      // con esta barra, y siempre están apiladas sobre la
                      // primera ruta ('/', el dashboard) — `popUntil` a la
                      // primera ruta vuelve a esa instancia ya existente en
                      // vez de apilar una nueva, sin importar cuántos
                      // niveles de profundidad haya (p. ej. Consejos abierto
                      // desde Perfil).
                      : () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fondo "vidrio esmerilado" de la barra (Fase 32.3): difumina lo que hay
/// detrás con [BackdropFilter] y superpone un tinte semitransparente del
/// token de superficie del tema activo, con un borde superior sutil. El
/// `ClipRect` acota el desenfoque exactamente al área de la barra — sin él,
/// `BackdropFilter` puede filtrar más allá de sus límites visuales.
class _BarraVidrio extends StatelessWidget {
  const _BarraVidrio({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: context.bgCard.withValues(alpha: 0.75),
            border: Border(
              top: BorderSide(
                color: context.borderCard.withValues(alpha: 0.6),
                width: 1,
              ),
            ),
          ),
          child: child,
        ),
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
    final color = activo ? colorSuccess : context.textSecondary;

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

/// Botón "Inicio" (Fase 32.1/32.2): a propósito rompe el patrón plano de los
/// otros 4 — círculo sólido en `colorSuccess` (nunca gris, ni siquiera
/// inactivo) con sombra, para leerse como un FAB integrado en la barra en
/// vez de un ícono más de la fila. Cuando está activo (en el dashboard) se
/// refuerza con un anillo y una sombra más marcada, mismo lenguaje de
/// "resaltado" que `_BotonInferior` usa con `colorSuccess` + negrita.
class _BotonInicio extends StatelessWidget {
  const _BotonInicio({required this.activo, required this.onTap});

  final bool activo;
  final VoidCallback onTap;

  static const double _diametro = AppBottomBar._diametroInicio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Inicio',
      selected: activo,
      button: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: _diametro,
            height: _diametro,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorSuccess,
              border: activo
                  ? Border.all(
                      color: colorSuccess.withValues(alpha: 0.35),
                      width: 3,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: colorSuccess.withValues(alpha: activo ? 0.45 : 0.3),
                  blurRadius: activo ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.home_rounded,
              color: colorSobreEstado,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
