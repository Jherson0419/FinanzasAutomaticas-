import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../../domain/entities/deuda.dart';
import '../../../../domain/proximos_pagos.dart';
import '../../../../domain/usecases/dto/resumen_dashboard.dart';
import '../../../shared/app_bottom_bar.dart';
import '../../../shared/app_card.dart';
import '../../../shared/estilos.dart';
import '../../../shared/formatters.dart';
import '../../../state/dashboard/dashboard_providers.dart';
import '../../../state/plan_pago_providers.dart';
import '../../../state/providers.dart';
import '../../../theme/app_theme.dart';
import 'saldo_hero_card.dart';

/// "Tus deudas" del Inicio (Fase 81). Reemplaza en el Inicio a
/// `DeudasActivasSection` (el acordeón) y a `TeDebenSection`.
///
/// Muestra el total que debes (`saldoPendiente`, Fase 79), una barra de
/// progreso pagado / `totalAPagar` y, solo con la nube, cuánto te deben.
/// La tarjeta "Libre de deudas en … / Mi plan" de 01-inicio.png NO va aquí:
/// el plan de pago es la Fase 83. Tocarla abre el hub de Deudas.
class TusDeudasCard extends ConsumerWidget {
  const TusDeudasCard({
    super.key,
    required this.deudasActivas,
    required this.totalAdeudadoPorMoneda,
    this.totalTeDebenPorMoneda = const {},
  });

  final List<DeudaActivaResumen> deudasActivas;
  final Map<Moneda, double> totalAdeudadoPorMoneda;

  /// Fase 82 — préstamos que hice, registrados por mí (local o nube).
  final Map<Moneda, double> totalTeDebenPorMoneda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final modoLocal = ref.watch(modoLocalProvider);
    // Fase 82: "Me deben" = mis préstamos (deudas locales o de la nube con
    // dirección "me deben") + lo que amigos registraron como que ME deben
    // (solo con la nube).
    final deAmigos = modoLocal
        ? const <DeudaDeAmigo>[]
        : [
            for (final d
                in ref.watch(deudasQueMeDebenProvider).valueOrNull ??
                    const <DeudaDeAmigo>[])
              if (!d.yoDebo) d,
          ];
    final meDeben = _sumarPorMoneda(deAmigos, base: totalTeDebenPorMoneda);

    final principal = monedaPrincipal([totalAdeudadoPorMoneda]);
    final progreso = progresoDeudas(deudasActivas, principal);

    String montos(Map<Moneda, double> mapa) =>
        mapa.entries.map((e) => formatearMonto(e.value, e.key)).join(' + ');

    final debo = totalAdeudadoPorMoneda.isEmpty
        ? formatearMonto(0, principal)
        : montos(totalAdeudadoPorMoneda);
    final detalle = [
      'Debo $debo',
      if (meDeben.isNotEmpty) 'Me deben ${montos(meDeben)}',
    ].join(' · ');
    final sinDeudas = deudasActivas.isEmpty;
    // Fase 83 (01-inicio.png): con una estimación real del plan, el título
    // es "Libre de deudas en …" y aparece "Mi plan". Sin estimación
    // posible, la parte del plan no se muestra.
    final fechaLibre = sinDeudas ? null : ref.watch(fechaLibrePlanProvider);
    final titulo = fechaLibre == null
        ? 'Tus deudas'
        : 'Libre de deudas en ${formatearMesAnioCorto(fechaLibre)} (aprox.)';

    final tarjeta = Semantics(
      button: true,
      excludeSemantics: true,
      label: sinDeudas
          ? 'Tus deudas: no tienes deudas activas.'
                '${meDeben.isEmpty ? '' : ' Me deben ${montos(meDeben)}.'} '
                'Abrir Deudas.'
          : '$titulo: '
                '${progreso.porcentaje}% pagado. $detalle. Abrir Deudas.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => irADestino(context, AppBottomTab.deudas),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    // Espacio para "Mi plan" (va encima, fuera de esta
                    // semántica, para que sea su propio botón accesible).
                    if (fechaLibre == null)
                      Icon(Icons.chevron_right, color: context.textSecondary)
                    else
                      const SizedBox(width: 72, height: 24),
                  ],
                ),
                const SizedBox(height: 12),
                if (sinDeudas)
                  Text(
                    meDeben.isEmpty
                        ? 'No tienes deudas activas.'
                        : 'No tienes deudas activas · Me deben ${montos(meDeben)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: context.textSecondary,
                    ),
                  )
                else ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progreso.fraccion,
                      minHeight: 8,
                      backgroundColor: context.borderCard,
                      color: context.brandAction,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${progreso.porcentaje}% pagado',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        detalle,
                        style: estiloMonto(
                          theme.textTheme.bodyMedium?.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (fechaLibre == null) return tarjeta;
    return Stack(
      children: [
        tarjeta,
        Positioned(
          top: 6,
          right: 8,
          child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: context.successText,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            onPressed: () => Navigator.of(context).pushNamed('/plan-pago'),
            child: const Text('Mi plan'),
          ),
        ),
      ],
    );
  }

  static Map<Moneda, double> _sumarPorMoneda(
    Iterable<DeudaDeAmigo> deudas, {
    Map<Moneda, double> base = const {},
  }) {
    final total = Map<Moneda, double>.of(base)
      ..removeWhere((_, monto) => monto <= 0);
    for (final d in deudas) {
      total.update(
        d.moneda,
        (v) => v + d.montoAdeudado,
        ifAbsent: () => d.montoAdeudado,
      );
    }
    return total;
  }
}
