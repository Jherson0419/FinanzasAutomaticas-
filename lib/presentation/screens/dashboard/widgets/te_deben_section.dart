import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/app_card.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';
import '../../../state/dashboard/dashboard_providers.dart';
import '../../../state/providers.dart';

/// "Te deben" (Fase 68) — deudas de otros usuarios vinculadas a mí como
/// amigo (`Deuda.amigoUsuarioId`, Fase 64), en modo solo lectura: sin
/// swipe de pago, sin editar/eliminar, porque no son mías. Autocontenida
/// (observa sus propios providers), mismo criterio que
/// `AlertasTarjetasCreditoBanner` — no se muestra nada si no hay ninguna.
class TeDebenSection extends ConsumerWidget {
  const TeDebenSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudas = ref.watch(deudasQueMeDebenProvider).valueOrNull ?? const [];
    if (deudas.isEmpty) return const SizedBox.shrink();

    final amigos = ref.watch(amigosProvider).valueOrNull ?? const [];
    final nickPorId = {for (final amigo in amigos) amigo.usuarioId: amigo.nick};

    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(icon: Icons.call_received, label: 'Te deben'),
          const SizedBox(height: 12),
          for (final deuda in deudas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '${nickPorId[deuda.deudorUsuarioId] ?? 'Alguien'} te debe '
                '${formatearMonto(deuda.montoAdeudado, deuda.moneda)}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
