import 'package:flutter/material.dart';

class AccesosRapidosSection extends StatelessWidget {
  const AccesosRapidosSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () =>
                Navigator.of(context).pushNamed('/transacciones/nueva'),
            icon: const Icon(Icons.add),
            label: const Text('Gasto/ingreso'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/deudas/nueva'),
            icon: const Icon(Icons.credit_card),
            label: const Text('Nueva deuda'),
          ),
        ),
      ],
    );
  }
}
