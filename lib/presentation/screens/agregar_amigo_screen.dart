import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/amistad.dart';
import '../shared/mensajes_error.dart';
import '../shared/selector_avatar.dart';
import '../state/providers.dart';

/// Buscar un usuario por nick y enviarle una solicitud de amistad (Fase 63).
/// Accesible desde `MisAmigosScreen` (botón "+" en el `AppBar`) o, desde la
/// Fase 64, abierta directo por el deep link `finzo://agregar-amigo?nick=`
/// que genera "Compartir mi perfil" en `MiPerfilScreen` — en ese caso
/// [nickInicial] llega prellenado y la búsqueda se dispara sola al abrir,
/// para que solo falte un toque en "Enviar solicitud" (nunca se envía sola:
/// eso siempre requiere ese toque explícito del usuario).
class AgregarAmigoScreen extends ConsumerStatefulWidget {
  const AgregarAmigoScreen({super.key, this.nickInicial});

  final String? nickInicial;

  @override
  ConsumerState<AgregarAmigoScreen> createState() =>
      _AgregarAmigoScreenState();
}

class _AgregarAmigoScreenState extends ConsumerState<AgregarAmigoScreen> {
  final _nickController = TextEditingController();
  bool _buscando = false;
  bool _enviando = false;
  bool _yaBusco = false;
  PerfilPublico? _resultado;

  @override
  void initState() {
    super.initState();
    final nickInicial = widget.nickInicial;
    if (nickInicial != null && nickInicial.isNotEmpty) {
      _nickController.text = nickInicial;
      _buscar();
    }
  }

  @override
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final nick = _nickController.text.trim();
    if (nick.isEmpty) return;

    setState(() {
      _buscando = true;
      _yaBusco = true;
      _resultado = null;
    });
    try {
      final resultado = await ref
          .read(amistadRepositoryProvider)
          .buscarPorNick(nick);
      if (!mounted) return;
      setState(() => _resultado = resultado);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo buscar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _enviarSolicitud() async {
    final resultado = _resultado;
    if (resultado == null) return;

    setState(() => _enviando = true);
    try {
      await ref
          .read(amistadRepositoryProvider)
          .enviarSolicitud(resultado.usuarioId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Solicitud enviada')));
      setState(() {
        _resultado = null;
        _yaBusco = false;
      });
      _nickController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar: ${mensajeDeError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar amigo')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nickController,
                decoration: const InputDecoration(
                  labelText: 'Nick de tu amigo',
                  hintText: 'p. ej. jherson23',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) => _buscar(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _buscando ? null : _buscar,
                child: _buscando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Buscar'),
              ),
              const SizedBox(height: 24),
              if (_yaBusco && !_buscando)
                _resultado == null
                    ? Text(
                        'No se encontró ningún usuario con ese nick.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    : _TarjetaResultado(
                        perfil: _resultado!,
                        enviando: _enviando,
                        onEnviar: _enviarSolicitud,
                      ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaResultado extends StatelessWidget {
  const _TarjetaResultado({
    required this.perfil,
    required this.enviando,
    required this.onEnviar,
  });

  final PerfilPublico perfil;
  final bool enviando;
  final VoidCallback onEnviar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        AvatarCirculo(avatarId: perfil.avatarId, tamano: 48),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            perfil.nick != null ? '@${perfil.nick}' : 'Sin nick',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        FilledButton(
          onPressed: enviando ? null : onEnviar,
          child: enviando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}
