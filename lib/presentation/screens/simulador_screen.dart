import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/plan_pago.dart';
import '../shared/app_card.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import '../shared/selector_segmentado.dart';
import '../state/plan_pago_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Texto fijo del simulador (Fase 86).
const avisoSimulador =
    'Estimación. Supone que mantienes tu pago total mensual.';

/// Paso de los botones − / + del pago extra.
const pasoExtraSimulador = 50.0;

/// Tope de meses para el pago único.
const mesesMaximosPagoUnico = 36;

/// Fase 86 — "¿Y si pago más?" (10-simulador.png). Compara SIEMPRE contra
/// el plan actual (extra y estrategia guardados): meses, intereses totales
/// y la diferencia. Nada se guarda salvo que toques "Usar … en mi plan"
/// (extra y estrategia; el pago único no se guarda).
class SimuladorScreen extends ConsumerStatefulWidget {
  const SimuladorScreen({super.key, this.extraInicial, this.ahora});

  /// Extra con que arranca el escenario (p. ej. la capacidad calculada);
  /// `null` = el extra del plan actual.
  final double? extraInicial;

  /// Solo para pruebas: fija "hoy".
  final DateTime? ahora;

  @override
  ConsumerState<SimuladorScreen> createState() => _SimuladorScreenState();
}

class _SimuladorScreenState extends ConsumerState<SimuladorScreen> {
  late final TextEditingController _extra;
  final _unico = TextEditingController();
  int _mesUnico = 1;
  late EstrategiaPago _estrategia;

  @override
  void initState() {
    super.initState();
    final config = ref.read(configPlanPagoProvider);
    final inicial = widget.extraInicial ?? config.extraMensual;
    _extra = TextEditingController(text: _texto(inicial));
    _estrategia = config.estrategia ?? EstrategiaPago.avalancha;
  }

  @override
  void dispose() {
    _extra.dispose();
    _unico.dispose();
    super.dispose();
  }

  static String _texto(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  static double _leer(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;
    return v < 0 ? 0 : v;
  }

  void _sumarExtra(double delta) {
    final nuevo = (_leer(_extra) + delta).clamp(0, double.infinity).toDouble();
    setState(() => _extra.text = _texto(nuevo));
  }

  Future<void> _usar() async {
    final notifier = ref.read(configPlanPagoProvider.notifier);
    await notifier.cambiarExtra(_leer(_extra));
    await notifier.cambiarEstrategia(_estrategia);
    if (!mounted) return;
    Navigator.of(context).pop(_leer(_extra));
  }

  @override
  Widget build(BuildContext context) {
    final deudas = ref.watch(deudasProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('¿Y si pago más?')),
      body: SafeArea(
        child: deudas.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('No se pudo simular.\n$e')),
          data: _contenido,
        ),
      ),
    );
  }

  Widget _contenido(List<Deuda> todas) {
    final theme = Theme.of(context);
    final config = ref.watch(configPlanPagoProvider);
    final candidatas = deudasParaPlan(todas);
    if (candidatas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes deudas activas que simular.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Misma moneda principal que el plan.
    final moneda = candidatas.any((d) => d.moneda == Moneda.pen)
        ? Moneda.pen
        : candidatas.first.moneda;
    final estrategiaActual =
        config.estrategia ??
        compararPlanes(
          candidatas,
          extraMensual: config.extraMensual,
        )[moneda]!.recomendacion.estrategia;
    final montoUnico = _leer(_unico);
    final c = simularEscenario(
      deudas: candidatas,
      moneda: moneda,
      extraActual: config.extraMensual,
      estrategiaActual: estrategiaActual,
      extraEscenario: _leer(_extra),
      estrategiaEscenario: _estrategia,
      pagoUnico: montoUnico > 0
          ? PagoUnico(mes: _mesUnico, monto: montoUnico)
          : null,
    );
    final ahora = widget.ahora ?? DateTime.now();
    final simbolo = '${simboloMoneda(moneda)} ';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pago extra cada mes',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  IconButton.outlined(
                    tooltip:
                        'Restar ${formatearMonto(pasoExtraSimulador, moneda)}',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _leer(_extra) > 0
                        ? () => _sumarExtra(-pasoExtraSimulador)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _extra,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Pago extra mensual',
                        prefixText: simbolo,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip:
                        'Sumar ${formatearMonto(pasoExtraSimulador, moneda)}',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: () => _sumarExtra(pasoExtraSimulador),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Hoy tu plan usa ${formatearMonto(config.extraMensual, moneda)} '
                'extra al mes.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Pago único (opcional)',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Por ejemplo, una gratificación que destinas a tus deudas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _unico,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monto del pago único',
                  prefixText: simbolo,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _mesUnico == 1
                            ? 'Lo pagas el mes que viene'
                            : 'Lo pagas en $_mesUnico meses '
                                  '(${formatearMesAnio(fechaDelMes(ahora, _mesUnico))})',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Un mes antes',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _mesUnico > 1
                        ? () => setState(() => _mesUnico--)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: 'Un mes después',
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    onPressed: _mesUnico < mesesMaximosPagoUnico
                        ? () => setState(() => _mesUnico++)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SelectorSegmentado<EstrategiaPago>(
          etiquetaGrupo: 'Estrategia',
          opciones: const [
            (EstrategiaPago.avalancha, 'Avalancha'),
            (EstrategiaPago.bolaDeNieve, 'Bola de nieve'),
          ],
          seleccionado: _estrategia,
          onCambio: (e) => setState(() => _estrategia = e),
        ),
        const SizedBox(height: 16),
        _Resultado(comparacion: c, moneda: moneda, ahora: ahora),
        const SizedBox(height: 12),
        _Aviso(),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _usar,
          child: Text(
            'Usar ${formatearMonto(_leer(_extra), moneda)} en mi plan',
          ),
        ),
        if (montoUnico > 0) ...[
          const SizedBox(height: 8),
          Text(
            'El pago único no se guarda: es solo para comparar.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _Aviso extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    avisoSimulador,
    style: Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: context.textSecondary),
  );
}

