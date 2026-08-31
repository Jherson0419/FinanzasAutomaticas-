import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notificacion.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Ícono por tipo de notificación (Fase 69, ampliado en la Fase 70) —
/// puramente visual, para poder escanear la lista de un vistazo. `tipo` es
/// el valor crudo que ya guarda `notificaciones.tipo` en Supabase:
/// - Fase 63: `solicitud_aceptada`.
/// - Fase 64: `pago_deuda_amigo`.
/// - Fase 69: `gasto_tarjeta`/`ingreso_recibido` (trigger `AFTER INSERT` en
///   `transacciones`).
/// - Fase 70: `solicitud_recibida` (trigger `AFTER INSERT` en
///   `solicitudes_amistad`); `cuota_por_vencer`/`cuota_vencida` (RPC
///   `generar_notificaciones_vencimiento`, llamado desde
///   `resumenDashboardProvider`); `deuda_pagada`/`deuda_amigo_pagada`
///   (trigger `AFTER UPDATE` en `deudas`).
/// - Fase 71: `deuda_vinculada` (trigger `AFTER INSERT OR UPDATE` en
///   `deudas`, se dispara al amigo cuando `amigo_usuario_id` pasa de nulo
///   a un valor — nunca en ediciones posteriores que no tocan ese campo).
///
/// Ninguna de estas la crea la app directamente (todas vienen de un
/// trigger/RPC de Postgres) — cualquier tipo futuro no listado aquí cae al
/// ícono genérico en vez de romper, nunca hace falta tocar este archivo
/// para que un tipo nuevo funcione, solo para que se vea distinto.
IconData _iconoParaTipoNotificacion(String tipo) {
  switch (tipo) {
    case 'solicitud_recibida':
      return Icons.person_add_alt_outlined;
    case 'solicitud_aceptada':
      return Icons.people_alt_outlined;
    case 'pago_deuda_amigo':
      return Icons.payments_outlined;
    case 'gasto_tarjeta':
      return Icons.credit_card;
    case 'ingreso_recibido':
      return Icons.savings_outlined;
    case 'cuota_por_vencer':
      return Icons.schedule;
    case 'cuota_vencida':
      return Icons.error_outline;
    case 'deuda_pagada':
      return Icons.check_circle_outline;
    case 'deuda_vinculada':
      return Icons.link;
    case 'deuda_amigo_pagada':
      return Icons.celebration_outlined;
    default:
      return Icons.notifications_none;
  }
}

/// Lista de notificaciones dentro de la app (Fase 63) — abierta desde la
/// campana del dashboard. Tocar una la marca como leída; no se borra ni
/// desaparece de la lista, solo deja de contar para el badge.
class NotificacionesScreen extends ConsumerWidget {
  const NotificacionesScreen({super.key});

  Future<void> _marcarLeida(
    WidgetRef ref,
    BuildContext context,
    Notificacion notificacion,
  ) async {
    if (notificacion.leida) return;
    try {
      await ref
          .read(notificacionRepositoryProvider)
          .marcarLeida(notificacion.id);
      ref.invalidate(notificacionesProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar: ${mensajeDeError(error)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificacionesAsync = ref.watch(notificacionesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: SafeArea(
        child: notificacionesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('No se pudieron cargar las notificaciones.\n$error'),
          ),
          data: (notificaciones) => notificaciones.isEmpty
              ? Center(
                  child: Text(
                    'No tienes notificaciones todavía.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: notificaciones.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final notificacion = notificaciones[index];
                    return InkWell(
                      onTap: () => _marcarLeida(ref, context, notificacion),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _iconoParaTipoNotificacion(notificacion.tipo),
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            if (!notificacion.leida)
                              Container(
                                margin: const EdgeInsets.only(top: 6, right: 8),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorSuccess,
                                ),
                              )
                            else
                              const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notificacion.mensaje,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: notificacion.leida
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    formatearFecha(notificacion.createdAt),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
