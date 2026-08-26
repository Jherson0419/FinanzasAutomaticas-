import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/mensajes_error.dart';
import '../state/providers.dart';

/// Paso 2 de "¿Olvidaste tu contraseña?" (Fase 65) — abierta por
/// `FinanzasAutomaticasApp` cuando llega el deep link `finzo://reset-password`
/// y `supabase_flutter` ya armó sola la sesión de recuperación
/// (`AuthChangeEvent.passwordRecovery`, ver `app.dart`). Guardar la nueva
/// contraseña (`AuthRepository.actualizarContrasena`) dentro de esa sesión
/// la deja como la sesión activa normal — no hace falta iniciar sesión de
/// nuevo, solo volver a la raíz de la navegación para que `RootScreen`
/// reaccione y muestre el dashboard.
class NuevaContrasenaScreen extends ConsumerStatefulWidget {
  const NuevaContrasenaScreen({super.key});

  @override
  ConsumerState<NuevaContrasenaScreen> createState() =>
      _NuevaContrasenaScreenState();
}

class _NuevaContrasenaScreenState
    extends ConsumerState<NuevaContrasenaScreen> {
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _guardando = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  bool get _passwordValida => _passwordController.text.length >= 6;
  bool get _confirmacionValida =>
      _confirmarPasswordController.text == _passwordController.text;

  bool get _esValido => _passwordValida && _confirmacionValida;

  String? get _errorConfirmacion {
    if (_confirmarPasswordController.text.isEmpty) return null;
    return _confirmacionValida ? null : 'Las contraseñas no coinciden';
  }

  Future<void> _guardar() async {
    if (!_esValido) return;

    setState(() => _guardando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .actualizarContrasena(nuevaContrasena: _passwordController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorConfirmacion = _errorConfirmacion;

    return Scaffold(
      appBar: AppBar(title: const Text('Nueva contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Elige tu nueva contraseña.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Nueva contraseña',
                  helperText: 'Mínimo 6 caracteres',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _passwordVisible ? 'Ocultar' : 'Mostrar',
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmarPasswordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  border: const OutlineInputBorder(),
                  errorText: errorConfirmacion,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_esValido && !_guardando) ? _guardar : null,
                child: _guardando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
