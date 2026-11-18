import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/costo_deuda.dart';
import '../../domain/cronograma_cuotas.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/saldo_deuda.dart';
import '../shared/app_card.dart';
import '../shared/dashboard_colors.dart';
import '../shared/enum_labels.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import '../theme/app_theme.dart';
import '../state/providers.dart';
import 'historial_pagos_deuda_screen.dart';
import 'pago_deuda_nuevo_screen.dart';
import 'transferencia_screen.dart';

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
        // Fase 82: costo anual de lo que DEBO (insumo del plan de pago).
        if (!deuda.meDeben) ...[
          _FilaCosto(deuda: deuda),
          const SizedBox(height: 16),
        ],
        // Fase 82: botón visible para registrar un pago. Hasta la Fase 81
        // solo existía en `DeudasActivasSection` (el acordeón del Inicio);
        // aquí, las cuotas solo se pagaban deslizando (gesto sin
        // alternativa accesible) y las de pago libre no tenían forma de
        // pagarse. La deuda automática de tarjeta se paga desde la cuenta.
        if (deuda.estado != EstadoDeuda.pagada && deuda.cuentaId == null) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.payments_outlined),
            label: Text(deuda.meDeben ? 'Registrar cobro' : 'Registrar pago'),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed('/deudas/pago', arguments: deuda.id),
          ),
          const SizedBox(height: 12),
        ],
        // Fase 85: la deuda de una tarjeta se paga con una transferencia
        // hacia la tarjeta (no cuenta como gasto); la deuda se sincroniza
        // sola con el nuevo saldo de la cuenta.
        if (deuda.cuentaId != null) ...[
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            icon: const Icon(Icons.swap_horiz),
            label: const Text('Pagar tarjeta'),
            onPressed: () async {
              await Navigator.of(context).pushNamed(
                '/transferencias/nueva',
                arguments: TransferenciaRouteArgs(destinoId: deuda.cuentaId),
              );
              ref.invalidate(deudaPorIdProvider(deuda.id));
              ref.invalidate(deudasProvider);
            },
          ),
          const SizedBox(height: 12),
        ],
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

/// Fase 82 — "Costo anual estimado: X %" (`tasaEfectivaAnual`) o, si no se
/// puede calcular, "Falta la tasa" con acceso a editar la deuda. Solo
/// informativo: insumo del plan de pago (Fase 83).
class _FilaCosto extends StatelessWidget {
  const _FilaCosto({required this.deuda});

  final Deuda deuda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasa = tasaEfectivaAnual(deuda);
    if (tasa != null) {
      final porcentaje = (tasa * 100).toStringAsFixed(1);
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Semantics(
          label: 'Costo anual estimado: $porcentaje por ciento',
          excludeSemantics: true,
          child: Row(
            children: [
              Icon(Icons.percent, color: context.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Costo anual estimado',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
              Text(
                '$porcentaje %',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: cifrasTabulares,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final esTarjeta = deuda.cuentaId != null;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Icon(Icons.help_outline, color: context.warningText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              esTarjeta
                  ? 'Falta la tasa (TCEA de la tarjeta)'
                  : 'Falta la tasa',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.warningText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // La deuda automática de tarjeta no se edita aquí (se sincroniza
          // desde su cuenta).
          if (!esTarjeta)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => Navigator.of(
                context,
              ).pushNamed('/deudas/nueva', arguments: deuda.id),
              child: const Text('Agregar tasa'),
            ),
        ],
      ),
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
    // Fase 79: contra lo que hay que pagar en total (capital + interés en
    // cuotas fijas). La fila "Monto total" de abajo sigue mostrando el
    // capital a propósito: va junto a "Interés total" como desglose.
    final total = totalAPagar(deuda);
    final progreso = total <= 0
        ? 0.0
        : (deuda.montoPagado / total).clamp(0.0, 1.0);

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
                  fontFeatures: cifrasTabulares,
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
                    fontFeatures: cifrasTabulares,
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
            '${deuda.meDeben ? 'Cobrado' : 'Pagado'} ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(totalAPagar(deuda), deuda.moneda)}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: cifrasTabulares,
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
              fontFeatures: cifrasTabulares,
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
    // Fase 58: además del ícono y el color ya existentes, la cuota pagada
    // se tacha — solo el número/monto de ESA cuota, no la fecha.
    final decoracionSiPagada = cuota.pagada
        ? TextDecoration.lineThrough
        : TextDecoration.none;

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
                    decoration: decoracionSiPagada,
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
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFeatures: cifrasTabulares,
              decoration: decoracionSiPagada,
            ),
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
