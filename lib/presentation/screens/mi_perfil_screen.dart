import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../domain/entities/perfil.dart';
import '../../domain/entities/tema_app.dart';
import '../shared/app_bottom_bar.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/mensajes_error.dart';
import '../shared/selector_avatar.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Formato básico de celular: dígitos opcionalmente precedidos de `+`,
/// entre 7 y 15 dígitos (rango E.164) — se valida después de quitar
/// espacios/guiones que el usuario haya tecleado para separar visualmente.
final _regexCelular = RegExp(r'^\+?[0-9]{7,15}$');

/// Ajustes de perfil: nombre e Instagram (Fase 31), nombre completo/
/// celular/otra red social y foto real de avatar (Fase 56) del usuario —
/// el nombre corto se guarda solo en este dispositivo vía
/// `PreferenciasRepository` (`shared_preferences`); todo lo demás vive en
/// `usuarios` (Supabase) vía `PerfilRepository`. El nick, en cambio, es de
/// solo lectura aquí (decisión de la Fase 31, ver `_construirCampos`).
///
/// Fase 24: ya no pide una API key de Gemini — `consejos_financieros_
/// screen.dart` usa la Edge Function `generar-consejos`, con una API key
/// del distribuidor de la app que nunca llega a este dispositivo.
class MiPerfilScreen extends ConsumerStatefulWidget {
  const MiPerfilScreen({super.key});

  @override
  ConsumerState<MiPerfilScreen> createState() => _MiPerfilScreenState();
}

class _MiPerfilScreenState extends ConsumerState<MiPerfilScreen> {
  final _nombreController = TextEditingController();
  final _instagramController = TextEditingController();
  final _nombreCompletoController = TextEditingController();
  final _celularController = TextEditingController();
  final _otraRedSocialController = TextEditingController();
  bool _guardando = false;
  bool _cerrandoSesion = false;
  bool _eliminandoCuenta = false;
  bool _cambiandoAvatar = false;
  bool _valoresPrecargados = false;

  bool get _celularValido {
    final texto = _celularController.text.trim();
    if (texto.isEmpty) return true; // opcional
    return _regexCelular.hasMatch(texto.replaceAll(RegExp(r'[\s\-]'), ''));
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _instagramController.dispose();
    _nombreCompletoController.dispose();
    _celularController.dispose();
    _otraRedSocialController.dispose();
    super.dispose();
  }

  void _precargar(String? nombre, Perfil perfil) {
    if (_valoresPrecargados) return;
    _valoresPrecargados = true;
    _nombreController.text = nombre ?? '';
    _instagramController.text = perfil.instagram ?? '';
    _nombreCompletoController.text = perfil.nombreCompleto ?? '';
    _celularController.text = perfil.celular ?? '';
    _otraRedSocialController.text = perfil.otraRedSocial ?? '';
  }

  Future<void> _guardar() async {
    if (!_celularValido) return;

    setState(() => _guardando = true);
    try {
      final preferencias = ref.read(preferenciasRepositoryProvider);
      await preferencias.guardarNombre(_nombreController.text.trim());

      final perfilRepo = ref.read(perfilRepositoryProvider);
      final instagram = _instagramController.text.trim();
      final nombreCompleto = _nombreCompletoController.text.trim();
      final celular = _celularController.text.trim();
      final otraRedSocial = _otraRedSocialController.text.trim();
      await perfilRepo.guardarInstagram(instagram.isEmpty ? null : instagram);
      await perfilRepo.guardarNombreCompleto(
        nombreCompleto.isEmpty ? null : nombreCompleto,
      );
      await perfilRepo.guardarCelular(celular.isEmpty ? null : celular);
      await perfilRepo.guardarOtraRedSocial(
        otraRedSocial.isEmpty ? null : otraRedSocial,
      );

      ref.invalidate(nombreUsuarioProvider);
      ref.invalidate(perfilProvider);
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

  /// Fase 56: reemplaza el selector de avatares prediseñados por una foto
  /// real — abre la galería, la sube a Supabase Storage (bucket
  /// `avatares`, SQL en el reporte de esta fase) y guarda la URL pública
  /// resultante en `usuarios.avatar_id` (mismo campo, significado nuevo).
  /// `maxWidth`/`maxHeight`/`imageQuality` limitan el tamaño de archivo sin
  /// necesitar un paquete aparte para recortar — como `AvatarCirculo` ya
  /// muestra la imagen con `BoxFit.cover` dentro de un círculo, una foto
  /// no cuadrada igual se ve bien, sin recorte exacto a cuadrado.
  Future<void> _cambiarAvatar() async {
    final XFile? foto;
    try {
      foto = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir la galería: ${mensajeDeError(error)}'),
        ),
      );
      return;
    }
    if (foto == null) return; // el usuario cerró el selector sin elegir nada
    if (!mounted) return;

    setState(() => _cambiandoAvatar = true);
    try {
      final bytes = await foto.readAsBytes();
      final extension = _extensionDeFoto(foto.path);
      final perfilRepo = ref.read(perfilRepositoryProvider);
      final url = await perfilRepo.subirFotoAvatar(bytes, extension: extension);
      await perfilRepo.guardarAvatarId(url);
      ref.invalidate(perfilProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _cambiandoAvatar = false);
    }
  }

  String _extensionDeFoto(String path) {
    final partes = path.split('.');
    if (partes.length < 2) return 'jpg';
    final extension = partes.last.toLowerCase();
    const validas = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    return validas.contains(extension) ? extension : 'jpg';
  }

