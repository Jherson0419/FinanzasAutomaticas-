import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/mensajes_error.dart';
import '../state/providers.dart';

final _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Paso 1 de "¿Olvidaste tu contraseña?" (Fase 65) — pide el correo y envía
/// el link de recuperación (`AuthRepository.enviarLinkRecuperacion`, que
/// internamente usa `resetPasswordForEmail` con `redirectTo:
/// finzo://reset-password`). El paso 2 (`NuevaContrasenaScreen`) se abre
/// solo cuando ese link llega y `supabase_flutter` arma la sesión de
/// recuperación (`app.dart`) — esta pantalla no navega a él directamente.
class OlvideContrasenaScreen extends ConsumerStatefulWidget {
  const OlvideContrasenaScreen({super.key});

  @override
  ConsumerState<OlvideContrasenaScreen> createState() =>
      _OlvideContrasenaScreenState();
}

class _OlvideContrasenaScreenState
    extends ConsumerState<OlvideContrasenaScreen> {
  final _emailController = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _esValido => _regexEmail.hasMatch(_emailController.text.trim());

  Future<void> _enviar() async {
    if (!_esValido) return;

    setState(() => _enviando = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .enviarLinkRecuperacion(email: _emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Revisa tu correo para continuar.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeDeError(error))));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ingresa tu correo y te enviaremos un link para elegir una '
                'contraseña nueva.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_esValido && !_enviando) ? _enviar : null,
                child: _enviando
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.onPrimary,
                        ),
                      )
                    : const Text('Enviar link de recuperación'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
