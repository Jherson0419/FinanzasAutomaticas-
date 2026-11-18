import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/deuda.dart';
import '../../domain/recordatorios.dart';
import '../../domain/repositories/notificaciones_locales_repository.dart';
import '../../domain/usecases/sincronizar_recordatorios.dart';
import '../state/avance_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';

/// Explicación previa al diálogo de permiso del sistema (Fase 87).
const explicacionPermisoRecordatorios =
    'Para avisarte, Finzo necesita permiso para mostrar notificaciones. '
    'Los avisos se calculan en tu teléfono y, salvo que lo actives, no '
    'muestran montos.';

const textoPermisoDenegado =
    'Las notificaciones de Finzo están desactivadas en tu teléfono. '
    'Actívalas en Ajustes para recibir recordatorios.';

const preguntaOfrecimiento = '¿Quieres que te recordemos los vencimientos?';

const _dias = {
  DateTime.monday: 'Lunes',
  DateTime.tuesday: 'Martes',
  DateTime.wednesday: 'Miércoles',
  DateTime.thursday: 'Jueves',
  DateTime.friday: 'Viernes',
  DateTime.saturday: 'Sábado',
  DateTime.sunday: 'Domingo',
};

/// Si el permiso no está concedido: explica, y solo si aceptas, pide el
/// permiso del sistema. `true` si al final quedó concedido.
Future<bool> asegurarPermisoRecordatorios(
  BuildContext context,
  WidgetRef ref,
) async {
  final puerto = ref.read(notificacionesLocalesRepositoryProvider);
  if (await puerto.estadoPermiso() == EstadoPermisoNotificaciones.concedido) {
    return true;
  }
  if (!context.mounted) return false;
  final continuar = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Recordatorios'),
      content: const Text(explicacionPermisoRecordatorios),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(c).pop(false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(c).pop(true),
          child: const Text('Continuar'),
        ),
      ],
    ),
  );
  if (continuar != true) return false;
  return puerto.pedirPermiso();
}

/// Sincroniza YA con la configuración dada (también cuando todo queda
/// apagado: cancela lo programado).
Future<ResultadoSincronizacion> sincronizarRecordatoriosAhora(
  WidgetRef ref,
  ConfigRecordatorios config,
) async =>
    SincronizarRecordatorios(ref.read(notificacionesLocalesRepositoryProvider))(
      deudas: await ref.read(deudasProvider.future),
      cuentas: await ref.read(cuentasProvider.future),
      ahora: ref.read(ahoraAvanceProvider),
      config: config,
    );

/// Fase 87 — "Notificaciones" en Mi perfil: vencimientos, cobros, revisión
/// semanal (día y hora) y "Mostrar montos". Todo apagado de inicio; el
/// permiso se pide SOLO al activar una opción.
class SeccionNotificaciones extends ConsumerStatefulWidget {
  const SeccionNotificaciones({super.key});

  @override
  ConsumerState<SeccionNotificaciones> createState() =>
      _SeccionNotificacionesState();
}

class _SeccionNotificacionesState extends ConsumerState<SeccionNotificaciones> {
  bool _denegado = false;
  bool _ocupado = false;

