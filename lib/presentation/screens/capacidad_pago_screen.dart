import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/capacidad_pago.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/entities/transaccion.dart';
import '../shared/app_card.dart';
import '../shared/enum_labels.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import '../state/plan_pago_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Texto del resultado negativo (Fase 86).
const textoNoAlcanza = 'Hoy tus ingresos no cubren tus gastos y mínimos';

/// Fase 87 — la segura no alcanza pero la típica sí.
String textoSoloMesTipico(String montoTipico) =>
    'En tu peor mes no alcanzó para tus mínimos; en un mes típico te '
    'sobran $montoTipico';

/// Pie fijo de la pantalla.
const avisoCapacidad =
    'Estimación con tus ingresos y gastos registrados en meses completos. '
    'No incluye el mes en curso ni las transferencias entre tus cuentas.';

/// Paso y tope del colchón ajustable.
const pasoColchon = 0.05;
const colchonMaximo = 0.50;

/// Fase 86 — "Cuánto puedo pagar de más" (11-capacidad.png). Cálculo
/// local y determinista ([calcularCapacidadPago]); con menos de 2 meses
/// completos pide un monto manual en vez de inventarlo. "Usar este monto"
/// lo guarda como pago extra del plan y devuelve el monto al cerrar.
class CapacidadPagoScreen extends ConsumerStatefulWidget {
  const CapacidadPagoScreen({super.key, this.ahora});

  /// Solo para pruebas: fija "hoy".
  final DateTime? ahora;

  @override
  ConsumerState<CapacidadPagoScreen> createState() =>
      _CapacidadPagoScreenState();
}

class _CapacidadPagoScreenState extends ConsumerState<CapacidadPagoScreen> {
  double _colchon = colchonPorDefecto;
  final _manual = TextEditingController();

  @override
  void dispose() {
    _manual.dispose();
    super.dispose();
  }

