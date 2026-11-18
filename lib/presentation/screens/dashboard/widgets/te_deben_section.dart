import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/deuda.dart';
import '../../../shared/app_card.dart';
import '../../../shared/estilos.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';
import '../../../state/dashboard/dashboard_providers.dart';
import '../../../state/providers.dart';

/// Texto de una deuda registrada por un amigo, desde MI punto de vista
/// (Fase 82): la dirección guardada es la del dueño, así que se invierte.
/// - El dueño la registró como "debo" (me debe a mí) → "{dueño} te debe".
/// - El dueño la registró como "me deben" (yo le debo) → "Debes a {dueño}".
String textoDeudaDeAmigo(DeudaDeAmigo deuda, String nombreDueno) {
  final monto = formatearMonto(deuda.montoAdeudado, deuda.moneda);
  return deuda.yoDebo
      ? 'Debes a $nombreDueno $monto'
      : '$nombreDueno te debe $monto';
}

/// "Registradas por tus amigos" (Fase 68 como "Te deben"; ampliada en la
/// Fase 82 con la dirección). Deudas que OTRO usuario registró y vinculó a
/// mí, en modo solo lectura: sin pagar, editar ni eliminar, porque no son
/// mías. Van FUERA de "Total que debes" / "Total que te deben" para no
/// duplicar montos (la deuda real vive en la cuenta del amigo).
///
/// [soloYoDebo]: `true` = solo las que yo debo (pestaña Debo), `false` =
/// solo las que me deben (pestaña Me deben), `null` = todas. No se muestra
/// nada si no hay ninguna.
class TeDebenSection extends ConsumerWidget {
  const TeDebenSection({super.key, this.soloYoDebo});

  final bool? soloYoDebo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todas = ref.watch(deudasQueMeDebenProvider).valueOrNull ?? const [];
    final deudas = [
      for (final d in todas)
        if (soloYoDebo == null || d.yoDebo == soloYoDebo) d,
    ];
    if (deudas.isEmpty) return const SizedBox.shrink();

    final amigos = ref.watch(amigosProvider).valueOrNull ?? const [];
    final nickPorId = {for (final amigo in amigos) amigo.usuarioId: amigo.nick};

    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel(
            icon: Icons.people_outline,
            label: 'Registradas por tus amigos',
          ),
          const SizedBox(height: 12),
          for (final deuda in deudas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                textoDeudaDeAmigo(
                  deuda,
                  nickPorId[deuda.deudorUsuarioId] ?? 'Alguien',
                ),
                style: estiloMonto(theme.textTheme.bodyMedium),
              ),
            ),
        ],
      ),
    );
  }
}
