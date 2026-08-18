import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cronograma_cuotas.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../shared/app_card.dart';
import '../shared/dashboard_colors.dart';
import '../shared/enum_labels.dart';
import '../shared/formatters.dart';
import '../state/providers.dart';
import 'historial_pagos_deuda_screen.dart';
import 'pago_deuda_nuevo_screen.dart';

class DeudaDetalleScreen extends ConsumerWidget {
  const DeudaDetalleScreen({super.key, required this.deudaId});

  final String deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deudaAsync = ref.watch(deudaPorIdProvider(deudaId));

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la deuda')),
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

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.deuda});

  final Deuda deuda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final esCuotasFijas = deuda.estructuraPago == EstructuraPago.cuotasFijas;
    final pagosAsync = ref.watch(pagosPorDeudaProvider(deuda.id));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _MiniDashboard(deuda: deuda),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar deuda'),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/deudas/nueva', arguments: deuda.id),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver historial'),
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed('/deudas/historial', arguments: deuda.id),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (esCuotasFijas)
          pagosAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => Text(
              'No se pudo cargar el cronograma.\n$error',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            data: (pagos) {
              final cronograma = generarCronogramaCuotas(deuda, pagos);
              if (cronograma.isEmpty) {
                return Text(
                  'Esta deuda no tiene un cronograma de cuotas configurado.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cronograma de cuotas',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Desliza una cuota pendiente hacia la derecha para registrar su pago.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final cuota in cronograma)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: cuota.pagada
                          ? _FilaCuota(cuota: cuota, moneda: deuda.moneda)
                          : Dismissible(
                              key: ValueKey('cuota-${cuota.numero}'),
                              direction: DismissDirection.startToEnd,
                              background: Container(
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Icon(
                                  Icons.payments_outlined,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                await Navigator.of(context).pushNamed(
                                  '/deudas/pago',
                                  arguments: PagoDeudaRouteArgs(
                                    deudaId: deuda.id,
                                    numeroCuotaInicial: cuota.numero,
                                    montoEsperadoInicial: cuota.montoEsperado,
                                  ),
                                );
                                return false;
                              },
                              child: _FilaCuota(
                                cuota: cuota,
                                moneda: deuda.moneda,
                              ),
                            ),
                    ),
                ],
              );
            },
          )
        else
          ListaPagosDeuda(deudaId: deuda.id, moneda: deuda.moneda),
      ],
    );
  }
}

class _MiniDashboard extends StatelessWidget {
  const _MiniDashboard({required this.deuda});

  final Deuda deuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progreso = deuda.montoTotal <= 0
        ? 0.0
        : (deuda.montoPagado / deuda.montoTotal).clamp(0.0, 1.0);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            deuda.nombreDeuda,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${labelTipoDeuda(deuda.tipoDeuda)} · ${deuda.nombreAcreedor}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (deuda.enMora) ...[
            _Banner(
              color: colorGasto(context),
              texto: deuda.diasMora != null && deuda.diasMora! > 0
                  ? 'En mora hace ${deuda.diasMora} día(s)'
                  : 'En mora',
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Monto total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                formatearMonto(deuda.montoTotal, deuda.moneda),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (deuda.interesTotal != null && deuda.interesTotal! > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Interés total',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatearMonto(deuda.interesTotal!, deuda.moneda),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),
          Text(
            deuda.estructuraPago == EstructuraPago.cuotasFijas
                ? (deuda.proximaFechaPago != null
                      ? 'Próxima cuota: ${formatearFecha(deuda.proximaFechaPago!)}'
                            '${deuda.montoCuota != null ? ' · ${formatearMonto(deuda.montoCuota!, deuda.moneda)}' : ''}'
                      : 'Todas las cuotas están pagadas')
                : 'Sin cuota fija (pago libre)',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilaCuota extends StatelessWidget {
  const _FilaCuota({required this.cuota, required this.moneda});

  final CuotaProgramada cuota;
  final Moneda moneda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cuota #${cuota.numero}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatearFecha(cuota.fechaVencimiento),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatearMonto(cuota.montoEsperado, moneda),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 12),
          Icon(
            cuota.pagada ? Icons.check_circle : Icons.schedule,
            color: cuota.pagada
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
