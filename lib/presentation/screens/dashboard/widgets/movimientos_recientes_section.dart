import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../../domain/entities/transaccion.dart';
import '../../../../domain/movimientos.dart';
import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_bottom_bar.dart';
import '../../../shared/app_card.dart';
import '../../../shared/fila_movimiento.dart';
import '../../../state/providers.dart';

/// "Movimientos recientes" del Inicio (Fase 81, 01-inicio.png): las 3
/// últimas transacciones con [FilaMovimiento] ("Categoría · Cuenta · Hoy")
/// y "Ver todo" hacia la pestaña Movimientos. Rediseño de la sección de la
/// Fase 19 (ya no es un acordeón).
///
/// `MovimientoReciente` no trae la cuenta: el nombre se resuelve cruzando
/// el id con `todasLasTransaccionesProvider` + `cuentasProvider`. Si esos
/// datos no están (o fallan), la fila igual se dibuja sin la cuenta.
class MovimientosRecientesSection extends ConsumerWidget {
  const MovimientosRecientesSection({
    super.key,
    required this.movimientosRecientes,
    this.limite = 3,
  });

  final List<MovimientoReciente> movimientosRecientes;
  final int limite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ahora = DateTime.now();
    final visibles = movimientosRecientes.take(limite).toList();
    final todas =
        ref.watch(todasLasTransaccionesProvider).valueOrNull ??
        const <Transaccion>[];
    final cuentaPorTransaccion = {for (final t in todas) t.id: t.cuentaId};
    // Fase 85: para titular "Transferencia a Visa BCP".
    final pares = cuentasDeTransferencias(todas);
    final porId = {for (final t in todas) t.id: t};
    final nombreCuenta = {
      for (final c
          in ref.watch(cuentasProvider).valueOrNull ?? const <Cuenta>[])
        c.id: c.nombre,
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EncabezadoSeccion(
            titulo: 'Movimientos recientes',
            textoAccion: 'Ver todo',
            etiquetaAccion: 'Ver todos los movimientos',
            onAccion: () => irADestino(context, AppBottomTab.movimientos),
          ),
          if (visibles.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Todavía no hay movimientos.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
          for (final m in visibles) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilaMovimiento(
                transaccionId: m.id,
                concepto: m.concepto,
                categoriaNombre: m.categoriaNombre,
                categoriaIcono: m.categoriaIconName,
                cuentaNombre: nombreCuenta[cuentaPorTransaccion[m.id]],
                fecha: m.fecha,
                ahora: ahora,
                monto: m.monto,
                moneda: m.moneda,
                esIngreso: m.tipo == TipoTransaccion.ingreso,
                esAjuste: m.fuenteCaptura == FuenteCaptura.ajuste,
                transferenciaId: m.transferenciaId,
                tituloTransferencia: m.transferenciaId == null
                    ? null
                    : porId[m.id] == null
                    ? 'Transferencia'
                    : tituloTransferencia(porId[m.id]!, pares, nombreCuenta),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
