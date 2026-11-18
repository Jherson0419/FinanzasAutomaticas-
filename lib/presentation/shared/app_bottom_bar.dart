import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/entities/deuda.dart';
import '../../domain/entities/transaccion.dart';
import '../theme/app_theme.dart';

/// Destinos del [AppBottomBar] (Fase 80). Todos son pantallas, nunca
/// acciones: las acciones (registrar gasto/ingreso/deuda) viven en la hoja
/// del botón "+" central. "Perfil" dejó de estar en la barra: se abre desde
/// el avatar de la cabecera del dashboard.
enum AppBottomTab { inicio, movimientos, deudas, consejos }

/// Ruta de cada destino. Inicio es la primera ruta ('/'), así que no se
/// empuja: se vuelve a ella.
const _rutaDestino = {
  AppBottomTab.movimientos: '/transacciones/todas',
  AppBottomTab.deudas: '/deudas',
  AppBottomTab.consejos: '/consejos',
};

/// Navega a un destino de la barra (Fase 80; pública desde la Fase 81 para
/// los enlaces "Ver todo" del Inicio). Inicio vuelve a la primera ruta;
/// cualquier otro destino reemplaza al destino anterior (nunca se apilan),
/// así "atrás" desde un destino siempre vuelve al Inicio.
void irADestino(BuildContext context, AppBottomTab destino) {
  final navigator = Navigator.of(context);
  if (destino == AppBottomTab.inicio) {
    navigator.popUntil((route) => route.isFirst);
    return;
  }
  navigator.pushNamedAndRemoveUntil(
    _rutaDestino[destino]!,
    (route) => route.isFirst,
  );
}

