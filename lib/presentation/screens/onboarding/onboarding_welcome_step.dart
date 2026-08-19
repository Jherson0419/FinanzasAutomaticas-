import 'package:flutter/material.dart';

/// Paso 0: bienvenida. Sin botón "Atrás" — es el primer paso del wizard.
class OnboardingWelcomeStep extends StatelessWidget {
  const OnboardingWelcomeStep({super.key, required this.onComenzar});

  final VoidCallback onComenzar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.savings_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            'Bienvenido a Finzo: Finanzas Automáticas',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Controla tus ingresos, gastos y deudas en un solo lugar, sin '
            'hojas de cálculo ni anotar todo a mano. Vamos a dejar todo '
            'listo en un par de minutos.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: onComenzar,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text('Comenzar'),
            ),
          ),
        ],
      ),
    );
  }
}
