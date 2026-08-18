import 'package:flutter/material.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../shared/app_card.dart';
import '../../../shared/dashboard_colors.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';

class IngresosGastosSection extends StatelessWidget {
  final Map<Moneda, double> ingresosMesPorMoneda;
  final Map<Moneda, double> gastosMesPorMoneda;

  const IngresosGastosSection({
    super.key,
    required this.ingresosMesPorMoneda,
    required this.gastosMesPorMoneda,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MontoMesCard(
            icono: Icons.arrow_downward,
            titulo: 'Ingresos (mes)',
            montos: ingresosMesPorMoneda,
            color: colorIngreso(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MontoMesCard(
            icono: Icons.arrow_upward,
            titulo: 'Gastos (mes)',
            montos: gastosMesPorMoneda,
            color: colorGasto(context),
          ),
        ),
      ],
    );
  }
}

class _MontoMesCard extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Map<Moneda, double> montos;
  final Color color;

  const _MontoMesCard({
    required this.icono,
    required this.titulo,
    required this.montos,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(icon: icono, label: titulo, iconColor: color),
          const SizedBox(height: 8),
          if (montos.isEmpty)
            Text(
              formatearMonto(0, Moneda.pen),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            )
          else
            for (final entry in montos.entries)
              Text(
                formatearMonto(entry.value, entry.key),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
        ],
      ),
    );
  }
}