/// Barra inferior (Fase 17; 5 botones y estilo "glass" en la Fase 32;
/// rediseñada en la Fase 80): Inicio · Movimientos · [+] · Deudas ·
/// Consejos. El "+" queda en el centro exacto, con un círculo elevado que
/// sobresale del borde superior (mismo lenguaje que el antiguo botón
/// "Inicio" de la Fase 32.2) y abre [mostrarHojaAgregar].
///
/// Accesibilidad: cada destino es un botón con `Semantics(selected:)` y su
/// etiqueta; el destino actual se distingue por color, peso de la etiqueta
/// Y un indicador en forma de píldora detrás del ícono (no solo color).
/// Todos los objetivos táctiles miden al menos 48 × 48 dp.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key, this.actual});

  /// Destino que representa la pantalla donde se muestra esta barra;
  /// `null` en pantallas que no son un destino (p. ej. "Mi perfil").
  final AppBottomTab? actual;

  static const double _alturaBarra = 72;
  static const double diametroAgregar = 60;
  static const double _protrusionAgregar = 24;
  static const double _alturaTotal = _alturaBarra + _protrusionAgregar;

  void _irA(BuildContext context, AppBottomTab destino) {
    if (destino == actual) return;
    irADestino(context, destino);
  }

  Widget _destino(
    BuildContext context,
    AppBottomTab destino,
    IconData icono,
    IconData iconoActivo,
    String etiqueta,
  ) {
    return Expanded(
      child: _BotonDestino(
        icono: icono,
        iconoActivo: iconoActivo,
        etiqueta: etiqueta,
        activo: actual == destino,
        onTap: () => _irA(context, destino),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary (Fase 32.4): el `BackdropFilter` de la barra es
    // costoso de re-pintar; aislarlo en su propia capa evita que el scroll
    // del contenido fuerce un repintado de la barra, y viceversa.
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      _destino(
                        context,
                        AppBottomTab.inicio,
                        Icons.home_outlined,
                        Icons.home_rounded,
                        'Inicio',
                      ),
                      _destino(
                        context,
                        AppBottomTab.movimientos,
                        Icons.notes_rounded,
                        Icons.notes_rounded,
                        'Movimientos',
                      ),
                      // Espaciador: el "+" flota encima en el `Positioned`
                      // de más abajo, pero ocupa este ancho en la fila.
                      const SizedBox(width: diametroAgregar + 8),
                      _destino(
                        context,
                        AppBottomTab.deudas,
                        Icons.swap_horiz_rounded,
                        Icons.swap_horiz_rounded,
                        'Deudas',
                      ),
                      _destino(
                        context,
                        AppBottomTab.consejos,
                        Icons.lightbulb_outline,
                        Icons.lightbulb,
                        'Consejos',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: _BotonAgregar(onTap: () => mostrarHojaAgregar(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior del "+" (Fase 80): Gasto, Ingreso y Deuda, cada una a la
/// pantalla que ya existe para eso; "Me deben" desde la Fase 82;
/// "Transferencia" desde la Fase 85.
Future<void> mostrarHojaAgregar(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    // Con texto grande (accesibilidad) o pantallas bajas el contenido puede
    // superar el alto por defecto de la hoja: se deja crecer y desplazar.
    isScrollControlled: true,
    builder: (hojaContext) {
      void abrir(String ruta, {Object? argumentos}) {
        Navigator.of(hojaContext).pop();
        Navigator.of(context).pushNamed(ruta, arguments: argumentos);
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Semantics(
                  header: true,
                  child: Text(
                    '¿Qué quieres registrar?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              _OpcionHoja(
                icono: Icons.arrow_upward,
                color: context.dangerText,
                fondo: context.dangerBg,
                titulo: 'Gasto',
                subtitulo: 'Algo que pagaste',
                onTap: () => abrir(
                  '/transacciones/nueva',
                  argumentos: TipoTransaccion.gasto,
                ),
              ),
              _OpcionHoja(
                icono: Icons.arrow_downward,
                color: context.successText,
                fondo: context.successBg,
                titulo: 'Ingreso',
                subtitulo: 'Dinero que recibiste',
                onTap: () => abrir(
                  '/transacciones/nueva',
                  argumentos: TipoTransaccion.ingreso,
                ),
              ),
              // Fase 85: entre cuentas propias (también pagar la tarjeta);
              // tono neutro: no es ingreso ni gasto.
              _OpcionHoja(
                icono: Icons.swap_horiz,
                color: context.textSecondary,
                fondo: context.borderCard,
                titulo: 'Transferencia',
                subtitulo: 'Entre tus cuentas o para pagar tu tarjeta',
                onTap: () => abrir('/transferencias/nueva'),
              ),
              _OpcionHoja(
                icono: Icons.credit_card,
                color: context.warningText,
                fondo: context.warningBg,
                titulo: 'Deuda',
                subtitulo: 'Un préstamo, cuotas o algo que debes',
                onTap: () =>
                    abrir('/deudas/nueva', argumentos: DireccionDeuda.debo),
              ),
              // Fase 82: un préstamo que hiciste (abre el formulario ya en
              // "Me deben").
              _OpcionHoja(
                icono: Icons.call_received,
                color: context.successText,
                fondo: context.successBg,
                titulo: 'Me deben',
                subtitulo: 'Dinero que le prestaste a alguien',
                onTap: () =>
                    abrir('/deudas/nueva', argumentos: DireccionDeuda.meDeben),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}

class _OpcionHoja extends StatelessWidget {
  const _OpcionHoja({
    required this.icono,
    required this.color,
    required this.fondo,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final Color fondo;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: fondo, shape: BoxShape.circle),
        child: Icon(icono, color: color),
      ),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitulo),
      onTap: onTap,
    );
  }
}

/// Fondo "vidrio esmerilado" de la barra (Fase 32.3): difumina lo que hay
/// detrás con [BackdropFilter] y superpone un tinte semitransparente del
/// token de superficie del tema activo, con un borde superior sutil. El
/// `ClipRect` acota el desenfoque exactamente al área de la barra.
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

class _BotonDestino extends StatelessWidget {
  const _BotonDestino({
    required this.icono,
    required this.iconoActivo,
    required this.etiqueta,
    required this.activo,
    required this.onTap,
  });

  final IconData icono;
  final IconData iconoActivo;
  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // `successText`, no `colorSuccess`: es color de TEXTO (Fase 80, A).
    final color = activo ? context.successText : context.textSecondary;

    return Semantics(
      container: true,
      button: true,
      selected: activo,
      label: etiqueta,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Indicador de selección que no depende solo del color.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: activo ? context.successBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    activo ? iconoActivo : icono,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 2),
                // `scaleDown`: con texto grande (accesibilidad) la etiqueta
                // se achica dentro de su celda en vez de desbordar la barra.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    etiqueta,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: activo ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón "+" central (Fase 80): círculo sólido de marca (`brandAction`)
/// elevado sobre la barra, para leerse como la acción principal. Es una
/// acción, no un destino: nunca se marca como seleccionado.
class _BotonAgregar extends StatelessWidget {
  const _BotonAgregar({required this.onTap});

  final VoidCallback onTap;

  static const double _diametro = AppBottomBar.diametroAgregar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Agregar',
      hint: 'Registrar un gasto, un ingreso o una deuda',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Agregar',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: _diametro,
              height: _diametro,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.brandAction,
                boxShadow: [
                  BoxShadow(
                    color: context.brandAction.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.add_rounded,
                color: colorSobreEstado,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
