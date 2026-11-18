import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Selector de 2+ opciones excluyentes con forma de "píldora" (Fase 82,
/// 04-deudas.png y 05-deuda-nueva.png): Debo / Me deben, Yo debo / Me
/// deben. Cada opción es un botón con `Semantics(selected:)` dentro de un
/// grupo mutuamente excluyente, y mide al menos 48 dp de alto. La opción
/// elegida se distingue por fondo, sombra Y negrita (no solo color).
/// Con [onCambio] `null` queda deshabilitado (p. ej. al editar una deuda).
class SelectorSegmentado<T> extends StatelessWidget {
  const SelectorSegmentado({
    super.key,
    required this.opciones,
    required this.seleccionado,
    required this.onCambio,
    this.etiquetaGrupo,
  });

  final List<(T, String)> opciones;
  final T seleccionado;
  final ValueChanged<T>? onCambio;

  /// Nombre del grupo para lectores de pantalla (p. ej. "Dirección").
  final String? etiquetaGrupo;

  @override
  Widget build(BuildContext context) {
    final habilitado = onCambio != null;
    return Semantics(
      container: true,
      label: etiquetaGrupo,
      child: Opacity(
        opacity: habilitado ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.borderCard,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              for (final (valor, texto) in opciones)
                Expanded(
                  child: _Opcion(
                    texto: texto,
                    activa: valor == seleccionado,
                    onTap: habilitado ? () => onCambio!(valor) : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({required this.texto, required this.activa, this.onTap});

  final String texto;
  final bool activa;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      inMutuallyExclusiveGroup: true,
      enabled: onTap != null,
      label: texto,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: activa ? context.bgCard : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: activa
                ? [
                    BoxShadow(
                      color: context.textPrimary.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: activa ? context.textPrimary : context.textSecondary,
              fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
