import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../cuenta_formulario.dart';
import '../dashboard/widgets/wallet_account_card.dart';

/// Paso 2: al menos una cuenta. "Continuar" deshabilitado hasta que
/// `cuentasProvider` tenga al menos un elemento.
class OnboardingCuentasStep extends ConsumerWidget {
  const OnboardingCuentasStep({
    super.key,
    required this.onAtras,
    required this.onContinuar,
  });

  final VoidCallback onAtras;
  final VoidCallback onContinuar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cuentasAsync = ref.watch(cuentasProvider);
    final hayCuentas = cuentasAsync.valueOrNull?.isNotEmpty ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tus cuentas',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega al menos una cuenta o billetera para empezar a '
            'registrar tus movimientos.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          cuentasAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) =>
                const Text('No se pudieron cargar las cuentas.'),
            data: (cuentas) => cuentas.isEmpty
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      for (final cuenta in cuentas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: WalletAccountCard(
                            cuenta: cuenta,
                            compacto: true,
                          ),
                        ),
                    ],
                  ),
          ),
          if (hayCuentas) const Divider(height: 32),
          Text('Agregar cuenta', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          CuentaFormulario(onGuardadoExitoso: () {}),
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
                  onPressed: hayCuentas ? onContinuar : null,
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