  Future<void> _usar(double monto, Moneda moneda) async {
    await ref.read(configPlanPagoProvider.notifier).cambiarExtra(monto);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Listo: tu pago extra ahora es '
          '${formatearMonto(monto, moneda)} al mes',
        ),
      ),
    );
    Navigator.of(context).pop(monto);
  }

  @override
  Widget build(BuildContext context) {
    final transacciones = ref.watch(todasLasTransaccionesProvider);
    final deudas = ref.watch(deudasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cuánto puedo pagar de más')),
      body: SafeArea(
        child: switch ((transacciones, deudas)) {
          (AsyncData(value: final txs), AsyncData(value: final ds)) =>
            _contenido(context, txs, ds),
          (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
            Center(child: Text('No se pudo calcular.\n$error')),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }

  Widget _contenido(
    BuildContext context,
    List<Transaccion> transacciones,
    List<Deuda> deudas,
  ) {
    final resultado = calcularCapacidadPago(
      transacciones: transacciones,
      deudas: deudas,
      ahora: widget.ahora ?? DateTime.now(),
      colchon: _colchon,
    );
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        ...switch (resultado) {
          CapacidadSinDatos() => _sinDatos(context, resultado),
          CapacidadCalculada() => _calculada(context, resultado),
        },
        if (resultado.otrasMonedas.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Solo se analiza ${labelMoneda(resultado.moneda)}. '
            'Tus movimientos y deudas en '
            '${resultado.otrasMonedas.map(labelMoneda).join(', ')} no se '
            'mezclan ni se convierten.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          avisoCapacidad,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _sinDatos(BuildContext context, CapacidadSinDatos r) {
    final theme = Theme.of(context);
    final monto = double.tryParse(_manual.text.trim().replaceAll(',', '.'));
    return [
      AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aún no hay datos suficientes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Para estimarlo necesito al menos $mesesMinimosCapacidad meses '
              'completos con tus ingresos y gastos registrados '
              '(${r.mesesConDatos == 1 ? 'tienes 1' : 'tienes ${r.mesesConDatos}'}). '
              'Mientras tanto, escribe cuánto crees que puedes pagar de más '
              'cada mes.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manual,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                labelText: 'Pago extra mensual',
                prefixText: '${simboloMoneda(r.moneda)} ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: monto != null && monto > 0
            ? () => _usar(monto, r.moneda)
            : null,
        child: const Text('Usar este monto como pago extra'),
      ),
    ];
  }

  List<Widget> _calculada(BuildContext context, CapacidadCalculada c) {
    final theme = Theme.of(context);
    final m = c.moneda;
    Widget fila(String etiqueta, String valor, {bool fuerte = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    etiqueta,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Fase 87: el valor puede ser largo ("S/ X − S/ Y"); se
                // parte en líneas en vez de desbordar.
                Flexible(
                  child: Text(
                    valor,
                    textAlign: TextAlign.end,
                    style: estiloMonto(
                      theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

    final tokens = AppColorTokens.oscuro; // el héroe es oscuro en ambos temas
    final muted = TextStyle(
      color: context.heroMuted,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );
    final aDeudas = c.recomendado;
    final colchon = c.colchonSeguro;
    final total = aDeudas + colchon;

    return [
      AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TUS ÚLTIMOS ${c.meses.length} MESES COMPLETOS',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 4),
            fila('Ingreso típico', formatearMonto(c.ingresoMediano, m)),
            fila('Gasto típico', formatearMonto(c.gastoMediano, m)),
            // Fase 87: el mes que menos dejó (ingreso y gasto del MISMO mes).
            fila(
              'Tu mes más ajustado (${formatearMesAnio(c.mesMasAjustado.mes)})',
              '${formatearMonto(c.mesMasAjustado.ingresos, m)} − '
                  '${formatearMonto(c.mesMasAjustado.gastos, m)}',
            ),
            fila('Mínimos de tus deudas', formatearMonto(c.minimos, m)),
            if (c.tarjetasExcluidas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 6),
                child: Text(
                  'No resto el mínimo de '
                  '${c.tarjetasExcluidas.map((t) => t.nombre).join(', ')}: '
                  'tus compras con ${c.tarjetasExcluidas.length == 1 ? 'esa tarjeta' : 'esas tarjetas'} '
                  'ya cuentan como gasto y lo cubren.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      Semantics(
        container: true,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.heroBg,
            borderRadius: BorderRadius.circular(24),
          ),
          child: c.noAlcanza
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.soloAlcanzaEnMesTipico
                          ? textoSoloMesTipico(formatearMonto(c.tipico, m))
                          : textoNoAlcanza,
                      style: TextStyle(
                        color: context.heroText,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c.faltante > 0
                          ? 'En tu mes más ajustado te faltan '
                                '${formatearMonto(c.faltante, m)} (contando un '
                                'colchón de ${formatearMonto(colchon, m)}).'
                          : 'En tu mes más ajustado no te quedó nada para '
                                'pagar de más.',
                      style: muted,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mi recomendación para tu deuda', style: muted),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${formatearMonto(aDeudas, m)} extra al mes',
                        style: estiloMonto(
                          TextStyle(
                            color: context.heroText,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (total > 0)
                      ExcludeSemantics(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            height: 10,
                            child: Row(
                              children: [
                                if (aDeudas > 0)
                                  Expanded(
                                    flex: (aDeudas / total * 1000).round(),
                                    child: Container(color: tokens.successText),
                                  ),
                                if (colchon > 0)
                                  Expanded(
                                    flex: (colchon / total * 1000).round(),
                                    child: Container(color: tokens.warningText),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text(
                          '${formatearMonto(aDeudas, m)} a deudas',
                          style: muted.copyWith(color: tokens.successText),
                        ),
                        Text(
                          '${formatearMonto(colchon, m)} colchón',
                          style: muted.copyWith(color: tokens.warningText),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Estimación segura: lo que te dejó tu mes más ajustado. '
        'En un mes típico ${c.tipico >= 0 ? 'te sobrarían ${formatearMonto(c.tipico, m)}' : 'te faltarían ${formatearMonto(-c.tipico, m)}'}.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 12),
      _ControlColchon(
        colchon: _colchon,
        onCambio: (v) => setState(() => _colchon = v),
      ),
      const SizedBox(height: 16),
      if (!c.noAlcanza && c.recomendado > 0)
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => _usar(c.recomendado, m),
          child: const Text('Usar este monto como pago extra'),
        )
      // Fase 87: solo la típica alcanza → opción secundaria, con aviso.
      else if (c.soloAlcanzaEnMesTipico && c.tipicoRedondeado > 0)
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: () => _usar(c.tipicoRedondeado, m),
          child: Text(
            'Usar ${formatearMonto(c.tipicoRedondeado, m)} (arriesgado en '
            'meses bajos)',
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: 8),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () => Navigator.of(
          context,
        ).pushNamed('/plan-pago/simulador', arguments: c.recomendado),
        child: const Text('Ver cuánto acelera mi plan'),
      ),
    ];
  }
}

/// "Colchón: 10 % de tu ingreso" con botones − / + de 48 dp.
class _ControlColchon extends StatelessWidget {
  const _ControlColchon({required this.colchon, required this.onCambio});

  final double colchon;
  final ValueChanged<double> onCambio;

  @override
  Widget build(BuildContext context) {
    final pct = (colchon * 100).round();
    double redondear(double v) => (v * 100).round() / 100;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Colchón para imprevistos: $pct % de tu ingreso',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Menos colchón',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: colchon > 0.001
                ? () => onCambio(redondear(colchon - pasoColchon))
                : null,
            icon: const Icon(Icons.remove),
          ),
          IconButton(
            tooltip: 'Más colchón',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: colchon < colchonMaximo - 0.001
                ? () => onCambio(redondear(colchon + pasoColchon))
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
