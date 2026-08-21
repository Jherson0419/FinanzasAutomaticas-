import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/generar_sugerencias_nick.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';

/// Paso 2 (Fase 31, entre nombre y cuentas): nick único del usuario.
/// Obligatorio para continuar — valida en vivo contra Supabase (debounce,
/// sin golpear la base en cada tecla) vía `PerfilRepository.nickDisponible`.
/// El nick en sí se guarda recién en el paso de resumen (mismo patrón que
/// el nombre, Fase 9: el controller sobrevive la navegación entre pasos
/// porque vive en `OnboardingFlowScreen`, no aquí).
///
/// Fase 56: si [nombre] no viene vacío (el paso anterior ya lo pidió),
/// ofrece 3 sugerencias de nick generadas a partir de él
/// (`generarSugerenciasNick`), verificadas en paralelo contra
/// `nickDisponible` — solo se muestran como chips las que de verdad están
/// libres. [nombre] es opcional (por defecto `''`, sin sugerencias) para
/// no romper a quien instancie este widget sin pasar por el paso anterior.
class OnboardingNickStep extends ConsumerStatefulWidget {
  const OnboardingNickStep({
    super.key,
    required this.controller,
    required this.onAtras,
    required this.onContinuar,
    this.nombre = '',
  });

  final TextEditingController controller;
  final VoidCallback onAtras;
  final VoidCallback onContinuar;
  final String nombre;

  @override
  ConsumerState<OnboardingNickStep> createState() => _OnboardingNickStepState();
}

enum _EstadoNick {
  vacio,
  formatoInvalido,
  verificando,
  disponible,
  tomado,
  error,
}

/// Nicks de 3-20 caracteres, letras/números/guion bajo — mismo criterio que
/// un "handle" típico (sin espacios ni símbolos que compliquen buscarlo
/// después desde un futuro sistema social).
final _formatoNickValido = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

class _OnboardingNickStepState extends ConsumerState<OnboardingNickStep> {
  Timer? _debounce;
  _EstadoNick _estado = _EstadoNick.vacio;

  /// El nick que dio origen al último resultado de `_estado` — si el
  /// usuario sigue escribiendo después de que la verificación async
  /// resuelve, ese resultado ya no aplica al texto actual.
  String? _nickVerificado;

  /// `null` mientras se generan/verifican; lista (posiblemente vacía) una
  /// vez resueltas — ya filtrada a solo las sugerencias disponibles.
  List<String>? _sugerencias;

  bool get _esValido =>
      _estado == _EstadoNick.disponible &&
      _nickVerificado == widget.controller.text.trim();

  @override
  void initState() {
    super.initState();
    if (widget.controller.text.trim().isNotEmpty) _programarVerificacion();
    _generarSugerencias();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Genera 3 candidatas a partir de [OnboardingNickStep.nombre] y las
  /// verifica todas en paralelo — cada `nickDisponible` que falle se
  /// descarta en silencio (una sugerencia es un atajo opcional, no vale la
  /// pena mostrar un error por ella; el campo de texto libre sigue
  /// funcionando igual si esto no encuentra nada).
  Future<void> _generarSugerencias() async {
    final candidatas = generarSugerenciasNick(widget.nombre);
    if (candidatas.isEmpty) {
      setState(() => _sugerencias = const []);
      return;
    }

    final repo = ref.read(perfilRepositoryProvider);
    final resultados = await Future.wait(
      candidatas.map((candidata) async {
        try {
          return await repo.nickDisponible(candidata) ? candidata : null;
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _sugerencias = resultados.whereType<String>().toList();
    });
  }

  void _elegirSugerencia(String sugerencia) {
    widget.controller.text = sugerencia;
    widget.controller.selection = TextSelection.collapsed(
      offset: sugerencia.length,
    );
    _onCambio(sugerencia);
  }

  void _onCambio(String texto) {
    setState(() {});
    _programarVerificacion();
  }

  void _programarVerificacion() {
    _debounce?.cancel();
    final nick = widget.controller.text.trim();

    if (nick.isEmpty) {
      setState(() => _estado = _EstadoNick.vacio);
      return;
    }
    if (!_formatoNickValido.hasMatch(nick)) {
      setState(() => _estado = _EstadoNick.formatoInvalido);
      return;
    }

    setState(() => _estado = _EstadoNick.verificando);
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _verificar(nick);
    });
  }

  Future<void> _verificar(String nick) async {
    try {
      final disponible = await ref
          .read(perfilRepositoryProvider)
          .nickDisponible(nick);
      if (!mounted) return;
      // El campo pudo cambiar mientras esperábamos la respuesta — solo
      // aplica el resultado si sigue siendo el texto actual.
      if (widget.controller.text.trim() != nick) return;
      setState(() {
        _nickVerificado = nick;
        _estado = disponible ? _EstadoNick.disponible : _EstadoNick.tomado;
      });
    } catch (error) {
      if (!mounted) return;
      if (widget.controller.text.trim() != nick) return;
      setState(() => _estado = _EstadoNick.error);
    }
  }

  String? get _textoAyuda {
    switch (_estado) {
      case _EstadoNick.vacio:
        return null;
      case _EstadoNick.formatoInvalido:
        return 'Usa entre 3 y 20 letras, números o guion bajo, sin espacios.';
      case _EstadoNick.verificando:
        return 'Verificando disponibilidad...';
      case _EstadoNick.disponible:
        return 'Disponible';
      case _EstadoNick.tomado:
        return 'Ya está en uso';
      case _EstadoNick.error:
        return 'No se pudo verificar. Revisa tu conexión.';
    }
  }

  Color? _colorAyuda(BuildContext context) {
    switch (_estado) {
      case _EstadoNick.disponible:
        return colorSuccess;
      case _EstadoNick.tomado:
      case _EstadoNick.error:
        return colorDanger;
      case _EstadoNick.formatoInvalido:
        return colorWarning;
      case _EstadoNick.vacio:
      case _EstadoNick.verificando:
        return context.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Elige tu nick',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Es tu identificador único en Finzo. No se puede cambiar '
            'después de este paso.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: widget.controller,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Nick',
              prefixText: '@',
              border: const OutlineInputBorder(),
              helperText: _textoAyuda,
              helperStyle: TextStyle(color: _colorAyuda(context)),
              suffixIcon: _estado == _EstadoNick.verificando
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _estado == _EstadoNick.disponible
                  ? const Icon(Icons.check_circle, color: colorSuccess)
                  : null,
            ),
            textInputAction: TextInputAction.done,
            onChanged: _onCambio,
          ),
          if (_sugerencias == null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'Buscando sugerencias de nick...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ] else if (_sugerencias!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Sugerencias:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sugerencia in _sugerencias!)
                  ActionChip(
                    label: Text('@$sugerencia'),
                    onPressed: () => _elegirSugerencia(sugerencia),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onAtras,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _esValido ? widget.onContinuar : null,
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
