import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../domain/pin_hash.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';

/// Se ofrece una sola vez, justo después de iniciar sesión, mientras no
/// haya PIN/biométrico configurado ni se haya omitido antes (ver
/// `RootScreen`/`bloqueoOmitidoProvider`).
class ConfigurarBloqueoScreen extends ConsumerStatefulWidget {
  const ConfigurarBloqueoScreen({super.key});

  @override
  ConsumerState<ConfigurarBloqueoScreen> createState() =>
      _ConfigurarBloqueoScreenState();
}

class _ConfigurarBloqueoScreenState
    extends ConsumerState<ConfigurarBloqueoScreen> {
  final _pinController = TextEditingController();
  final _confirmarPinController = TextEditingController();
  final _localAuth = LocalAuthentication();

  bool _biometricoDisponible = false;
  bool _biometricoActivo = false;
  bool _pinConfigurado = false;
  bool _guardandoPin = false;
  bool _procesandoOmitir = false;

  @override
  void initState() {
    super.initState();
    _verificarBiometria();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmarPinController.dispose();
    super.dispose();
  }

  Future<void> _verificarBiometria() async {
    bool disponible;
    try {
      disponible = await _localAuth.canCheckBiometrics;
    } catch (_) {
      disponible = false;
    }
    if (mounted) setState(() => _biometricoDisponible = disponible);
  }

  bool get _pinValido {
    final pin = _pinController.text.trim();
    return pin.length == 4 &&
        int.tryParse(pin) != null &&
        pin == _confirmarPinController.text.trim();
  }

  Future<void> _guardarPin() async {
    if (!_pinValido) return;

    setState(() => _guardandoPin = true);
    try {
      await ref
          .read(preferenciasRepositoryProvider)
          .guardarPinHash(hashPin(_pinController.text.trim()));
      if (!mounted) return;
      setState(() => _pinConfigurado = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN guardado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar el PIN: ${mensajeDeError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardandoPin = false);
    }
  }

  Future<void> _cambiarBiometrico(bool valor) async {
    setState(() => _biometricoActivo = valor);
    try {
      await ref
          .read(preferenciasRepositoryProvider)
          .guardarBloqueoBiometricoActivo(valor);
    } catch (error) {
      if (!mounted) return;
      setState(() => _biometricoActivo = !valor);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
    }
  }

  void _continuar() {
    ref.invalidate(bloqueoConfiguradoProvider);
    // El usuario ya "se autenticó" al configurar el bloqueo recién — no
    // tiene sentido pedirle que se desbloquee de inmediato después.
    ref.read(desbloqueadoEnEstaSesionProvider.notifier).state = true;
  }

  Future<void> _omitir() async {
    setState(() => _procesandoOmitir = true);
    try {
      await ref.read(preferenciasRepositoryProvider).marcarBloqueoOmitido();
      ref.invalidate(bloqueoOmitidoProvider);
    } finally {
      if (mounted) setState(() => _procesandoOmitir = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final puedeContinuar = _pinConfigurado || _biometricoActivo;

    return Scaffold(
      appBar: AppBar(title: const Text('Protege tu app')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Agrega una capa extra de seguridad para abrir la app.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Text('PIN de 4 dígitos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Nuevo PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmarPinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Confirmar PIN',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: (_pinValido && !_guardandoPin) ? _guardarPin : null,
              child: Text(_pinConfigurado ? 'PIN guardado ✓' : 'Guardar PIN'),
            ),
            if (_biometricoDisponible) ...[
              const SizedBox(height: 28),
              Text('Face ID / huella', style: theme.textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Usar Face ID / huella'),
                value: _biometricoActivo,
                onChanged: _cambiarBiometrico,
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: puedeContinuar ? _continuar : null,
              child: const Text('Continuar'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _procesandoOmitir ? null : _omitir,
              child: const Text('Omitir por ahora'),
            ),
          ],
        ),
      ),
    );
  }
}
