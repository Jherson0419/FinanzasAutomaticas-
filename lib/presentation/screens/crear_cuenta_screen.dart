import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/mensajes_error.dart';
import '../state/providers.dart';

final _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class CrearCuentaScreen extends ConsumerStatefulWidget {
  const CrearCuentaScreen({super.key});

  @override
  ConsumerState<CrearCuentaScreen> createState() => _CrearCuentaScreenState();
}

class _CrearCuentaScreenState extends ConsumerState<CrearCuentaScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _creandoCuenta = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  bool get _emailValido => _regexEmail.hasMatch(_emailController.text.trim());
  bool get _passwordValida => _passwordController.text.length >= 6;
  bool get _confirmacionValida =>
      _confirmarPasswordController.text == _passwordController.text;

  bool get _esValido => _emailValido && _passwordValida && _confirmacionValida;

  String? get _errorConfirmacion {
    if (_confirmarPasswordController.text.isEmpty) return null;
    return _confirmacionValida ? null : 'Las contraseñas no coinciden';
  }

  Future<void> _crearCuenta() async {
    if (!_esValido) return;

    setState(() => _creandoCuenta = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .crearCuenta(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      ref.invalidate(haySesionActivaProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
    } finally {
      if (mounted) setState(() => _creandoCuenta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorConfirmacion = _errorConfirmacion;

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
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
                onPressed: (_esValido && !_creandoCuenta) ? _crearCuenta : null,
                child: _creandoCuenta
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Crear cuenta'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Ya tengo cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