/// Héroe "Libre de deudas" + intereses + tabla plan actual vs escenario.
class _Resultado extends StatelessWidget {
  const _Resultado({
    required this.comparacion,
    required this.moneda,
    required this.ahora,
  });

  final ComparacionEscenario comparacion;
  final Moneda moneda;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const t = AppColorTokens.oscuro;
    final esc = comparacion.escenario;
    final act = comparacion.actual;
    final meses = comparacion.mesesAntes;
    final ahorro = comparacion.interesAhorrado;
    final textoMeses = meses == null
        ? 'A este ritmo no terminas de pagar'
        : meses > 0
        ? (meses == 1 ? '1 mes antes' : '$meses meses antes')
        : meses < 0
        ? (meses == -1 ? '1 mes después' : '${-meses} meses después')
        : 'Igual que tu plan actual';
    final textoAhorro = ahorro.abs() < 0.5
        ? 'Los mismos intereses'
        : ahorro > 0
        ? 'Ahorras ${formatearMonto(ahorro, moneda)} en intereses'
        : 'Pagas ${formatearMonto(-ahorro, moneda)} más en intereses';
    String meses_(ResultadoPlan p) => p.meses == null
        ? 'no termina'
        : (p.meses == 1 ? '1 mes' : '${p.meses} meses');

    Widget filaTabla(String nombre, ResultadoPlan p, {bool fuerte = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nombre,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: fuerte ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${meses_(p)} · ${formatearMonto(p.interesTotal, moneda)} '
                    'de interés',
                    textAlign: TextAlign.end,
                    style: estiloMonto(theme.textTheme.bodyMedium),
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                Text(
                  'Libre de deudas',
                  style: TextStyle(
                    color: context.heroMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  esc.meses == null
                      ? 'no terminas'
                      : '${formatearMesAnio(fechaDelMes(ahora, esc.meses!))} '
                            '(aprox.)',
                  style: TextStyle(
                    color: context.heroText,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  textoMeses,
                  style: TextStyle(
                    color: meses != null && meses > 0
                        ? t.successText
                        : context.heroMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  textoAhorro,
                  style: TextStyle(
                    color: ahorro > 0.5 ? t.successText : context.heroMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Contra tu plan actual',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              filaTabla('Plan actual', act),
              filaTabla('Este escenario', esc, fuerte: true),
            ],
          ),
        ),
      ],
    );
  }
}
