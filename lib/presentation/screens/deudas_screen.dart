import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/proximos_pagos.dart';
import '../../domain/usecases/dto/resumen_dashboard.dart';
import '../shared/app_bottom_bar.dart';
import '../shared/app_card.dart';
import '../shared/estilos.dart';
import '../shared/fila_deuda.dart';
import '../shared/selector_segmentado.dart';
import '../shared/formatters.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';
import 'dashboard/widgets/te_deben_section.dart';

// Fase 81: la fila, el chip y la etiqueta de urgencia viven en
// `shared/fila_deuda.dart` (también los usa "Próximos pagos" del Inicio).
export '../shared/fila_deuda.dart'
    show
        ChipUrgencia,
        EtiquetaUrgencia,
        TonoUrgencia,
        detalleEstructura,
        etiquetaUrgencia;

/// Hub de deudas (Fase 80; pestañas Debo / Me deben en la Fase 82,
/// 04-deudas.png) — destino "Deudas" de la barra inferior.
///
/// Reutiliza `resumenDashboardProvider`: `deudasActivas` (lo que debo) y
/// `deudasMeDebenActivas` (lo que me deben), con `fechaVencimientoReal`,
/// `totalAPagar` y `saldoPendiente` (Fase 79). Cruza con `deudasProvider`
/// solo para tipo/acreedor/cuotas. Orden: `ordenarPorUrgenciaYFecha`.
/// Con la nube, "Registradas por tus amigos" va debajo, FUERA de los
/// totales (la deuda real vive en la cuenta del amigo).
class DeudasScreen extends ConsumerStatefulWidget {
  const DeudasScreen({super.key, this.pestanaInicial = DireccionDeuda.debo});

  final DireccionDeuda pestanaInicial;

  @override
  ConsumerState<DeudasScreen> createState() => _DeudasScreenState();
}

class _DeudasScreenState extends ConsumerState<DeudasScreen> {
  late DireccionDeuda _pestana = widget.pestanaInicial;

  @override
  Widget build(BuildContext context) {
    final resumenAsync = ref.watch(resumenDashboardProvider);
    final deudasPorId = {
      for (final d in ref.watch(deudasProvider).valueOrNull ?? const <Deuda>[])
        d.id: d,
    };
    final modoLocal = ref.watch(modoLocalProvider);
    final theme = Theme.of(context);
    final debo = _pestana == DireccionDeuda.debo;

    return Scaffold(
      appBar: AppBar(
        // Destino de la barra: se vuelve al Inicio con la barra (o el
        // "atrás" del sistema), sin flecha propia (04-deudas.png).
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        title: Text(
          'Deudas',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: resumenAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar tus deudas.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (resumen) {
            final ahora = DateTime.now();
            final deudas = ordenarPorUrgenciaYFecha(
              debo ? resumen.deudasActivas : resumen.deudasMeDebenActivas,
              ahora,
            );
            final totales = debo
                ? resumen.totalAdeudadoPorMoneda
                : resumen.totalTeDebenPorMoneda;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                SelectorSegmentado<DireccionDeuda>(
                  etiquetaGrupo: 'Ver deudas',
                  opciones: const [
                    (DireccionDeuda.debo, 'Debo'),
                    (DireccionDeuda.meDeben, 'Me deben'),
                  ],
                  seleccionado: _pestana,
                  onCambio: (p) => setState(() => _pestana = p),
                ),
                const SizedBox(height: 16),
                if (deudas.isEmpty)
                  _EstadoVacio(direccion: _pestana)
                else ...[
                  _TarjetaResumen(
                    titulo: debo ? 'Total que debes' : 'Total que te deben',
                    totalPorMoneda: totales,
                    deudas: deudas,
                    ahora: ahora,
                    direccion: _pestana,
                  ),
                  // Fase 83: entrada al plan de pago (solo lo que debo).
                  if (debo)
                    Align(
                      alignment: Alignment.centerLeft,
                      // Fase 87: "Mi avance" junto al plan.
                      child: Wrap(
                        children: [
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: context.successText,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/plan-pago'),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Ver mi plan de pago'),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              foregroundColor: context.successText,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/avance'),
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: const Text('Mi avance'),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 16),
                  for (final deuda in deudas) ...[
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: FilaDeuda(
                        resumen: deuda,
                        deuda: deudasPorId[deuda.id],
                        ahora: ahora,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
                // Solo con la nube (amigos). Fuera de los totales de arriba.
                if (!modoLocal) ...[
                  const SizedBox(height: 4),
                  TeDebenSection(soloYoDebo: debo),
                ],
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const AppBottomBar(actual: AppBottomTab.deudas),
    );
  }
}

class _TarjetaResumen extends StatelessWidget {
  const _TarjetaResumen({
    required this.titulo,
    required this.totalPorMoneda,
    required this.deudas,
    required this.ahora,
    required this.direccion,
  });

  final String titulo;
  final Map<Moneda, double> totalPorMoneda;
  final List<DeudaActivaResumen> deudas;
  final DateTime ahora;
  final DireccionDeuda direccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tonos = deudas.map((d) => etiquetaUrgencia(d, ahora).tono).toList();
    final vencidas = tonos.where((t) => t == TonoUrgencia.peligro).length;
    final pronto = tonos.where((t) => t == TonoUrgencia.aviso).length;
    final totales = totalPorMoneda.entries.toList();
    final debo = direccion == DireccionDeuda.debo;
    final n = deudas.length;

    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.heroBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.heroMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            if (totales.isEmpty)
              _montoHero(context, formatearMonto(0, Moneda.pen))
            else
              for (final e in totales)
                _montoHero(context, formatearMonto(e.value, e.key)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (debo || pronto > 0)
                  _ChipHero(
                    icono: Icons.schedule,
                    texto: pronto == 1
                        ? '1 vence pronto'
                        : '$pronto vencen pronto',
                  ),
                if (vencidas > 0)
                  _ChipHero(
                    icono: Icons.error_outline,
                    texto: vencidas == 1 ? '1 vencida' : '$vencidas vencidas',
                  ),
                _ChipHero(
                  icono: debo
                      ? Icons.receipt_long_outlined
                      : Icons.people_outline,
                  texto: debo
                      ? (n == 1 ? '1 deuda activa' : '$n deudas activas')
                      : (n == 1
                            ? '1 préstamo por cobrar'
                            : '$n préstamos por cobrar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _montoHero(BuildContext context, String texto) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: TextStyle(
          color: context.heroText,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          fontFeatures: cifrasTabulares,
        ),
      ),
    );
  }
}

class _ChipHero extends StatelessWidget {
  const _ChipHero({required this.icono, required this.texto});

  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.heroMuted.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: context.heroText),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto,
              style: TextStyle(
                color: context.heroText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.direccion});

  final DireccionDeuda direccion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final debo = direccion == DireccionDeuda.debo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.successBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              debo ? Icons.celebration_outlined : Icons.handshake_outlined,
              size: 36,
              color: context.successText,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            debo ? 'No tienes deudas activas' : 'Nadie te debe',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            debo
                ? 'Registra un préstamo, una compra en cuotas o algo que le '
                      'debas a alguien para seguir sus pagos aquí.'
                : 'Si le prestaste dinero a alguien, regístralo para llevar '
                      'la cuenta de lo que te devuelve.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
            onPressed: () => Navigator.of(
              context,
            ).pushNamed('/deudas/nueva', arguments: direccion),
            icon: const Icon(Icons.add),
            label: Text(debo ? 'Agregar deuda' : 'Registrar préstamo'),
          ),
        ],
      ),
    );
  }
}
