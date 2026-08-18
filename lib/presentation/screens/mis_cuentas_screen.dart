import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'dashboard/widgets/wallet_account_card.dart';

class MisCuentasScreen extends ConsumerWidget {
  const MisCuentasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis cuentas')),
      body: SafeArea(
        child: cuentasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('No se pudieron cargar las cuentas.\n$error')),
          data: (cuentas) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (cuentas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Aún no tienes cuentas registradas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final cuenta in cuentas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/cuentas/nueva', arguments: cuenta.id),
                      child: Center(child: WalletAccountCard(cuenta: cuenta)),
                    ),
                  ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed('/cuentas/nueva'),
                icon: const Icon(Icons.add),
                label: const Text('Agregar cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
