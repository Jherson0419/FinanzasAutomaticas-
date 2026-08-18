import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/app_bottom_bar.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/mensajes_error.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Ajustes de perfil: nombre del usuario y la API key de Gemini usada por
/// `consejos_financieros_screen.dart`. Ambos se guardan solo en este
/// dispositivo vía `PreferenciasRepository` (`shared_preferences`).
class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  ConsumerState<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends ConsumerState<MiPerfilScreen> {
  final _nombreController = TextEditingController();
  final _apiKeyController = TextEditingController();
  bool _apiKeyVisible = false;
  bool _guardando = false;
  bool _cerrandoSesion = false;
  bool _eliminandoCuenta = false;
  bool _valoresPrecargados = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _precargar(String? nombre, String? apiKey) {
    if (_valoresPrecargados) return;
    _valoresPrecargados = true;
    _nombreController.text = nombre ?? '';
    _apiKeyController.text = apiKey ?? '';
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final preferencias = ref.read(preferenciasRepositoryProvider);
      await preferencias.guardarNombre(_nombreController.text.trim());
      await preferencias.guardarApiKeyGemini(_apiKeyController.text.trim());
      ref.invalidate(nombreUsuarioProvider);
      ref.invalidate(apiKeyGeminiProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    final confirmado = await confirmarAccion(
      context,
      titulo: 'Cerrar sesión',
      mensaje:
          '¿Cerrar sesión? Tus datos financieros no se borran de este '
          'dispositivo, solo se cierra tu sesión.',
      textoConfirmar: 'Cerrar sesión',
    );
    if (!confirmado) return;
    if (!mounted) return;

    setState(() => _cerrandoSesion = true);
    try {
      await ref.read(authRepositoryProvider).cerrarSesion();
      ref.invalidate(haySesionActivaProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar sesión: ${mensajeDeError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _cerrandoSesion = false);
    }
  }

  /// Fase 22 — requisito de Apple (Guideline 5.1.1(v)): toda app que deja
  /// crear una cuenta debe dejar borrarla, no solo cerrar sesión.
  /// `EliminarCuentaDeUsuario` borra los datos financieros y la cuenta de
  /// autenticación; solo si eso termina sin errores se limpian las
  /// preferencias locales y se navega al login. Si falla a mitad de
  /// camino, no se toca nada local y el usuario puede volver a intentar
  /// de inmediato — reintentar es seguro: el caso de uso solo borra lo
  /// que todavía exista, así que un segundo intento nunca falla por
  /// encontrar registros ya borrados.
  Future<void> _eliminarCuenta() async {
    final confirmado = await confirmarEliminarCuenta(context);
    if (!confirmado) return;
    if (!mounted) return;

    setState(() => _eliminandoCuenta = true);
    try {
      await ref.read(eliminarCuentaDeUsuarioProvider).call();
      await ref.read(preferenciasRepositoryProvider).limpiarTodo();
      ref.invalidate(haySesionActivaProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      await mostrarErrorEliminar(context, error);
    } finally {
      if (mounted) setState(() => _eliminandoCuenta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreAsync = ref.watch(nombreUsuarioProvider);
    final apiKeyAsync = ref.watch(apiKeyGeminiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.perfil),
      body: SafeArea(
        child: nombreAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('No se pudo cargar el perfil.\n$error')),
          data: (nombre) => apiKeyAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('No se pudo cargar el perfil.\n$error')),
            data: (apiKey) {
              _precargar(nombre, apiKey);
              return _construirCampos(context);
            },
          ),
        ),
      ),
    );
  }

  Widget _construirCampos(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 28),
        Text('Consejos financieros con IA', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        TextFormField(
          controller: _apiKeyController,
          obscureText: !_apiKeyVisible,
          decoration: InputDecoration(
            labelText: 'API key de Gemini',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: _apiKeyVisible ? 'Ocultar' : 'Mostrar',
              icon: Icon(
                _apiKeyVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _apiKeyVisible = !_apiKeyVisible),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Se guarda solo en este dispositivo. Consíguela gratis en '
          'ai.google.dev.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
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
        const SizedBox(height: 32),
        const Divider(),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.category_outlined),
          title: const Text('Mis categorías'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed('/categorias'),
        ),
        const Divider(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _cerrandoSesion ? null : _cerrarSesion,
          icon: _cerrandoSesion
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onSurface,
                  ),
                )
              : const Icon(Icons.logout),
          label: const Text('Cerrar sesión'),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        Text(
          'Zona de peligro',
          style: theme.textTheme.titleSmall?.copyWith(color: colorDanger),
        ),
        const SizedBox(height: 8),
        Text(
          'Elimina tu cuenta y todos tus datos financieros de forma '
          'permanente. Esta acción no se puede deshacer.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: colorDanger,
            foregroundColor: bgPage,
          ),
          onPressed: _eliminandoCuenta ? null : _eliminarCuenta,
          icon: _eliminandoCuenta
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: bgPage,
                  ),
                )
              : const Icon(Icons.delete_forever),
          label: const Text('Eliminar mi cuenta'),
        ),
      ],
    );
  }
}
