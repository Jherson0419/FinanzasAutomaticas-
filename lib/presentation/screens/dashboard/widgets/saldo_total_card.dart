import 'package:flutter/material.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../shared/app_card.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';

class SaldoTotalCard extends StatelessWidget {
  final Map<Moneda, double> saldoTotalPorMoneda;

  const SaldoTotalCard({super.key, required this.saldoTotalPorMoneda});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Saldo total',
          ),
          const SizedBox(height: 8),
          if (saldoTotalPorMoneda.isEmpty)
            Text(
              formatearMonto(0, Moneda.pen),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            )
          else
            for (final entry in saldoTotalPorMoneda.entries)
              Text(
                formatearMonto(entry.value, entry.key),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
        ],
      ),
    );
  }
}