  Future<void> _aplicar(
    ConfigRecordatorios nueva, {
    bool activa = false,
  }) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      if (activa && !await asegurarPermisoRecordatorios(context, ref)) {
        // Sin permiso, la opción queda apagada y se explica cómo activarlo.
        if (mounted) setState(() => _denegado = true);
        return;
      }
      if (mounted) setState(() => _denegado = false);
      await ref.read(configRecordatoriosProvider.notifier).guardar(nueva);
      final r = await sincronizarRecordatoriosAhora(ref, nueva);
      if (mounted) {
        setState(() => _denegado = r == ResultadoSincronizacion.sinPermiso);
      }
    } catch (_) {
      // El plugin no disponible (p. ej. web) no debe romper el perfil.
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = ref.watch(configRecordatoriosProvider);
    final hora = TimeOfDay(hour: c.horaRevision, minute: c.minutoRevision);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Notificaciones', style: theme.textTheme.titleSmall),
        ),
        const SizedBox(height: 4),
        Text(
          'Recordatorios que se calculan en tu teléfono. Todo está apagado '
          'hasta que actives algo.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
        if (_denegado) ...[
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(textoPermisoDenegado, style: theme.textTheme.bodyMedium),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => ref
                        .read(notificacionesLocalesRepositoryProvider)
                        .abrirAjustes(),
                    child: const Text('Abrir Ajustes'),
                  ),
                ),
              ],
            ),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vencimientos de cuotas y tarjetas'),
          subtitle: const Text('3 días antes y el mismo día, a las 9:00'),
          value: c.vencimientos,
          onChanged: _ocupado
              ? null
              : (v) => _aplicar(c.copyWith(vencimientos: v), activa: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Cobros'),
          subtitle: const Text(
            'El día en que vence lo que te deben. Solo te avisa a ti.',
          ),
          value: c.cobros,
          onChanged: _ocupado
              ? null
              : (v) => _aplicar(c.copyWith(cobros: v), activa: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Revisión semanal'),
          subtitle: Text(
            '${_dias[c.diaRevision]} a las ${hora.format(context)}',
          ),
          value: c.revisionSemanal,
          onChanged: _ocupado
              ? null
              : (v) => _aplicar(c.copyWith(revisionSemanal: v), activa: v),
        ),
        if (c.revisionSemanal)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<int>(
                    initialValue: c.diaRevision,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Día',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final MapEntry(:key, :value) in _dias.entries)
                        DropdownMenuItem(value: key, child: Text(value)),
                    ],
                    onChanged: _ocupado
                        ? null
                        : (d) => d == null
                              ? null
                              : _aplicar(c.copyWith(diaRevision: d)),
                  ),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _ocupado
                      ? null
                      : () async {
                          final elegida = await showTimePicker(
                            context: context,
                            initialTime: hora,
                          );
                          if (elegida == null) return;
                          await _aplicar(
                            c.copyWith(
                              horaRevision: elegida.hour,
                              minutoRevision: elegida.minute,
                            ),
                          );
                        },
                  icon: const Icon(Icons.schedule),
                  label: Text('Hora: ${hora.format(context)}'),
                ),
              ],
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar montos'),
          subtitle: const Text(
            'Si lo activas, los avisos dicen cuánto vence. Cualquiera que '
            'vea tu pantalla bloqueada podría leerlo.',
          ),
          value: c.mostrarMontos,
          onChanged: _ocupado
              ? null
              : (v) => _aplicar(c.copyWith(mostrarMontos: v)),
        ),
      ],
    );
  }
}

/// Fase 87 — después de tener tu primera deuda, el Inicio ofrece UNA vez
/// activar los recordatorios de vencimientos. Respondas lo que respondas,
/// no vuelve a preguntar.
class OfrecimientoRecordatorios extends ConsumerStatefulWidget {
  const OfrecimientoRecordatorios({super.key});

  @override
  ConsumerState<OfrecimientoRecordatorios> createState() =>
      _OfrecimientoRecordatoriosState();
}

class _OfrecimientoRecordatoriosState
    extends ConsumerState<OfrecimientoRecordatorios> {
  bool _denegado = false;

  Future<void> _responder(bool si) async {
    final notifier = ref.read(configRecordatoriosProvider.notifier);
    final actual = ref.read(configRecordatoriosProvider);
    if (si && await asegurarPermisoRecordatorios(context, ref)) {
      final nueva = actual.copyWith(
        vencimientos: true,
        ofrecimientoHecho: true,
      );
      await notifier.guardar(nueva);
      try {
        await sincronizarRecordatoriosAhora(ref, nueva);
      } catch (_) {}
      return;
    }
    if (si && mounted) setState(() => _denegado = true);
    await notifier.guardar(actual.copyWith(ofrecimientoHecho: true));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_denegado) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(textoPermisoDenegado, style: theme.textTheme.bodyMedium),
              Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => setState(() => _denegado = false),
                    child: const Text('Cerrar'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: () => ref
                        .read(notificacionesLocalesRepositoryProvider)
                        .abrirAjustes(),
                    child: const Text('Abrir Ajustes'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    final config = ref.watch(configRecordatoriosProvider);
    final deudas = ref.watch(deudasProvider).valueOrNull ?? const <Deuda>[];
    final tieneDeuda = deudas.any((d) => d.direccion == DireccionDeuda.debo);
    if (config.ofrecimientoHecho || config.vencimientos || !tieneDeuda) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_none, color: context.successText),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preguntaOfrecimiento,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Te avisamos 3 días antes y el mismo día, sin mostrar montos. '
              'Puedes cambiarlo en Mi perfil.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => _responder(false),
                  child: const Text('No, gracias'),
                ),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => _responder(true),
                  child: const Text('Sí, avisarme'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Invisible: mantiene los recordatorios al día mientras el Inicio está
/// visible (al abrir la app y tras cambios en las deudas).
class SincronizadorRecordatorios extends ConsumerWidget {
  const SincronizadorRecordatorios({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sincronizacionRecordatoriosProvider);
    return const SizedBox.shrink();
  }
}
