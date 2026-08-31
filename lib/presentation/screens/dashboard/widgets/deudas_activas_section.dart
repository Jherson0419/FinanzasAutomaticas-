import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../../domain/entities/deuda.dart';
import '../../../../domain/urgencia_deuda.dart';
import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_card.dart';
import '../../../shared/dashboard_colors.dart';
import '../../../shared/formatters.dart';
import '../../../shared/section_label.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';

class DeudasActivasSection extends ConsumerStatefulWidget {
  final List<DeudaActivaResumen> deudasActivas;
  final int deudasEnMoraCount;
  final int deudasPorVencerEstaSemanaCount;
  final Map<Moneda, double> totalAdeudadoPorMoneda;

  const DeudasActivasSection({
    super.key,
    required this.deudasActivas,
    required this.deudasEnMoraCount,
    required this.deudasPorVencerEstaSemanaCount,
    required this.totalAdeudadoPorMoneda,
  });

  @override
  ConsumerState<DeudasActivasSection> createState() =>
      _DeudasActivasSectionState();
}

/// Umbral de velocidad (px/s) para que un swipe horizontal cuente como
/// gesto válido — mismo criterio de umbral por velocidad que
/// `CuentasCarrusel` (Fase 33), adaptado a un gesto horizontal binario en
/// vez de una rotación de pila.
const double _umbralVelocidadSwipe = 200;

class _DeudasActivasSectionState extends ConsumerState<DeudasActivasSection> {
  bool _expandido = true;

  /// 0 = cuotas fijas, 1 = pago libre (Fase 60).
  int _paginaActual = 0;

  void _irAPagina(int pagina) {
    if (pagina == _paginaActual) return;
    setState(() => _paginaActual = pagina);
  }

