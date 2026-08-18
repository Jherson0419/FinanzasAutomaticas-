import 'package:flutter/material.dart';

/// Paso 1: nombre del usuario. "Continuar" deshabilitado si está vacío.
class OnboardingNombreStep extends StatefulWidget {
  const OnboardingNombreStep({
    super.key,
    required this.controller,
    required this.onAtras,
    required this.onContinuar,
  });

  final TextEditingController controller;
  final VoidCallback onAtras;
  final VoidCallback onContinuar;

  @override
  State<OnboardingNombreStep> createState() => _OnboardingNombreStepState();
}

class _OnboardingNombreStepState extends State<OnboardingNombreStep> {
  bool get _esValido => widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Cómo te llamas?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lo usamos para saludarte en el dashboard.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.controller,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onAtras,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _esValido ? widget.onContinuar : null,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
