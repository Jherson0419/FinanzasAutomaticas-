import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notificacion.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

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
