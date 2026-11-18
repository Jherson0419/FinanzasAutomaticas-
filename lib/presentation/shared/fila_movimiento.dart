import 'package:flutter/material.dart';

import '../../domain/entities/cuenta.dart';
import '../theme/app_theme.dart';
import 'category_icons.dart';
import 'dashboard_colors.dart';
import 'estilos.dart';
import 'formatters.dart';

/// Fila de un movimiento (Fase 81, 01-inicio.png y 02-movimientos.png):
/// ícono de categoría con fondo tenue, concepto, "Categoría · Cuenta ·
/// Hoy" y monto con signo +/− en color accesible. El signo (y la etiqueta
/// semántica "Ingreso"/"Gasto") comunican el tipo: nunca solo el color.
/// Tocarla abre lo mismo de siempre: la transacción en modo edición.
class FilaMovimiento extends StatelessWidget {
  const FilaMovimiento({
    super.key,
    required this.transaccionId,
    required this.concepto,
    required this.categoriaNombre,
    required this.categoriaIcono,
    required this.monto,
    required this.moneda,
    required this.esIngreso,
    this.cuentaNombre,
    this.fecha,
    this.esAjuste = false,
    this.ahora,
    this.transferenciaId,
    this.tituloTransferencia,
    this.signoTransferencia = 0,
  });

  final String transaccionId;
  final String concepto;
  final String categoriaNombre;
  final String? categoriaIcono;
  final String? cuentaNombre;

  /// Si no es `null`, se agrega "Hoy"/"Ayer"/"14 nov" al subtítulo (en
  /// Movimientos la fecha ya la da el encabezado del día).
  final DateTime? fecha;
  final double monto;
  final Moneda moneda;
  final bool esIngreso;
  final bool esAjuste;
  final DateTime? ahora;

  /// Fase 85 — no `null` si la fila es una transferencia: tono neutro (ni
  /// verde ni rojo), ícono de intercambio, la palabra "Transferencia" en el
  /// título y en la etiqueta accesible, y abre su detalle.
  final String? transferenciaId;

  /// "Transferencia a Visa BCP" / "Transferencia desde Débito".
  final String? tituloTransferencia;

  /// 0 = sin signo (vista de todas las cuentas: no cambia el total); −1/+1
  /// = sale/entra de la cuenta que se está viendo.
  final int signoTransferencia;

  @override
  Widget build(BuildContext context) {
    if (transferenciaId != null) return _construirTransferencia(context);
    final theme = Theme.of(context);
    final titulo = concepto.trim().isEmpty ? categoriaNombre : concepto;
    final subtitulo = [
      categoriaNombre,
      if (cuentaNombre != null && cuentaNombre!.isNotEmpty) cuentaNombre!,
      if (fecha != null) formatearDiaRelativo(fecha!, ahora: ahora),
    ].join(' · ');
    final montoTexto = formatearMontoConSigno(
      monto,
      moneda,
      positivo: esIngreso,
    );
    final (Color colorIcono, Color fondoIcono) = esAjuste
        ? (context.textSecondary, context.borderCard)
        : esIngreso
        ? (context.successText, context.successBg)
        : (context.dangerText, context.dangerBg);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          '${esIngreso ? 'Ingreso' : 'Gasto'}${esAjuste ? ' (ajuste)' : ''}: '
          '$titulo, ${formatearMonto(monto.abs(), moneda)}. $subtitulo.',
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamed('/transacciones/nueva', arguments: transaccionId),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: fondoIcono,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      // Como en las imágenes: ingresos con flecha, gastos con
                      // el ícono de su categoría.
                      esAjuste
                          ? Icons.tune
                          : esIngreso
                          ? Icons.arrow_upward
                          : iconoParaCategoria(categoriaIcono ?? 'category'),
                      color: colorIcono,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Con texto grande (accesibilidad) o montos largos, el monto
                  // se limita a ~55 % de la fila y se reduce antes que
                  // desbordar; el concepto se trunca con elipsis.
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (constraints.maxWidth - 44 - 14 - 12) * 0.55,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        montoTexto,
                        maxLines: 1,
                        style: estiloMonto(
                          theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: esIngreso
                                ? colorIngreso(context)
                                : colorGasto(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension on FilaMovimiento {
  Widget _construirTransferencia(BuildContext context) {
    final theme = Theme.of(context);
    final titulo = tituloTransferencia ?? 'Transferencia';
    final nota = concepto.trim();
    final subtitulo = [
      if (nota.isNotEmpty && nota != 'Transferencia') nota,
      if (cuentaNombre != null && cuentaNombre!.isNotEmpty) cuentaNombre!,
      if (fecha != null) formatearDiaRelativo(fecha!, ahora: ahora),
    ].join(' · ');
    final montoTexto = signoTransferencia == 0
        ? formatearMonto(monto, moneda)
        : formatearMontoConSigno(monto, moneda, positivo: signoTransferencia > 0);
    final neutro = context.textSecondary;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label:
          'Transferencia: $titulo, '
          '${signoTransferencia < 0 ? 'sale ' : signoTransferencia > 0 ? 'entra ' : ''}'
          '${formatearMonto(monto.abs(), moneda)}.'
          '${subtitulo.isEmpty ? '' : ' $subtitulo.'}',
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).pushNamed('/transferencias/detalle', arguments: transferenciaId),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: context.borderCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.swap_horiz, color: neutro, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitulo.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (constraints.maxWidth - 44 - 14 - 12) * 0.55,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        montoTexto,
                        maxLines: 1,
                        style: estiloMonto(
                          theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de tarjeta de sección (Fase 81): título + enlace opcional
/// "Ver todo" con objetivo táctil de al menos 48 dp.
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({
    super.key,
    required this.titulo,
    this.textoAccion,
    this.onAccion,
    this.etiquetaAccion,
  });

  final String titulo;
  final String? textoAccion;
  final VoidCallback? onAccion;

  /// Etiqueta accesible del enlace (p. ej. "Ver todos los movimientos").
  final String? etiquetaAccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              titulo,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        if (textoAccion != null)
          Semantics(
            button: true,
            label: etiquetaAccion ?? textoAccion,
            excludeSemantics: true,
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: context.successText,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: onAccion,
              child: Text(textoAccion!),
            ),
          ),
      ],
    );
  }
}
