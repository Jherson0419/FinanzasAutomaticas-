import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import 'crear_cuenta_screen.dart';
import 'olvide_contrasena_screen.dart';

final _regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Rediseño estilo "Flow" (Fase 65): logo circular, subtítulo, "Recuérdame"
/// (B.2) y "¿Olvidaste tu contraseña?" (B.3) junto al botón de login, un
/// solo botón de continuar con proveedor externo (Google — Apple no aplica
/// aquí). Sistema de diseño de la Fase 19/31 (`Theme.of(context)`, sin
/// colores sueltos fuera de sus tokens).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _recuerdame = true;
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

  /// Fase 65 (B.2) — "Recuérdame": la preferencia se guarda siempre (no
  /// solo cuando queda desmarcada), para que volver a marcar el checkbox en
  /// un login posterior también revierta un `false` guardado antes; sin
  /// esto, el checkbox nunca podría "recuperar" la sesión persistente una
  /// vez desactivado. Solo se guarda tras un login exitoso — un intento
  /// fallido no debe tocar la preferencia.
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
      await ref
          .read(preferenciasRepositoryProvider)
          .guardarRecordarSesion(_recuerdame);
      // Fase 71 — recién ahora, con la sesión ya confirmada, tiene sentido
      // pedir permiso de notificaciones (nunca antes de que el usuario
      // entienda para qué es). `try/catch` propio, separado del de más
      // abajo: registrar el token es secundario y nunca debe mostrarse
      // como si el login hubiera fallado, ni impedir el
      // `ref.invalidate` de la línea siguiente.
      try {
        await ref.read(registrarTokenDispositivoProvider).call();
      } catch (_) {}
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

  void _abrirOlvideContrasena() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OlvideContrasenaScreen()),
    );
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
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 38,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Finzo',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tus finanzas, en un solo lugar',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
                const SizedBox(height: 4),
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.9,
                      child: Checkbox(
                        value: _recuerdame,
                        onChanged: (valor) =>
                            setState(() => _recuerdame = valor ?? true),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _recuerdame = !_recuerdame),
                      child: const Text('Recuérdame'),
                    ),
                    const Spacer(),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _abrirOlvideContrasena,
                      child: const Text('¿Olvidaste tu contraseña?'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o continúa con',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(color: theme.colorScheme.outlineVariant),
                    ),
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿Nuevo aquí? ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () async {
                        final cuentaCreada = await Navigator.of(
                          context,
                        ).push<bool>(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