  Future<void> _cambiarTema(TemaApp tema) async {
    try {
      await ref.read(preferenciasRepositoryProvider).guardarTema(tema);
      ref.invalidate(temaProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
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
  ///
  /// Fase 23.2 — `EliminarCuentaDeUsuario.call` acepta `onProgreso(etapa)`
  /// con 6 mensajes descriptivos; se conecta a un diálogo de progreso no
  /// descartable (mismo espíritu que `MigrarDatosScreen`, que muestra la
  /// etapa actual de una operación igual de larga en vez de un spinner
  /// genérico) en lugar de solo deshabilitar el botón.
  Future<void> _eliminarCuenta() async {
    final confirmado = await confirmarEliminarCuenta(context);
    if (!confirmado) return;
    if (!mounted) return;

    final etapaActual = ValueNotifier<String>('Preparando...');
    setState(() => _eliminandoCuenta = true);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            _DialogoProgresoEliminarCuenta(etapaActual: etapaActual),
      ),
    );

    try {
      await ref
          .read(eliminarCuentaDeUsuarioProvider)
          .call(onProgreso: (etapa) => etapaActual.value = etapa);
      await ref.read(preferenciasRepositoryProvider).limpiarTodo();
      ref.invalidate(haySesionActivaProvider);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cierra el diálogo
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // cierra el diálogo
      await mostrarErrorEliminar(context, error);
    } finally {
      etapaActual.dispose();
      if (mounted) setState(() => _eliminandoCuenta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombreAsync = ref.watch(nombreUsuarioProvider);
    final perfilAsync = ref.watch(perfilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.perfil),
      body: SafeArea(
        child: nombreAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('No se pudo cargar el perfil.\n$error')),
          data: (nombre) => perfilAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('No se pudo cargar el perfil.\n$error')),
            data: (perfil) {
              _precargar(nombre, perfil);
              return _construirCampos(context, perfil);
            },
          ),
        ),
      ),
    );
  }

  Widget _construirCampos(BuildContext context, Perfil perfil) {
    final theme = Theme.of(context);
    final tema = ref.watch(temaProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: GestureDetector(
            onTap: _cambiandoAvatar ? null : _cambiarAvatar,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AvatarCirculo(avatarId: perfil.avatarId, tamano: 88),
                if (_cambiandoAvatar)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.bgCard,
                        border: Border.all(color: context.borderCard),
                      ),
                      child: Icon(
                        Icons.edit,
                        size: 14,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            perfil.nick != null ? '@${perfil.nick}' : 'Sin nick',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (perfil.nick != null)
          Center(
            child: Text(
              // El nick es de solo lectura después del onboarding — así un
              // futuro sistema social siempre puede encontrar a alguien por
              // el mismo nick que usó desde el principio (ver Fase 31).
              'El nick no se puede cambiar',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textMuted,
              ),
            ),
          ),
        const SizedBox(height: 28),
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nombreCompletoController,
          decoration: const InputDecoration(
            labelText: 'Nombre completo (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _celularController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Celular (opcional)',
            hintText: '+51 987654321',
            border: const OutlineInputBorder(),
            errorText: _celularValido ? null : 'Formato de celular inválido',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _instagramController,
          decoration: const InputDecoration(
            labelText: 'Instagram (opcional)',
            hintText: '@usuario',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _otraRedSocialController,
          decoration: const InputDecoration(
            labelText: 'Otra red social (opcional)',
            hintText: 'p. ej. tu usuario de TikTok o X',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: (_guardando || !_celularValido) ? null : _guardar,
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
        const SizedBox(height: 16),
        Text('Apariencia', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        SegmentedButton<TemaApp>(
          segments: const [
            ButtonSegment(
              value: TemaApp.claro,
              label: Text('Claro'),
              icon: Icon(Icons.light_mode_outlined),
            ),
            ButtonSegment(
              value: TemaApp.oscuro,
              label: Text('Oscuro'),
              icon: Icon(Icons.dark_mode_outlined),
            ),
            ButtonSegment(
              value: TemaApp.sistema,
              label: Text('Sistema'),
              icon: Icon(Icons.brightness_auto_outlined),
            ),
          ],
          selected: {tema},
          onSelectionChanged: (seleccion) => _cambiarTema(seleccion.first),
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
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.bolt_outlined),
          title: const Text('Automatización'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).pushNamed('/automatizacion'),
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
            foregroundColor: colorSobreEstado,
          ),
          onPressed: _eliminandoCuenta ? null : _eliminarCuenta,
          icon: _eliminandoCuenta
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorSobreEstado,
                  ),
                )
              : const Icon(Icons.delete_forever),
          label: const Text('Eliminar mi cuenta'),
        ),
      ],
    );
  }
}

/// Progreso de `EliminarCuentaDeUsuario` (Fase 23.2) — no descartable
/// (`PopScope(canPop: false)`, sin botón de cerrar): es una operación
/// destructiva e idempotente por diseño, así que no tiene sentido dejar
/// cancelarla a mitad de camino; el progreso es solo informativo.
class _DialogoProgresoEliminarCuenta extends StatelessWidget {
  const _DialogoProgresoEliminarCuenta({required this.etapaActual});

  final ValueListenable<String> etapaActual;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Eliminando tu cuenta'),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: etapaActual,
                builder: (context, etapa, _) => Text(etapa),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
