import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import 'crear_cuenta_screen.dart';

final _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _iniciandoSesion = false;
  bool _iniciandoConGoogle = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _esValido =>
      _regexEmail.hasMatch(_emailController.text.trim()) &&
      _passwordController.text.length >= 6;

  Future<void> _iniciarSesion() async {
    if (!_esValido) return;

    setState(() => _iniciandoSesion = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .iniciarSesion(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      ref.invalidate(haySesionActivaProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
    } finally {
      if (mounted) setState(() => _iniciandoSesion = false);
    }
  }

  /// Fase 56 — a diferencia de `_iniciarSesion`, este método no deja la
  /// sesión activa al terminar: solo abre el navegador con la pantalla de
  /// Google. La sesión llega después, sola, por el deep link
  /// (`AuthRepository.iniciarSesionConGoogle`) — `RootScreen` navega al
  /// dashboard cuando eso pase, sin que esta pantalla tenga que esperarlo
  /// ni invalidar nada a mano.
  Future<void> _continuarConGoogle() async {
    setState(() => _iniciandoConGoogle = true);
    try {
      await ref.read(authRepositoryProvider).iniciarSesionConGoogle();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
    } finally {
      if (mounted) setState(() => _iniciandoConGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Finzo',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),
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
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (_esValido && !_iniciandoSesion)
                      ? _iniciarSesion
                      : null,
                  child: _iniciandoSesion
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _iniciandoConGoogle ? null : _continuarConGoogle,
                  icon: _iniciandoConGoogle
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onSurface,
                          ),
                        )
                      : const Icon(Icons.login),
                  label: const Text('Continuar con Google'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    final cuentaCreada = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (context) => const CrearCuentaScreen(),
                      ),
                    );
                    if (cuentaCreada == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Revisa tu correo para confirmar tu cuenta.',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