  void _procesarSwipe(DragEndDetails details) {
    final velocidad = details.primaryVelocity ?? 0;
    if (velocidad <= -_umbralVelocidadSwipe) {
      _irAPagina(1);
    } else if (velocidad >= _umbralVelocidadSwipe) {
      _irAPagina(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Fase 68: "Debo a {nick}" — el amigo vinculado siempre está en mi
    // propia lista de amigos aceptados (`amigosProvider`, ya cargada para
    // "Mis amigos"), así que no hace falta una resolución de nick aparte.
    final amigos = ref.watch(amigosProvider).valueOrNull ?? const [];
    final nickPorId = {for (final amigo in amigos) amigo.usuarioId: amigo.nick};

    final cuotasFijas = widget.deudasActivas
        .where((d) => d.estructuraPago == EstructuraPago.cuotasFijas)
        .toList();
    final pagoLibre = widget.deudasActivas
        .where((d) => d.estructuraPago == EstructuraPago.pagoLibre)
        .toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expandido = !_expandido),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SectionLabel(
                        icon: Icons.credit_card,
                        label: 'Deudas activas',
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _expandido ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.totalAdeudadoPorMoneda.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final entry in widget.totalAdeudadoPorMoneda.entries)
                        Text(
                          formatearMonto(entry.value, entry.key),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_expandido
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.deudasEnMoraCount > 0) ...[
                        const SizedBox(height: 12),
                        _Banner(
                          color: colorGasto(context),
                          texto: widget.deudasEnMoraCount == 1
                              ? 'Tienes 1 deuda en mora'
                              : 'Tienes ${widget.deudasEnMoraCount} deudas en mora',
                        ),
                      ],
                      if (widget.deudasPorVencerEstaSemanaCount > 0) ...[
                        const SizedBox(height: 12),
                        _Banner(
                          color: colorWarning,
                          texto: widget.deudasPorVencerEstaSemanaCount == 1
                              ? 'Tienes 1 deuda que vence esta semana'
                              : 'Tienes ${widget.deudasPorVencerEstaSemanaCount} deudas que vencen esta semana',
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (widget.deudasActivas.isEmpty)
                        Text(
                          'No tienes deudas activas registradas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _paginaActual == 0 ? 'Cuotas fijas' : 'Pago libre',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Row(
                              children: [
                                _PuntoIndicador(
                                  key: const ValueKey(
                                    'deudasActivas_puntoCuotasFijas',
                                  ),
                                  activo: _paginaActual == 0,
                                  onTap: () => _irAPagina(0),
                                ),
                                const SizedBox(width: 6),
                                _PuntoIndicador(
                                  key: const ValueKey(
                                    'deudasActivas_puntoPagoLibre',
                                  ),
                                  activo: _paginaActual == 1,
                                  onTap: () => _irAPagina(1),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onHorizontalDragEnd: _procesarSwipe,
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _paginaActual == 0
                                  ? _paginaDeudas(
                                      key: const ValueKey('cuotasFijas'),
                                      lista: cuotasFijas,
                                      theme: theme,
                                      colorScheme: colorScheme,
                                      nickPorId: nickPorId,
                                    )
                                  : _paginaDeudas(
                                      key: const ValueKey('pagoLibre'),
                                      lista: pagoLibre,
                                      theme: theme,
                                      colorScheme: colorScheme,
                                      nickPorId: nickPorId,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _paginaDeudas({
    required Key key,
    required List<DeudaActivaResumen> lista,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Map<String, String?> nickPorId,
  }) {
    if (lista.isEmpty) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No tienes deudas de este tipo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final deuda in lista)
          _filaDeuda(deuda, theme, colorScheme, nickPorId),
      ],
    );
  }

  /// Fase 68 — color de fondo/borde según [urgenciaDeuda]: vencida
  /// (`colorDanger`), por vencer en ≤3 días (`colorWarning`), normal sin
  /// cambio (mismo umbral que `ObtenerAlertasTarjetasCredito`, ya aplicado
  /// también al ORDEN de esta lista en `ObtenerResumenDashboard`).
  Color? _colorFondoUrgencia(UrgenciaDeuda urgencia) {
    switch (urgencia) {
      case UrgenciaDeuda.vencida:
        return colorDanger.withValues(alpha: 0.10);
      case UrgenciaDeuda.porVencer:
        return colorWarning.withValues(alpha: 0.10);
      case UrgenciaDeuda.normal:
        return null;
    }
  }

  Color? _colorBordeUrgencia(UrgenciaDeuda urgencia) {
    switch (urgencia) {
      case UrgenciaDeuda.vencida:
        return colorDanger;
      case UrgenciaDeuda.porVencer:
        return colorWarning;
      case UrgenciaDeuda.normal:
        return null;
    }
  }

  Widget _filaDeuda(
    DeudaActivaResumen deuda,
    ThemeData theme,
    ColorScheme colorScheme,
    Map<String, String?> nickPorId,
  ) {
    final urgencia = urgenciaDeuda(deuda, DateTime.now());
    final colorBorde = _colorBordeUrgencia(urgencia);
    // Fase 68 (68.4) — "Debo a {nick}" reemplaza la falta total de
    // descripción de acreedor que tenía esta fila para deudas vinculadas a
    // un amigo de Finzo.
    final nombreAmigo = deuda.amigoUsuarioId == null
        ? null
        : nickPorId[deuda.amigoUsuarioId];

    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).pushNamed('/deudas/detalle', arguments: deuda.id),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _colorFondoUrgencia(urgencia),
          borderRadius: BorderRadius.circular(12),
          border: colorBorde == null
              ? null
              : Border.all(color: colorBorde, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    deuda.nombreDeuda,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Registrar pago',
                  icon: Icon(
                    Icons.payments_outlined,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamed('/deudas/pago', arguments: deuda.id),
                ),
                if (deuda.enMora)
                  Text(
                    'En mora',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorGasto(context),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else if (deuda.fechaVencimientoReal != null)
                  Text(
                    formatearFecha(deuda.fechaVencimientoReal!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else if (deuda.estructuraPago == EstructuraPago.cuotasFijas)
                  // Todas las cuotas ya están pagadas (por eso no hay
                  // `fechaVencimientoReal`), a diferencia de `pagoLibre` sin
                  // cuenta vinculada, que nunca tuvo una fecha que mostrar.
                  Text(
                    '—',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  Text(
                    'Sin cuota fija',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (nombreAmigo != null) ...[
              const SizedBox(height: 2),
              Text(
                'Debo a $nombreAmigo',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: deuda.progreso,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              deuda.montoCuota != null
                  ? 'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)} · Cuota ${formatearMonto(deuda.montoCuota!, deuda.moneda)}'
                  : 'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Puntito indicador de página (Fase 60) — relleno cuando [activo], solo el
/// borde si no. Tocarlo salta directo a esa página, además del swipe.
class _PuntoIndicador extends StatelessWidget {
  const _PuntoIndicador({super.key, required this.activo, required this.onTap});

  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: activo ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: activo
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final String texto;

  const _Banner({required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
