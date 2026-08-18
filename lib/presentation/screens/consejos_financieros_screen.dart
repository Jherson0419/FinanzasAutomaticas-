import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/consejos_financieros_repository.dart';
import '../shared/app_bottom_bar.dart';
import '../shared/app_card.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';

/// Genera consejos financieros con IA (Gemini) a partir del resumen
/// agregado de deudas/ingresos/gastos. No se llama a Gemini automáticamente
/// al entrar — solo cuando el usuario toca "Generar consejos", para evitar
/// gastos de API no pedidos. Los consejos no se persisten entre sesiones.
class ConsejosFinancierosScreen extends ConsumerStatefulWidget {
  const ConsejosFinancierosScreen({super.key});

  @override
  ConsumerState<ConsejosFinancierosScreen> createState() =>
      _ConsejosFinancierosScreenState();
}

class _ConsejosFinancierosScreenState
    extends ConsumerState<ConsejosFinancierosScreen> {
  List<String>? _consejos;
  bool _cargando = false;
  Object? _error;

  Future<void> _generar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final consejos = await ref.read(obtenerConsejosFinancierosProvider)();
      if (!mounted) return;
      setState(() => _consejos = consejos);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tieneConsejos = _consejos != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Consejos financieros')),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.consejos),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                _ErrorConsejos(error: _error!),
                const SizedBox(height: 16),
              ],
              FilledButton.icon(
                onPressed: _cargando ? null : _generar,
                icon: _cargando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  tieneConsejos ? 'Actualizar consejos' : 'Generar consejos',
                ),
              ),
              const SizedBox(height: 20),
              if (tieneConsejos)
                Expanded(
                  child: _consejos!.isEmpty
                      ? Center(
                          child: Text(
                            'Gemini no devolvió consejos. Intenta de nuevo.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _consejos!.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _TarjetaConsejo(texto: _consejos![index]),
                        ),
                )
              else if (!_cargando && _error == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Toca "Generar consejos" para recibir recomendaciones '
                      'personalizadas según tus deudas, ingresos y gastos.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorConsejos extends StatelessWidget {
  const _ErrorConsejos({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final esFaltaApiKey = error is ApiKeyGeminiFaltanteError;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mensajeDeError(error),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          if (esFaltaApiKey) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/perfil'),
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaConsejo extends StatelessWidget {
  const _TarjetaConsejo({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
