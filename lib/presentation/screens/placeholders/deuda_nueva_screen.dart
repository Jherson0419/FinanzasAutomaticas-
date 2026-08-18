import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/dashboard/dashboard_providers.dart';
import '../../state/providers.dart';
import '../../shared/dialogos_eliminar.dart';
import '../deuda_formulario.dart';

class DeudaNuevaScreen extends ConsumerWidget {
  const DeudaNuevaScreen({super.key, this.deudaId});

  /// Si no es nulo, la pantalla abre en modo edición sobre esta deuda.
  final String? deudaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editando = deudaId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editando ? 'Editar deuda' : 'Nueva deuda'),
        actions: [
          if (editando)
            IconButton(
              tooltip: 'Eliminar',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _eliminar(context, ref, deudaId!),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (editando) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Ver historial de pagos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/deudas/historial', arguments: deudaId),
              ),
              const Divider(),
              const SizedBox(height: 8),
            ],
            DeudaFormulario(
              deudaId: deudaId,
              onGuardadoExitoso: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref, String id) async {
    final confirmado = await confirmarEliminar(
      context,
      titulo: 'Eliminar deuda',
      mensaje: '¿Eliminar esta deuda? Esta acción no se puede deshacer.',
    );
    if (!confirmado) return;
    if (!context.mounted) return;

    try {
      await ref.read(eliminarDeudaProvider)(deudaId: id);
      ref.invalidate(deudasProvider);
      ref.invalidate(resumenDashboardProvider);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!context.mounted) return;
      await mostrarErrorEliminar(context, error);
    }
  }
}
