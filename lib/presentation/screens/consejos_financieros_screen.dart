import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/mensaje_consejo.dart';
import '../../domain/repositories/consejos_financieros_repository.dart'
    show LimiteDiarioConsejosError;
import '../shared/app_bottom_bar.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Chat de consejos financieros con Gemini (Fase 30) — reemplaza el flujo
/// de "Generar consejos" de un solo turno (Fase 24, sin historial). La
/// primera vez que el usuario entra y no tiene ningún mensaje guardado, la
/// app arma su resumen financiero (agregado y anonimizado, mismo criterio
/// de siempre) y lo manda sola como el primer mensaje — el usuario no tiene
/// que tocar nada para empezar la conversación. De ahí en adelante es un
/// chat normal: el historial se guarda en `mensajes_consejos` y persiste
/// entre sesiones.
class ConsejosFinancierosScreen extends ConsumerStatefulWidget {
  const ConsejosFinancierosScreen({super.key});

  @override
  ConsumerState<ConsejosFinancierosScreen> createState() =>
      _ConsejosFinancierosScreenState();
}

class _ConsejosFinancierosScreenState
    extends ConsumerState<ConsejosFinancierosScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  bool _enviando = false;
  String? _mensajeOptimista;
  Object? _errorSistema;

  /// Evita que `build()` agende el primer mensaje automático más de una
  /// vez por apertura de pantalla, incluso si `historialConsejosProvider`
  /// se reconstruye por otros motivos mientras la conversación arranca.
  bool _yaIniciando = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Guardia de "en curso" — permite que el botón "Reintentar" vuelva a
  /// llamar esto tras un error (a diferencia de `_yaIniciando`, que solo
  /// evita que `build()` agende el envío automático más de una vez).
  Future<void> _iniciarConversacion() async {
    if (_enviando) return;
    setState(() {
      _enviando = true;
      _errorSistema = null;
    });

    try {
      final resumen = await ref.read(armarResumenParaConsejosProvider)();
      await ref
          .read(chatConsejosRepositoryProvider)
          .enviarMensaje(mensaje: '', esPrimerMensaje: true, resumen: resumen);
      ref.invalidate(historialConsejosProvider);
      await ref.read(historialConsejosProvider.future);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorSistema = error);
    } finally {
      if (mounted) setState(() => _enviando = false);
      _scrollAlFinal();
    }
  }

  Future<void> _enviarSeguimiento() async {
    final texto = _controller.text.trim();
    if (texto.isEmpty || _enviando) return;

    _controller.clear();
    setState(() {
      _enviando = true;
      _mensajeOptimista = texto;
      _errorSistema = null;
    });
    _scrollAlFinal();

    try {
      await ref
          .read(chatConsejosRepositoryProvider)
          .enviarMensaje(mensaje: texto);
      ref.invalidate(historialConsejosProvider);
      await ref.read(historialConsejosProvider.future);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorSistema = error);
      _controller.text = texto;
    } finally {
      if (mounted) {
        setState(() {
          _enviando = false;
          _mensajeOptimista = null;
        });
      }
      _scrollAlFinal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historialAsync = ref.watch(historialConsejosProvider);

    // Primer mensaje automático (30.4): en cuanto se sabe que el historial
    // está vacío, se agenda una sola vez — `_yaIniciando` se marca aquí
    // mismo, de forma síncrona dentro de `build()` (que nunca se reentra),
    // así que no hace falta ninguna protección adicional contra que se
    // dispare dos veces. `_iniciarConversacion` en sí queda libre para que
    // el botón "Reintentar" la vuelva a llamar tras un error.
    final mensajesCargados = historialAsync.valueOrNull;
    if (mensajesCargados != null && mensajesCargados.isEmpty && !_yaIniciando) {
      _yaIniciando = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _iniciarConversacion();
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Consejos financieros')),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.consejos),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: historialAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudo cargar la conversación.\n$error',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
                data: (mensajes) {
                  if (mensajes.isEmpty && !_enviando && _errorSistema == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Preparando tu resumen financiero...',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final mensaje in mensajes)
                        _Burbuja(
                          texto: mensaje.contenido,
                          esUsuario: mensaje.rol == RolMensajeConsejo.usuario,
                        ),
                      if (_mensajeOptimista != null)
                        _Burbuja(texto: _mensajeOptimista!, esUsuario: true),
                      if (_enviando) const _BurbujaEscribiendo(),
                      if (_errorSistema != null)
                        _BurbujaSistema(
                          error: _errorSistema!,
                          onReintentar: mensajes.isEmpty
                              ? _iniciarConversacion
                              : null,
                        ),
                    ],
                  );
                },
              ),
            ),
            _CampoDeTexto(
              controller: _controller,
              habilitado: !_enviando,
              onEnviar: _enviarSeguimiento,
            ),
          ],
        ),
      ),
    );
  }
}

class _CampoDeTexto extends StatelessWidget {
  const _CampoDeTexto({
    required this.controller,
    required this.habilitado,
    required this.onEnviar,
  });

  final TextEditingController controller;
  final bool habilitado;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: habilitado,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onEnviar(),
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: habilitado ? onEnviar : null,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.texto, required this.esUsuario});

  final String texto;
  final bool esUsuario;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: esUsuario
              ? colorSuccess.withValues(alpha: 0.18)
              : context.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: esUsuario
              ? null
              : Border.all(color: context.borderCard, width: 0.5),
        ),
        child: Text(
          texto,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _BurbujaEscribiendo extends StatelessWidget {
  const _BurbujaEscribiendo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderCard, width: 0.5),
        ),
        child: Text(
          'Escribiendo...',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _BurbujaSistema extends StatelessWidget {
  const _BurbujaSistema({required this.error, this.onReintentar});

  final Object error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // El límite diario (Fase 24, contando mensajes desde la Fase 30) no es
    // un error real, es un tope esperado — se distingue con color/ícono
    // propios en vez de tratarlo como una falla genérica.
    final esLimiteDiario = error is LimiteDiarioConsejosError;
    final color = esLimiteDiario ? colorWarning : colorDanger;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                esLimiteDiario ? Icons.info_outline : Icons.error_outline,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  mensajeDeError(error),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
            ],
          ),
          if (onReintentar != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: onReintentar,
              child: Text('Reintentar', style: TextStyle(color: color)),
            ),
          ],
        ],
      ),
    );
  }
}
