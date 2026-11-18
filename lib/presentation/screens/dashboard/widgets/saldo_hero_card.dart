import 'package:flutter/material.dart';

import '../../../../domain/entities/cuenta.dart';
import '../../../shared/estilos.dart';
import '../../../shared/formatters.dart';
import '../../../theme/app_theme.dart';

/// Moneda que se muestra en grande (Fase 81): soles si aparece en
/// cualquiera de los mapas (o si no hay datos); si no, la primera que
/// aparezca. Nunca se convierte entre monedas.
Moneda monedaPrincipal(Iterable<Map<Moneda, double>> mapas) {
  for (final m in mapas) {
    if (m.containsKey(Moneda.pen)) return Moneda.pen;
  }
  for (final m in mapas) {
    if (m.isNotEmpty) return m.keys.first;
  }
  return Moneda.pen;
}

/// Tarjeta "héroe" del Inicio (Fase 81, 01-inicio.png). Reemplaza en el
/// Inicio a `SaldoTotalCard`, `IngresosGastosSection` y `CuentasCarrusel`:
/// saldo total, resultado del mes (chip con flecha + signo + monto),
/// ingresos y gastos del mes y el enlace "N cuentas ›" a Mis cuentas.
///
/// Multi-moneda igual que `ObtenerResumenDashboard` (sin convertir): la
/// moneda principal va en grande y cada moneda adicional en una línea
/// secundaria aparte.
///
/// La tarjeta es oscura en los dos temas (`heroBg`), así que los colores de
/// estado sobre ella son SIEMPRE los del tema oscuro
/// (`AppColorTokens.oscuro`), cuyo contraste sobre `heroBg` está probado.
class SaldoHeroCard extends StatelessWidget {
  const SaldoHeroCard({
    super.key,
    required this.saldoTotalPorMoneda,
    required this.ingresosMesPorMoneda,
    required this.gastosMesPorMoneda,
    required this.cantidadCuentas,
  });

  final Map<Moneda, double> saldoTotalPorMoneda;
  final Map<Moneda, double> ingresosMesPorMoneda;
  final Map<Moneda, double> gastosMesPorMoneda;
  final int cantidadCuentas;

  static const _sobreHero = AppColorTokens.oscuro;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final principal = monedaPrincipal([
      saldoTotalPorMoneda,
      ingresosMesPorMoneda,
      gastosMesPorMoneda,
    ]);
    final monedas = {
      ...saldoTotalPorMoneda.keys,
      ...ingresosMesPorMoneda.keys,
      ...gastosMesPorMoneda.keys,
    }.where((m) => m != principal).toList();

    double neto(Moneda m) =>
        (ingresosMesPorMoneda[m] ?? 0) - (gastosMesPorMoneda[m] ?? 0);

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: context.heroMuted,
      fontWeight: FontWeight.w600,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      decoration: BoxDecoration(
        color: context.heroBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Saldo total', style: muted)),
              Semantics(
                button: true,
                label: 'Ver mis $cantidadCuentas cuentas',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).pushNamed('/cuentas'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cantidadCuentas == 1
                                ? '1 cuenta'
                                : '$cantidadCuentas cuentas',
                            style: muted,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right,
                            color: context.heroMuted,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatearMonto(saldoTotalPorMoneda[principal] ?? 0, principal),
                style: TextStyle(
                  color: context.heroText,
                  fontSize: 40,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  fontFeatures: cifrasTabulares,
                ),
              ),
            ),
          ),
          for (final m in monedas)
            if (saldoTotalPorMoneda.containsKey(m))
              Text(
                'Además ${formatearMonto(saldoTotalPorMoneda[m]!, m)}',
                style: estiloMonto(muted),
              ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipResultadoMes(neto: neto(principal), moneda: principal),
              for (final m in monedas)
                if (ingresosMesPorMoneda.containsKey(m) ||
                    gastosMesPorMoneda.containsKey(m))
                  _ChipResultadoMes(neto: neto(m), moneda: m),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.heroMuted.withValues(alpha: 0.25)),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ColumnaMes(
                    titulo: 'Ingresos',
                    montos: ingresosMesPorMoneda,
                    principal: principal,
                    color: _sobreHero.successText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ColumnaMes(
                    titulo: 'Gastos',
                    montos: gastosMesPorMoneda,
                    principal: principal,
                    color: _sobreHero.dangerText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "↗ +S/ 640.00 este mes": flecha + signo + monto (nunca solo color).
class _ChipResultadoMes extends StatelessWidget {
  const _ChipResultadoMes({required this.neto, required this.moneda});

  final double neto;
  final Moneda moneda;

  @override
  Widget build(BuildContext context) {
    const t = SaldoHeroCard._sobreHero;
    final positivo = neto >= 0;
    final (color, fondo, icono) = positivo
        ? (t.successText, t.successBg, Icons.north_east)
        : (t.dangerText, t.dangerBg, Icons.south_east);
    final texto =
        '${formatearMontoConSigno(neto, moneda, positivo: positivo)} este mes';
    return Semantics(
      label:
          'Resultado del mes: ${positivo ? 'a favor' : 'en contra'} '
          '${formatearMonto(neto.abs(), moneda)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFeatures: cifrasTabulares,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColumnaMes extends StatelessWidget {
  const _ColumnaMes({
    required this.titulo,
    required this.montos,
    required this.principal,
    required this.color,
  });

  final String titulo;
  final Map<Moneda, double> montos;
  final Moneda principal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final otras = montos.entries.where((e) => e.key != principal);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: context.heroMuted,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            formatearMonto(montos[principal] ?? 0, principal),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFeatures: cifrasTabulares,
            ),
          ),
        ),
        for (final e in otras)
          Text(
            formatearMonto(e.value, e.key),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFeatures: cifrasTabulares,
            ),
          ),
      ],
    );
  }
}
