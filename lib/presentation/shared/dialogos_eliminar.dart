import 'package:flutter/material.dart';

import 'mensajes_error.dart';

/// Diálogo de confirmación reutilizado por las pantallas con acción
/// "Eliminar" (transacción, deuda, cuenta). Devuelve `true` solo si el
/// usuario confirmó explícitamente.
Future<bool> confirmarEliminar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

/// Diálogo de confirmación genérico (no destructivo) — mismo estilo que
/// [confirmarEliminar] pero con el texto del botón de confirmación
/// personalizable (p. ej. "Cerrar sesión").
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  required String textoConfirmar,
}) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return confirmado ?? false;
}

/// Palabra que hay que escribir tal cual (sin distinguir mayúsculas ni
/// espacios extra) para habilitar el botón de confirmar en
/// [confirmarEliminarCuenta].
const _palabraConfirmacionEliminarCuenta = 'ELIMINAR';

/// La confirmación más seria de toda la app (Fase 22): eliminar la cuenta
/// del usuario borra todos sus datos financieros y su acceso, sin forma de
/// deshacerlo. A diferencia de [confirmarEliminar]/[confirmarAccion] (un
/// botón sí/no), esto exige escribir "ELIMINAR" para habilitar el botón de
/// confirmar — el mismo patrón que usan Apple/GitHub/etc. para borrado de
/// cuenta, pensado para que no se dispare por un toque accidental.
Future<bool> confirmarEliminarCuenta(BuildContext context) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (context) {
      final controller = TextEditingController();
      return StatefulBuilder(
        builder: (context, setState) {
          final habilitado =
              controller.text.trim().toUpperCase() ==
              _palabraConfirmacionEliminarCuenta;
          return AlertDialog(
            title: const Text('Eliminar mi cuenta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esto borra permanentemente todas tus cuentas, '
                  'transacciones, deudas, pagos y categorías propias, y '
                  'elimina tu acceso a la app. No se puede deshacer.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Escribe $_palabraConfirmacionEliminarCuenta para '
                  'confirmar:',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: _palabraConfirmacionEliminarCuenta,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: habilitado
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('Eliminar mi cuenta'),
              ),
            ],
          );
        },
      );
    },
  );
  return confirmado ?? false;
}

/// Diálogo (no un SnackBar, que desaparece solo) para mostrar por qué no
/// se pudo eliminar algo — p. ej. una deuda con pagos o una cuenta con
/// movimientos registrados.
Future<void> mostrarErrorEliminar(BuildContext context, Object error) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('No se pudo eliminar'),
      content: Text(mensajeDeError(error)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    ),
  );
}
