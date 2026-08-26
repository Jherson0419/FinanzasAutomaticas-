import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/amistad.dart';
import '../shared/mensajes_error.dart';
import '../shared/selector_avatar.dart';
import '../state/providers.dart';
import 'agregar_amigo_screen.dart';

/// "Mis amigos" (Fase 63) — accesible desde `MiPerfilScreen`. Dos
/// secciones: solicitudes recibidas pendientes (Aceptar/Rechazar) y la
/// lista de amigos ya aceptados. El botón "+" del `AppBar` abre
/// `AgregarAmigoScreen` para buscar y enviar una solicitud nueva.
class MisAmigosScreen extends ConsumerWidget {
  const MisAmigosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solicitudesAsync = ref.watch(solicitudesRecibidasProvider);
    final amigosAsync = ref.watch(amigosProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis amigos'),
        actions: [
          IconButton(
            tooltip: 'Agregar amigo',
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (context) => const AgregarAmigoScreen(),
                ),
              );
              ref.invalidate(solicitudesRecibidasProvider);
              ref.invalidate(amigosProvider);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Solicitudes recibidas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            solicitudesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text(
                'No se pudieron cargar las solicitudes.\n$error',
              ),
              data: (solicitudes) => solicitudes.isEmpty
                  ? Text(
                      'No tienes solicitudes pendientes.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      children: [
                        for (final solicitud in solicitudes)
                          _FilaSolicitud(solicitud: solicitud),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text('Mis amigos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            amigosAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  Text('No se pudieron cargar tus amigos.\n$error'),
              data: (amigos) => amigos.isEmpty
                  ? Text(
                      'Todavía no tienes amigos agregados.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Column(
                      children: [
                        for (final amigo in amigos) _FilaAmigo(perfil: amigo),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaSolicitud extends ConsumerStatefulWidget {
  const _FilaSolicitud({required this.solicitud});

  final SolicitudRecibida solicitud;

  @override
  ConsumerState<_FilaSolicitud> createState() => _FilaSolicitudState();
}

class _FilaSolicitudState extends ConsumerState<_FilaSolicitud> {
  bool _procesando = false;

  Future<void> _responder(bool aceptar) async {
    setState(() => _procesando = true);
    try {
      final repo = ref.read(amistadRepositoryProvider);
      if (aceptar) {
        await repo.aceptarSolicitud(widget.solicitud.solicitudId);
      } else {
        await repo.rechazarSolicitud(widget.solicitud.solicitudId);
      }
      ref.invalidate(solicitudesRecibidasProvider);
      ref.invalidate(amigosProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(aceptar ? 'Solicitud aceptada' : 'Solicitud rechazada')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo responder: ${mensajeDeError(error)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = widget.solicitud.deQuien;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AvatarCirculo(avatarId: perfil.avatarId, tamano: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              perfil.nick != null ? '@${perfil.nick}' : 'Sin nick',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (_procesando)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              tooltip: 'Aceptar',
              icon: const Icon(Icons.check_circle_outline),
              onPressed: () => _responder(true),
            ),
            IconButton(
              tooltip: 'Rechazar',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => _responder(false),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilaAmigo extends StatelessWidget {
  const _FilaAmigo({required this.perfil});

  final PerfilPublico perfil;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AvatarCirculo(avatarId: perfil.avatarId, tamano: 40),
          const SizedBox(width: 12),
          Text(
            perfil.nick != null ? '@${perfil.nick}' : 'Sin nick',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
