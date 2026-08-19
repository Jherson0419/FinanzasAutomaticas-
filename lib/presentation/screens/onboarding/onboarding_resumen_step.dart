import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/dashboard/dashboard_providers.dart';
import '../../state/providers.dart';
import '../dashboard/widgets/wallet_account_card.dart';
import 'deuda_lista_item.dart';

/// Paso final: resumen + botón que cierra el onboarding.
class OnboardingResumenStep extends ConsumerStatefulWidget {
  const OnboardingResumenStep({
    super.key,
    required this.nombre,
    required this.nick,
  });

  final String nombre;
  final String nick;

  @override
  ConsumerState<OnboardingResumenStep> createState() =>
      _OnboardingResumenStepState();
}

class _OnboardingResumenStepState extends ConsumerState<OnboardingResumenStep> {
  bool _finalizando = false;

  Future<void> _finalizar() async {
    setState(() => _finalizando = true);
    try {
      final preferencias = ref.read(preferenciasRepositoryProvider);
      await preferencias.guardarNombre(widget.nombre);
      await ref.read(perfilRepositoryProvider).guardarNick(widget.nick);
      await preferencias.marcarOnboardingCompletado();

      ref.invalidate(cuentasProvider);
      ref.invalidate(resumenDashboardProvider);
      ref.invalidate(onboardingCompletadoProvider);
      ref.invalidate(nombreUsuarioProvider);
      ref.invalidate(perfilProvider);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo completar: $error')));
    } finally {
      if (mounted) setState(() => _finalizando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cuentasAsync = ref.watch(cuentasProvider);
    final deudasAsync = ref.watch(deudasProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Todo listo',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa lo que configuraste antes de empezar.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('Nombre', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(widget.nombre, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('Nick', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('@${widget.nick}', style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text('Cuentas', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          cuentasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Text('No se pudieron cargar las cuentas.'),
            data: (cuentas) => Column(
              children: [
                for (final cuenta in cuentas)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: WalletAccountCard(cuenta: cuenta, compacto: true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Deudas', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          deudasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                const Text('No se pudieron cargar las deudas.'),
            data: (deudas) => deudas.isEmpty
                ? Text(
                    'Sin deudas registradas.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: [
                      for (final deuda in deudas)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: DeudaListaItem(deuda: deuda),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _finalizando ? null : _finalizar,
            child: _finalizando
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  )
                : const Text('Empezar a usar la app'),
          ),
        ],
      ),
    );
  }
}
