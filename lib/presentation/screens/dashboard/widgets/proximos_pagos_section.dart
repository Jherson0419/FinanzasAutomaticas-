import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/deuda.dart';
import '../../../../domain/proximos_pagos.dart';
import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_bottom_bar.dart';
import '../../../shared/app_card.dart';
import '../../../shared/fila_deuda.dart';
import '../../../shared/fila_movimiento.dart';
import '../../../state/providers.dart';

/// "Próximos pagos" del Inicio (Fase 81): las 3 deudas más urgentes
/// (`proximosPagos`, mismo orden que el hub de Deudas) con la MISMA fila del
/// hub (`FilaDeuda`, variante compacta). "Ver todo" abre el hub. No se
/// muestra si no hay deudas activas.
class ProximosPagosSection extends ConsumerWidget {
  const ProximosPagosSection({
    super.key,
    required this.deudasActivas,
    this.limite = 3,
  });

  final List<DeudaActivaResumen> deudasActivas;
  final int limite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (deudasActivas.isEmpty) return const SizedBox.shrink();
    final ahora = DateTime.now();
    final deudasPorId = {
      for (final d in ref.watch(deudasProvider).valueOrNull ?? const <Deuda>[])
        d.id: d,
    };
    final proximas = proximosPagos(deudasActivas, ahora, limite: limite);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoSeccion(
            titulo: 'Próximos pagos',
            textoAccion: 'Ver todo',
            etiquetaAccion: 'Ver todas las deudas',
            onAccion: () => irADestino(context, AppBottomTab.deudas),
          ),
          for (var i = 0; i < proximas.length; i++) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 8, 12),
              child: FilaDeuda(
                resumen: proximas[i],
                deuda: deudasPorId[proximas[i].id],
                ahora: ahora,
                variante: VarianteFilaDeuda.compacta,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
