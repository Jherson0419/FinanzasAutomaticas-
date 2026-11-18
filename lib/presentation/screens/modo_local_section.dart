import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/mensajes_error.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Sección "Modo local" de "Mi perfil" (Fase 78) — solo se monta cuando
/// `modoLocalProvider` es `true` (`main_local.dart`).
class ModoLocalSection extends ConsumerStatefulWidget {
  const ModoLocalSection({super.key});

  @override
  ConsumerState<ModoLocalSection> createState() => _ModoLocalSectionState();
}

class _ModoLocalSectionState extends ConsumerState<ModoLocalSection> {
  bool _trabajando = false;

  /// Todo lo que lee datos financieros/perfil y no se recalcula solo.
  void _invalidarDatos() {
    ref.invalidate(cuentasProvider);
    ref.invalidate(categoriasProvider);
    ref.invalidate(deudasProvider);
    ref.invalidate(todasLasTransaccionesProvider);
    ref.invalidate(resumenDashboardProvider);
    ref.invalidate(alertasTarjetasCreditoProvider);
    ref.invalidate(notificacionesProvider);
  }

  Future<void> _cargarDatosDeEjemplo() async {
    setState(() => _trabajando = true);
    try {
      final resultado = await ref.read(sembrarDatosDemoProvider).call();
      _invalidarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado.yaEstabaCargado
                ? 'Los datos de ejemplo ya estaban cargados'
                : 'Datos de ejemplo cargados',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _borrarTodo() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Borrar todos los datos locales?'),
        content: const Text(
          'Se eliminarán tus cuentas, movimientos, deudas, categorías '
          'propias, perfil y notificaciones guardados en este dispositivo. '
          'Esta acción no se puede deshacer. Tus datos en la nube no se '
          'tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorDanger,
              foregroundColor: colorSobreEstado,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Borrar todo'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _trabajando = true);
    try {
      await ref.read(datosLocalesRepositoryProvider).borrarTodo();
      _invalidarDatos();
      ref.invalidate(perfilProvider);
      ref.invalidate(onboardingCompletadoProvider);
      ref.invalidate(nombreUsuarioProvider);
      if (!mounted) return;
      // Sin nick guardado, `RootScreen` vuelve a mostrar el onboarding.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo borrar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Modo local', style: theme.textTheme.titleSmall),
            const SizedBox(width: 8),
            Chip(
              key: const Key('indicador_modo_local'),
              avatar: const Icon(Icons.phone_android, size: 16),
              label: const Text('Sin conexión a la nube'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Todo se guarda solo en este dispositivo. Amigos, automatización, '
          'consejos con IA y la cuenta en la nube están deshabilitados.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _trabajando ? null : _cargarDatosDeEjemplo,
          icon: const Icon(Icons.dataset_outlined),
          label: const Text('Cargar datos de ejemplo'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: colorDanger),
          onPressed: _trabajando ? null : _borrarTodo,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Borrar todos los datos locales'),
        ),
      ],
    );
  }
}
