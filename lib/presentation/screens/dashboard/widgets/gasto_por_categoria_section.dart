import 'package:flutter/material.dart';

import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_card.dart';
import '../../../shared/category_icons.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';

class GastoPorCategoriaSection extends StatelessWidget {
  final List<GastoPorCategoria> gastoPorCategoriaMes;

  const GastoPorCategoriaSection({
    super.key,
    required this.gastoPorCategoriaMes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            icon: Icons.pie_chart_outline,
            label: 'Gasto por categoría',
          ),
          const SizedBox(height: 16),
          if (gastoPorCategoriaMes.isEmpty)
            Text(
              'Aún no tienes gastos registrados este mes.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final categoria in gastoPorCategoriaMes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          iconoParaCategoria(categoria.iconName),
                          size: 20,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            categoria.nombre,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          formatearMonto(categoria.monto, categoria.moneda),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: categoria.porcentajeDelTotal
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        minHeight: 6,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
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
