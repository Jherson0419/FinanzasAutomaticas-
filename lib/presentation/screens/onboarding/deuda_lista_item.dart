import 'package:flutter/material.dart';

import '../../../domain/entities/deuda.dart';
import '../../shared/enum_labels.dart';
import '../../shared/formatters.dart';

/// Fila compacta para mostrar una deuda ya agregada, usada tanto en el paso
/// de deudas como en el resumen final del onboarding.
class DeudaListaItem extends StatelessWidget {
  const DeudaListaItem({super.key, required this.deuda});

  final Deuda deuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt_long_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deuda.nombreDeuda,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  labelTipoDeuda(deuda.tipoDeuda),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatearMonto(deuda.montoTotal, deuda.moneda),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
