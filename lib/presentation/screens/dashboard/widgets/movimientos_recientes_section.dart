import 'package:flutter/material.dart';

import '../../../../domain/entities/transaccion.dart';
import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_card.dart';
import '../../../shared/category_icons.dart';
import '../../../shared/dashboard_colors.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';

class MovimientosRecientesSection extends StatefulWidget {
  final List<MovimientoReciente> movimientosRecientes;

  const MovimientosRecientesSection({
    super.key,
    required this.movimientosRecientes,
  });

  @override
  State<MovimientosRecientesSection> createState() =>
      _MovimientosRecientesSectionState();
}

class _MovimientosRecientesSectionState
    extends State<MovimientosRecientesSection> {
  bool _expandido = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Row(
              children: [
                const SectionLabel(
                  icon: Icons.receipt_long_outlined,
                  label: 'Movimientos recientes',
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expandido ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_expandido
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      if (widget.movimientosRecientes.isEmpty)
                        Text(
                          'Aún no tienes transacciones registradas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else ...[
                        for (final movimiento in widget.movimientosRecientes)
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed(
                              '/transacciones/nueva',
                              arguments: movimiento.id,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    foregroundColor:
                                        colorScheme.onSurfaceVariant,
                                    child: Icon(
                                      movimiento.fuenteCaptura ==
                                              FuenteCaptura.ajuste
                                          ? Icons.tune
                                          : iconoParaCategoria(
                                              movimiento.categoriaIconName,
                                            ),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                movimiento.concepto,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                            ),
                                            if (movimiento.fuenteCaptura ==
                                                FuenteCaptura.ajuste) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .secondaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Ajuste',
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSecondaryContainer,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        Text(
                                          formatearFecha(movimiento.fecha),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${movimiento.tipo == TipoTransaccion.ingreso ? '+' : '-'} ${formatearMonto(movimiento.monto, movimiento.moneda)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color:
                                          movimiento.tipo ==
                                              TipoTransaccion.ingreso
                                          ? colorIngreso(context)
                                          : colorGasto(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(
                              context,
                            ).pushNamed('/transacciones/todas'),
                            child: const Text('Ver todos'),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
