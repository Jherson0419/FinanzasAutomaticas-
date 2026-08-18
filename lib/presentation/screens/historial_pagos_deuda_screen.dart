import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/entities/pago_deuda.dart';
import '../shared/app_card.dart';
import '../shared/formatters.dart';
import '../state/providers.dart';

class HistorialPagosDeudaScreen extends ConsumerWidget {
  const HistorialPagosDeudaScreen({super.key, required this.deudaId});

  final String deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudaAsync = ref.watch(deudaPorIdProvider(deudaId));

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de pagos')),
      body: SafeArea(
        child: deudaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('No se pudo cargar la deuda.\n$error')),
          data: (deuda) {
            if (deuda == null) {
              return const Center(child: Text('Esta deuda ya no existe.'));
            }
            return _Contenido(deuda: deuda);
          },
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({required this.deuda});

  final Deuda deuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deuda.nombreDeuda,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListaPagosDeuda(deudaId: deuda.id, moneda: deuda.moneda),
      ],
    );
  }
}

/// Lista de pagos registrados de una deuda ("Pagos registrados" + estados
/// de carga/error/vacío). Widget público para poder embeberse tanto en
/// [HistorialPagosDeudaScreen] como en `deuda_detalle_screen.dart` (deudas
/// `pagoLibre`) sin duplicar la lógica de renderizado.
class ListaPagosDeuda extends ConsumerWidget {
  const ListaPagosDeuda({
    super.key,
    required this.deudaId,
    required this.moneda,
  });

  final String deudaId;
  final Moneda moneda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pagosAsync = ref.watch(pagosPorDeudaProvider(deudaId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pagos registrados', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        pagosAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Text(
            'No se pudieron cargar los pagos.\n$error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          data: (pagos) {
            if (pagos.isEmpty) {
              return Text(
                'Todavía no registraste ningún pago para esta deuda.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              );
            }
            final ordenados = [...pagos]
              ..sort((a, b) => b.fechaPago.compareTo(a.fechaPago));
            return Column(
              children: [
                for (final pago in ordenados)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FilaPago(pago: pago, moneda: moneda),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilaPago extends ConsumerWidget {
  const _FilaPago({required this.pago, required this.moneda});

  final PagoDeuda pago;
  final Moneda moneda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cuentaId = pago.cuentaId;

    final detalles = <String>[];
    if (pago.montoCapital != null) {
      detalles.add('Capital: ${formatearMonto(pago.montoCapital!, moneda)}');
    }
    if (pago.montoInteres != null) {
      detalles.add('Interés: ${formatearMonto(pago.montoInteres!, moneda)}');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatearMonto(pago.montoPagado, moneda),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                formatearFecha(pago.fechaPago),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (detalles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              detalles.join(' · '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (pago.numeroCuota != null) ...[
            const SizedBox(height: 4),
            Text(
              'Cuota #${pago.numeroCuota}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 4),
          if (cuentaId == null)
            Text(
              'Pago retroactivo (sin cuenta asociada)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ref
                .watch(cuentaPorIdProvider(cuentaId))
                .when(
                  loading: () => Text(
                    'Cargando cuenta...',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  error: (error, stackTrace) => Text(
                    'Cuenta desconocida',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  data: (cuenta) => Text(
                    cuenta != null
                        ? 'Desde ${cuenta.nombre}'
                        : 'Cuenta eliminada',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
