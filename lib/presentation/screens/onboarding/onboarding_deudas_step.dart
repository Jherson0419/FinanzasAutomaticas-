import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../deuda_formulario.dart';
import 'deuda_lista_item.dart';

/// Paso 3: deudas, opcional. Tanto "Omitir por ahora" como "Continuar"
/// avanzan al resumen — con o sin deudas agregadas.
class OnboardingDeudasStep extends ConsumerWidget {
  const OnboardingDeudasStep({
    super.key,
    required this.onAtras,
    required this.onContinuar,
  });

  final VoidCallback onAtras;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deudasAsync = ref.watch(deudasProvider);
    final hayDeudas = deudasAsync.valueOrNull?.isNotEmpty ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Tienes deudas activas?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Este paso es opcional — puedes agregarlas ahora o más tarde '
            'desde el dashboard.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          deudasAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                const Text('No se pudieron cargar las deudas.'),
            data: (deudas) => deudas.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final deuda in deudas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DeudaListaItem(deuda: deuda),
                        ),
                    ],
                  ),
          ),
          if (hayDeudas) const Divider(height: 32),
          Text('Agregar deuda', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          DeudaFormulario(onGuardadoExitoso: () {}),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onAtras,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onContinuar,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: onContinuar,
              child: const Text('Omitir por ahora'),
            ),
          ),
        ],
      ),
    );
  }
}
