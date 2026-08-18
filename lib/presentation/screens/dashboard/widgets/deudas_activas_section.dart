import 'package:flutter/material.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../../domain/entities/deuda.dart';
import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_card.dart';
import '../../../shared/dashboard_colors.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';
import '../../../theme/app_theme.dart';

class DeudasActivasSection extends StatefulWidget {
  final List<DeudaActivaResumen> deudasActivas;
  final int deudasEnMoraCount;
  final int deudasPorVencerEstaSemanaCount;
  final Map<Moneda, double> totalAdeudadoPorMoneda;

  const DeudasActivasSection({
    super.key,
    required this.deudasActivas,
    required this.deudasEnMoraCount,
    required this.deudasPorVencerEstaSemanaCount,
    required this.totalAdeudadoPorMoneda,
  });

  @override
  State<DeudasActivasSection> createState() => _DeudasActivasSectionState();
}

class _DeudasActivasSectionState extends State<DeudasActivasSection> {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SectionLabel(
                        icon: Icons.credit_card,
                        label: 'Deudas activas',
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
                if (widget.totalAdeudadoPorMoneda.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in widget.totalAdeudadoPorMoneda.entries)
                        Text(
                          formatearMonto(entry.value, entry.key),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
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
                      if (widget.deudasEnMoraCount > 0) ...[
                        const SizedBox(height: 12),
                        _Banner(
                          color: colorGasto(context),
                          texto: widget.deudasEnMoraCount == 1
                              ? 'Tienes 1 deuda en mora'
                              : 'Tienes ${widget.deudasEnMoraCount} deudas en mora',
                        ),
                      ],
                      if (widget.deudasPorVencerEstaSemanaCount > 0) ...[
                        const SizedBox(height: 12),
                        _Banner(
                          color: colorWarning,
                          texto: widget.deudasPorVencerEstaSemanaCount == 1
                              ? 'Tienes 1 deuda que vence esta semana'
                              : 'Tienes ${widget.deudasPorVencerEstaSemanaCount} deudas que vencen esta semana',
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (widget.deudasActivas.isEmpty)
                        Text(
                          'No tienes deudas activas registradas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (final deuda in widget.deudasActivas)
                          InkWell(
                            onTap: () => Navigator.of(
                              context,
                            ).pushNamed('/deudas/detalle', arguments: deuda.id),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          deuda.nombreDeuda,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Registrar pago',
                                        icon: Icon(
                                          Icons.payments_outlined,
                                          color: colorScheme.primary,
                                          size: 20,
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pushNamed(
                                              '/deudas/pago',
                                              arguments: deuda.id,
                                            ),
                                      ),
                                      if (deuda.enMora)
                                        Text(
                                          'En mora',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorGasto(context),
                                                fontWeight: FontWeight.w600,
                                              ),
                                        )
                                      else if (deuda.estructuraPago ==
                                          EstructuraPago.cuotasFijas)
                                        Text(
                                          deuda.proximaFechaPago != null
                                              ? formatearFecha(
                                                  deuda.proximaFechaPago!,
                                                )
                                              : '—',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        )
                                      else
                                        Text(
                                          'Sin cuota fija',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: deuda.progreso,
                                      minHeight: 6,
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    deuda.montoCuota != null
                                        ? 'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)} · Cuota ${formatearMonto(deuda.montoCuota!, deuda.moneda)}'
                                        : 'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final String texto;

  const _Banner({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
