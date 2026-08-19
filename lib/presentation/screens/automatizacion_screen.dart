import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/supabase_config.dart';
import '../shared/app_card.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Pantalla de Automatización (Fase 25) — punto de entrada para conectar
/// captura automática de transacciones (Atajos de iOS/Apple Pay, reglas de
/// reenvío de correo) vía la Edge Function `capturar-transaccion`.
///
/// Todavía no hay Atajo de iOS ni Worker de correo (Etapa 3 en progreso,
/// ver `CONTEXTO.md`) — esta pantalla solo expone el enlace (URL +
/// `token_webhook`) que esas piezas, cuando existan, van a necesitar
/// configurar del otro lado.
class AutomatizacionScreen extends ConsumerStatefulWidget {
  const AutomatizacionScreen({super.key});

  @override
  ConsumerState<AutomatizacionScreen> createState() =>
      _AutomatizacionScreenState();
}

class _AutomatizacionScreenState extends ConsumerState<AutomatizacionScreen> {
  bool _regenerando = false;

  /// El token va como query param (no solo en el body, aunque
  /// `capturar-transaccion` también lo acepta ahí) para que este único
  /// string, copiado tal cual, ya identifique al usuario — más simple de
  /// configurar en un Atajo o en una regla de reenvío de correo que tener
  /// que armar un body JSON con el token adentro.
  String _urlWebhook(String token) =>
      '$supabaseUrl/functions/v1/capturar-transaccion?token=$token';

  Future<void> _copiar(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Enlace copiado')));
  }

  Future<void> _regenerar() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Generar nuevo enlace',
      mensaje:
          'Esto invalida el enlace actual de inmediato — cualquier Atajo o '
          'regla de correo que ya lo tenga configurado dejará de funcionar '
          'hasta que lo actualices con el nuevo.',
      textoConfirmar: 'Generar nuevo enlace',
    );
    if (!confirmado) return;
    if (!mounted) return;

    setState(() => _regenerando = true);
    try {
      await ref.read(automatizacionRepositoryProvider).regenerarTokenWebhook();
      ref.invalidate(tokenWebhookProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enlace regenerado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo regenerar: ${mensajeDeError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _regenerando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokenAsync = ref.watch(tokenWebhookProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Automatización')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: tokenAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text(
                'No se pudo cargar tu enlace de automatización.\n$error',
              ),
            ),
            data: (token) => _construirContenido(context, _urlWebhook(token)),
          ),
        ),
      ),
    );
  }

  Widget _construirContenido(BuildContext context, String url) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Conecta capturas automáticas',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Usa este enlace para conectar un Atajo de iOS (por ejemplo, '
                'al recibir una notificación de Apple Pay) o una regla de '
                'reenvío de correo (Yape/Plin), para que tus movimientos se '
                'registren solos.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tu enlace', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _copiar(url),
                icon: const Icon(Icons.copy),
                label: const Text('Copiar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: colorDanger),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No compartas este enlace — cualquiera que lo tenga puede '
                  'registrar movimientos en tu cuenta.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorDanger,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _regenerando ? null : _regenerar,
          icon: _regenerando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onSurface,
                  ),
                )
              : const Icon(Icons.refresh),
          label: const Text('Generar nuevo enlace'),
        ),
      ],
    );
  }
}
