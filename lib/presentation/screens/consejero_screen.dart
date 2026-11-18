import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/consejero.dart';
import '../shared/app_card.dart';
import '../shared/formatters.dart';
import '../state/consejero_providers.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'transferencia_screen.dart';

/// Navega a la acción de un consejo. Las rutas de transferencia reciben
/// sus argumentos tipados (el dominio no conoce la UI y manda un mapa).
Future<void> abrirAccionConsejo(
  BuildContext context,
  WidgetRef ref,
  AccionConsejo accion,
) async {
  var argumentos = accion.argumentos;
  if (accion.ruta == '/transferencias/nueva' && argumentos is Map) {
    argumentos = TransferenciaRouteArgs(
      destinoId: argumentos['destinoId'] as String?,
      montoSugerido: argumentos['monto'] as double?,
    );
  }
  await Navigator.of(context).pushNamed(accion.ruta, arguments: argumentos);
  // Lo que hayas hecho allá puede cambiar los consejos.
  ref.invalidate(deudasProvider);
  ref.invalidate(cuentasProvider);
  ref.invalidate(todasLasTransaccionesProvider);
  ref.invalidate(pagosDeTodasLasDeudasProvider);
  ref.invalidate(resumenDashboardProvider);
}

/// Fase 86 — "Tu consejero" (13-consejero.png): revisión semanal y hasta 3
/// consejos de reglas locales (sin IA ni red), cada uno descartable o
/// posponible 7 días; el resto en "Ver más".
class ConsejeroScreen extends ConsumerStatefulWidget {
  const ConsejeroScreen({super.key});

  @override
  ConsumerState<ConsejeroScreen> createState() => _ConsejeroScreenState();
}

class _ConsejeroScreenState extends ConsumerState<ConsejeroScreen> {
  bool _verMas = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ahora = ref.watch(ahoraConsejeroProvider);
    final contexto = ref.watch(contextoConsejeroProvider);
    final visibles = ref.watch(consejosVisiblesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tu consejero'),
            Text(
              'Revisión de la semana · ${formatearFechaLarga(ahora)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch ((contexto, visibles)) {
          (AsyncData(value: final ctx), AsyncData(value: final v)) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _Revision(revision: revisionSemanal(ctx), ahora: ahora),
              const SizedBox(height: 16),
              if (v.vacio)
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No tengo consejos nuevos para ti por ahora. Vuelve '
                    'cuando registres más movimientos.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              else ...[
                for (final c in v.principales) ...[
                  _TarjetaConsejo(consejo: c),
                  const SizedBox(height: 12),
                ],
                if (v.mas.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => setState(() => _verMas = !_verMas),
                      child: Text(
                        _verMas ? 'Ver menos' : 'Ver más (${v.mas.length})',
                      ),
                    ),
                  ),
                if (_verMas)
                  for (final c in v.mas) ...[
                    _TarjetaConsejo(consejo: c),
                    const SizedBox(height: 12),
                  ],
              ],
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(context).pushNamed('/plan-pago'),
                child: const Text('Ver mi plan'),
              ),
              const SizedBox(height: 16),
              Text(
                pieConsejero,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
          (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
            Center(child: Text('No se pudieron revisar tus datos.\n$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _Revision extends StatelessWidget {
  const _Revision({required this.revision, required this.ahora});

  final RevisionSemanal revision;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = revision.moneda;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tus últimos 7 días',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pagaste ${formatearMonto(revision.pagadoADeudas, m)} a tus '
            'deudas, gastaste ${formatearMonto(revision.gastado, m)} y '
            'recibiste ${formatearMonto(revision.ingresos, m)}.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Text(
            'Próximos 7 días',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          if (revision.proximos.isEmpty)
            Text(
              'No vence nada esta semana.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final v in revision.proximos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  '${v.deuda.nombreDeuda}: '
                  '${v.monto == null ? '' : '${formatearMonto(v.monto!, v.deuda.moneda)}, '}'
                  'vence ${formatearDiaRelativo(v.fecha, ahora: ahora).toLowerCase()}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
        ],
      ),
    );
  }
}

class _TarjetaConsejo extends ConsumerWidget {
  const _TarjetaConsejo({required this.consejo});

  final Consejo consejo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accion = consejo.accion;
    final notifier = ref.read(estadosConsejeroProvider.notifier);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    consejo.titulo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(consejo.texto, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (accion != null)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: context.successText,
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => abrirAccionConsejo(context, ref, accion),
                  child: Text(accion.etiqueta),
                ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => notifier.posponer(consejo),
                child: Text(
                  'Posponer 7 días',
                  semanticsLabel: 'Posponer 7 días: ${consejo.titulo}',
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => notifier.descartar(consejo),
                child: Text(
                  'Descartar',
                  semanticsLabel: 'Descartar: ${consejo.titulo}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Fase 86 (E) — línea compacta del Inicio con el consejo de mayor
/// prioridad; lleva al consejero. Sin consejos (o sin datos) no ocupa nada.
class ConsejoDestacadoLinea extends ConsumerWidget {
  const ConsejoDestacadoLinea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consejo = ref
        .watch(consejosVisiblesProvider)
        .valueOrNull
        ?.principales
        .firstOrNull;
    if (consejo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Consejo: ${consejo.titulo}. Abrir tu consejero.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pushNamed('/consejero'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: context.successText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      consejo.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.textSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
