import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/app_card.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Se muestra automáticamente desde `RootScreen` (Fase 21) cuando hay datos
/// financieros locales en Drift sin migrar a Supabase. A partir de que
/// `MigrarDatosALaNube` termina con éxito, la app deja de ser
/// offline-first: cuentas, categorías propias, deudas, transacciones y
/// pagos viven solo en Supabase.
class MigrarDatosScreen extends ConsumerStatefulWidget {
  const MigrarDatosScreen({super.key});

  @override
  ConsumerState<MigrarDatosScreen> createState() => _MigrarDatosScreenState();
}

class _MigrarDatosScreenState extends ConsumerState<MigrarDatosScreen> {
  bool _migrando = false;
  String? _etapaActual;
  Object? _error;

  Future<void> _confirmarYMigrar() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Subir tus datos a la nube',
      mensaje:
          'Vamos a subir tus cuentas, categorías, deudas, transacciones y '
          'pagos a la nube. A partir de ahora la app necesita conexión a '
          'internet para funcionar. Una vez confirmada la subida, '
          'tus datos locales se borrarán de este dispositivo.',
      textoConfirmar: 'Subir y continuar',
    );
    if (!confirmado) return;
    if (!mounted) return;
    await _migrar();
  }

  Future<void> _migrar() async {
    setState(() {
      _migrando = true;
      _error = null;
      _etapaActual = null;
    });

    try {
      await ref.read(migrarDatosALaNubeProvider)(
        onProgreso: (etapa) {
          if (mounted) setState(() => _etapaActual = etapa);
        },
      );

      // Solo se borra lo local si la subida (incluida su verificación de
      // conteos) terminó sin lanzar ninguna excepción.
      await ref.read(appDatabaseProvider).limpiarTrasMigracion();
      await ref.read(preferenciasRepositoryProvider).marcarDatosEnLaNube();
      ref.invalidate(datosEnLaNubeProvider);
      ref.invalidate(necesitaMigracionProvider);

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _migrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Subir tus datos a la nube')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.cloud_upload_outlined,
                      color: colorSuccess,
                      size: 28,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Encontramos datos guardados en este dispositivo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vamos a subir tus cuentas, categorías propias, '
                      'deudas, transacciones y pagos a la nube (Supabase). '
                      'Desde ese momento la app deja de funcionar sin '
                      'conexión: cada lectura y escritura de tus datos '
                      'financieros necesita internet.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Una vez confirmada la subida, tus datos locales se '
                      'borran de este dispositivo — antes de eso no se '
                      'toca nada.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorWarning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_migrando) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _etapaActual ?? 'Preparando...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ),
              ] else if (_error != null) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: colorDanger,
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No se pudo completar la subida',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        mensajeDeError(_error!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tus datos locales siguen intactos — puedes '
                        'reintentar cuando quieras.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _confirmarYMigrar,
                  child: const Text('Reintentar'),
                ),
              ] else
                FilledButton(
                  onPressed: _confirmarYMigrar,
                  child: const Text('Subir mis datos'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
