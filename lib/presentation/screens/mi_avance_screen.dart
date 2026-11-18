import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/avance.dart';
import '../../domain/hitos.dart';
import '../shared/app_card.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import '../state/avance_providers.dart';
import '../state/plan_pago_providers.dart';
import '../theme/app_theme.dart';

/// Nota fija sobre el porcentaje (puede bajar con una deuda nueva).
const notaPorcentajeAvance =
    'Si registras una deuda nueva, este porcentaje puede bajar. Lo que ya '
    'pagaste no baja nunca.';

/// Fase 87 — "Mi avance" (14-hitos.png). Dato principal: lo que has
/// pagado (siempre crece). Luego el porcentaje, la racha, los hitos y la
/// estimación de libertad del plan.
class MiAvanceScreen extends ConsumerWidget {
  const MiAvanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avance = ref.watch(avanceProvider);
    // Evalúa (y guarda) hitos al abrir la pantalla.
    ref.watch(evaluacionHitosProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi avance')),
      body: SafeArea(
        child: avance.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('No se pudo calcular tu avance.\n$e')),
          data: (a) => _Contenido(avance: a),
        ),
      ),
    );
  }
}

class _Contenido extends ConsumerWidget {
  const _Contenido({required this.avance});

  final Avance avance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final m = avance.moneda;
    final hitos = ref.watch(hitosProvider);
    final fechaLibre = ref.watch(fechaLibrePlanProvider);
    final muted = TextStyle(
      color: context.heroMuted,
      fontWeight: FontWeight.w600,
    );
    const t = AppColorTokens.oscuro;
    final p = avance.pagado;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const CelebracionHito(),
        if (avance.sinDatos)
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Cuando registres una deuda y tus pagos, aquí verás cuánto '
              'llevas pagado y tus logros.',
              style: theme.textTheme.bodyMedium,
            ),
          )
        else ...[
          Semantics(
            container: true,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.heroBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Has pagado', style: muted),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${formatearMonto(p.total, m)} en deudas',
                      style: estiloMonto(
                        TextStyle(
                          color: context.heroText,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    [
                      if (p.capital > 0)
                        'Capital ${formatearMonto(p.capital, m)}',
                      if (p.interes > 0)
                        'Interés ${formatearMonto(p.interes, m)}',
                      if (p.sinDesglose > 0)
                        'Sin desglose ${formatearMonto(p.sinDesglose, m)}',
                    ].join(' · '),
                    style: muted.copyWith(color: t.successText),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (avance.porcentaje != null)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Llevas el ${avance.porcentaje} % de tus deudas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: avance.fraccion,
                        minHeight: 10,
                        backgroundColor: context.borderCard,
                        color: context.brandAction,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${formatearMonto(avance.pagadoDeTotal, m)} de '
                    '${formatearMonto(avance.totalDeudas, m)} '
                    '(sin tarjetas)',
                    style: estiloMonto(theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notaPorcentajeAvance,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Dato(
                titulo: 'Pagos a tiempo',
                valor: avance.racha.actual == 1
                    ? '1 mes'
                    : '${avance.racha.actual} meses',
                detalle:
                    'Tu mejor racha: ${avance.racha.mejor == 1 ? '1 mes' : '${avance.racha.mejor} meses'}',
              ),
              if (avance.tarjetas case final tj?)
                _Dato(
                  titulo: 'Uso de tarjetas',
                  valor: formatearMonto(tj.usado, m),
                  detalle: 'de ${formatearMonto(tj.linea, m)} de línea',
                ),
            ],
          ),
          if (fechaLibre != null) ...[
            const SizedBox(height: 12),
            Text(
              'Según tu plan, quedas libre de deudas en '
              '${formatearMesAnio(fechaLibre)} (aprox.)',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ],
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            'HITOS',
            style: theme.textTheme.labelLarge?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
        ),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              for (final hito in Hito.values)
                _FilaHito(hito: hito, logrado: hitos[hito]),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => Navigator.of(context).pushNamed('/consejero'),
                child: const Text('Mi consejero'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(context).pushNamed('/plan-pago'),
                child: const Text('Ver mi plan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.titulo, required this.valor, this.detalle});

  final String titulo;
  final String valor;
  final String? detalle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                titulo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              Text(
                valor,
                style: estiloMonto(
                  theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (detalle != null)
                Text(detalle!, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un hito: logrado (✓ + "Logrado el …") o por lograr (círculo vacío +
/// "Por lograr"). El estado se dice con ícono Y texto, nunca solo color.
class _FilaHito extends StatelessWidget {
  const _FilaHito({required this.hito, required this.logrado});

  final Hito hito;
  final HitoLogrado? logrado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hecho = logrado != null;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                color: hecho ? context.successText : context.textSecondary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tituloHito(hito),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hecho
                          ? 'Logrado el ${formatearFecha(logrado!.fecha)}'
                          : 'Por lograr · ${descripcionHito(hito)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fase 87 — celebración sobria de un hito: una tarjeta con texto, sin
/// animación (respeta "reducir movimiento" por diseño), una a la vez.
/// "Entendido" la marca como celebrada y nunca vuelve.
class CelebracionHito extends ConsumerWidget {
  const CelebracionHito({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Evalúa con los datos actuales (si fallan, simplemente no muestra
    // nada).
    ref.watch(evaluacionHitosProvider);
    final hito = siguienteACelebrar(ref.watch(hitosProvider));
    if (hito == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
          decoration: BoxDecoration(
            color: context.successBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.emoji_events_outlined, color: context.successText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Logro: ${tituloHito(hito.hito)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: context.successText,
                          ),
                        ),
                        Text(
                          descripcionHito(hito.hito),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => ref
                      .read(hitosProvider.notifier)
                      .marcarCelebrado(hito.hito),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
