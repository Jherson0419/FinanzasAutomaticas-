import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../domain/pin_hash.dart';
import '../state/providers.dart';

/// Se muestra solo al abrir la app en frío (cold start) cuando ya hay
/// PIN/biométrico configurado — ver `desbloqueadoEnEstaSesionProvider`.
class DesbloqueoScreen extends ConsumerStatefulWidget {
  const DesbloqueoScreen({super.key});

  @override
  ConsumerState<DesbloqueoScreen> createState() => _DesbloqueoScreenState();
}

class _DesbloqueoScreenState extends ConsumerState<DesbloqueoScreen> {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();

  String? _error;
  bool _verificando = false;
  bool _intentoBiometricoHecho = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _intentarBiometrico());
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _intentarBiometrico() async {
    if (_intentoBiometricoHecho) return;
    _intentoBiometricoHecho = true;

    final biometricoActivo = await ref
        .read(preferenciasRepositoryProvider)
        .obtenerBloqueoBiometricoActivo();
    if (!biometricoActivo) return;

    try {
      final exito = await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para continuar',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (exito) _desbloquear();
    } catch (_) {
      // El usuario canceló o falló el biométrico — se queda en esta
      // pantalla y puede usar el PIN en su lugar.
    }
  }

  void _desbloquear() {
    ref.read(desbloqueadoEnEstaSesionProvider.notifier).state = true;
  }

  Future<void> _verificarPin() async {
    setState(() {
      _verificando = true;
      _error = null;
    });

    final hashGuardado = await ref
        .read(preferenciasRepositoryProvider)
        .obtenerPinHash();
    final hashIngresado = hashPin(_pinController.text.trim());

    if (!mounted) return;

    if (hashGuardado != null && hashGuardado == hashIngresado) {
      _desbloquear();
      return;
    }

    setState(() {
      _error = 'PIN incorrecto';
      _verificando = false;
    });
    _pinController.clear();
  }

  Future<void> _usarCorreoYContrasena() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    ref.invalidate(haySesionActivaProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pinValido = _pinController.text.trim().length == 4;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 48, color: colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Ingresa tu PIN',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    counterText: '',
                    errorText: _error,
                  ),
                  onChanged: (_) => setState(() {}),
                  onFieldSubmitted: (_) => pinValido ? _verificarPin() : null,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: (pinValido && !_verificando)
                      ? _verificarPin
                      : null,
                  child: _verificando
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Desbloquear'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _usarCorreoYContrasena,
                  child: const Text('Usar mi correo y contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
