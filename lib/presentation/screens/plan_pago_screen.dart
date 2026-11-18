import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/plan_pago.dart';
import '../../domain/saldo_deuda.dart';
import '../shared/app_card.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import 'pago_deuda_nuevo_screen.dart';
import 'transferencia_screen.dart';
import '../state/plan_pago_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Aviso fijo de toda la pantalla: el plan es una ESTIMACIÓN.
const avisoEstimacionPlan =
    'Estimación. Depende de que pagues a tiempo y de que las tasas '
    'ingresadas sean correctas.';

/// Chips de presupuesto extra.
const incrementosExtra = [50.0, 100.0, 200.0];

/// Fase 84 (A.1) — explica de dónde sale el ahorro frente a "sin plan".
String textoOrigenAhorro(double extra) => extra <= 0
    ? 'Ahorro por reasignar las cuotas que vas liberando'
    : 'Ahorro con tu pago extra y las cuotas liberadas';

/// Fase 84 (A.2) — la TCEA solo se cobra sobre lo que no se paga completo.
const notaTasaTarjeta =
    'Si pagas el total cada mes, esta tasa no te cobra interés';

/// Fase 84b (C) — el supuesto del plan, siempre visible en el hero: cuánto
/// se destina al mes y que lo liberado se reasigna. Vale también con extra 0.
String textoSupuestoPlan({
  required double minimos,
  required double extra,
  required Moneda moneda,
}) {
  final extraReal = extra < 0 ? 0.0 : extra;
  return 'Supone que destinas ${formatearMonto(minimos + extraReal, moneda)} '
      'al mes a tus deudas (mínimos ${formatearMonto(minimos, moneda)} + '
      'extra ${formatearMonto(extraReal, moneda)}) y que reasignas lo que '
      'vas liberando';
}

/// Fase 84 (E): fila de tarjeta en el plan — sin botón de pago.
const notaTarjetaSinPago = 'Se actualiza con los movimientos de tu tarjeta';

/// Nombre de la estrategia para la UI.
String nombreEstrategia(EstrategiaPago e) => switch (e) {
  EstrategiaPago.avalancha => 'Avalancha',
  EstrategiaPago.bolaDeNieve => 'Bola de nieve',
  EstrategiaPago.base => 'Sin plan',
};

/// Estrategia vigente: la elegida a mano o, si no, la recomendada.
EstrategiaPago estrategiaVigente(
  ComparacionPlanes c,
  EstrategiaPago? elegida,
) => elegida ?? c.recomendacion.estrategia;

/// Fecha estimada en que queda libre de deudas con [plan]; `null` si a
/// este ritmo no se termina.
DateTime? fechaLibre(ResultadoPlan plan, DateTime ahora) =>
    plan.meses == null ? null : fechaDelMes(ahora, plan.meses!);

/// Mi plan de pago (Fase 83, 09-plan-pago.png). SOLO lectura y cálculo:
/// no registra pagos ni modifica deudas (por eso no tiene el botón "Pagar"
/// de la imagen). Todo es una estimación.
class PlanPagoScreen extends ConsumerStatefulWidget {
  const PlanPagoScreen({super.key, this.ahora});

  /// Solo para pruebas: fija "hoy".
  final DateTime? ahora;

  @override
  ConsumerState<PlanPagoScreen> createState() => _PlanPagoScreenState();
}

class _PlanPagoScreenState extends ConsumerState<PlanPagoScreen> {
  // Se crea en initState (no perezoso): en el estado vacío el campo nunca
  // se construye y un controlador perezoso se crearía recién en dispose,
  // cuando `ref` ya no se puede usar.
  late final TextEditingController _extraController;

  @override
  void initState() {
    super.initState();
    _extraController = TextEditingController(
      text: _textoExtra(ref.read(configPlanPagoProvider).extraMensual),
    );
  }

  DateTime get _ahora => widget.ahora ?? DateTime.now();

  static String _textoExtra(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');

  @override
  void dispose() {
    _extraController.dispose();
    super.dispose();
  }

  /// Fase 86: capacidad y simulador pueden guardar un nuevo extra; al
  /// volver, el campo muestra el valor guardado.
  Future<void> _abrirYSincronizar(String ruta) async {
    await Navigator.of(context).pushNamed(
      ruta,
      arguments: ruta == '/plan-pago/simulador'
          ? ref.read(configPlanPagoProvider).extraMensual
          : null,
    );
    if (!mounted) return;
    final guardado = ref.read(configPlanPagoProvider).extraMensual;
    if (_extraController.text != _textoExtra(guardado)) {
      _extraController.text = _textoExtra(guardado);
    }
  }

  void _cambiarExtra(double valor, {bool actualizarCampo = false}) {
    ref.read(configPlanPagoProvider.notifier).cambiarExtra(valor);
    if (actualizarCampo) {
      _extraController.text = _textoExtra(valor < 0 ? 0 : valor);
      _extraController.selection = TextSelection.collapsed(
        offset: _extraController.text.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final comparacionesAsync = ref.watch(comparacionesPlanProvider);
    final config = ref.watch(configPlanPagoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mi plan de pago',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        // Fase 87: entrada a "Mi avance".
        actions: [
          IconButton(
            tooltip: 'Mi avance',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => Navigator.of(context).pushNamed('/avance'),
            icon: const Icon(Icons.emoji_events_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: comparacionesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudo calcular el plan.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (comparaciones) {
            if (comparaciones.isEmpty) return const _EstadoVacio();
            final monedas = comparaciones.keys.toList();
            final principal = comparaciones[monedas.first]!;
            final estrategia = estrategiaVigente(principal, config.estrategia);
            final plan = principal.plan(estrategia);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _Hero(
                  comparacion: principal,
                  plan: plan,
                  ahora: _ahora,
                  extra: config.extraMensual,
                ),
                const SizedBox(height: 16),
                _Comparador(
                  comparacion: principal,
                  seleccionada: estrategia,
                  onElegir: (e) => ref
                      .read(configPlanPagoProvider.notifier)
                      .cambiarEstrategia(e),
                ),
                const SizedBox(height: 16),
                _Presupuesto(
                  controller: _extraController,
                  moneda: principal.moneda,
                  onCambiar: (v) => _cambiarExtra(v),
                  onSumar: (inc) => _cambiarExtra(
                    config.extraMensual + inc,
                    actualizarCampo: true,
                  ),
                  onAbrir: _abrirYSincronizar,
                ),
                const SizedBox(height: 16),
                _ListaOrdenada(
                  plan: plan,
                  estrategia: estrategia,
                  ahora: _ahora,
                ),
                if (plan.hayDeudasSinTasa) ...[
                  const SizedBox(height: 12),
                  _Aviso(
                    icono: Icons.help_outline,
                    texto:
                        'Algunas deudas no tienen tasa: se calcularon sin '
                        'interés. Agrégala para un plan más preciso.',
                    tono: _TonoAviso.aviso,
                  ),
                ],
                for (final m in monedas.skip(1)) ...[
                  const SizedBox(height: 16),
                  _OtraMoneda(
                    comparacion: comparaciones[m]!,
                    estrategia: estrategiaVigente(
                      comparaciones[m]!,
                      config.estrategia,
                    ),
                    ahora: _ahora,
                  ),
                ],
                const SizedBox(height: 16),
                const _Aviso(
                  icono: Icons.info_outline,
                  texto: avisoEstimacionPlan,
                  tono: _TonoAviso.neutro,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.comparacion,
    required this.plan,
    required this.ahora,
    required this.extra,
  });

  final ComparacionPlanes comparacion;
  final ResultadoPlan plan;
  final DateTime ahora;
  final double extra;

  @override
  Widget build(BuildContext context) {
    const t = AppColorTokens.oscuro; // la tarjeta es oscura en ambos temas
    final fecha = fechaLibre(plan, ahora);
    final meses = comparacion.ahorroMeses(plan);
    final ahorro = comparacion.ahorroInteres(plan);
    final moneda = comparacion.moneda;
    final muted = TextStyle(
      color: context.heroMuted,
      fontWeight: FontWeight.w600,
      fontSize: 15,
    );

    return Semantics(
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
              fecha == null
                  ? 'A este ritmo'
                  : 'Puedes estar libre de deudas en',
              style: muted,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                fecha == null
                    ? 'no terminas de pagar'
                    : '${formatearMesAnio(fecha)} (aprox.)',
                style: TextStyle(
                  color: context.heroText,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (fecha == null) ...[
              const SizedBox(height: 6),
              Text(
                'Los pagos no alcanzan a cubrir el interés de alguna deuda. '
                'Prueba con más pago extra.',
                style: muted,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (meses != null && meses > 0)
                  _ChipHero(
                    texto: meses == 1
                        ? '1 mes antes que sin plan'
                        : '$meses meses antes que sin plan',
                    color: t.successText,
                    fondo: t.successBg,
                  ),
                if (ahorro != null && ahorro >= 1)
                  _ChipHero(
                    texto:
                        '~${formatearMonto(ahorro, moneda)} menos en intereses',
                    color: t.successText,
                    fondo: t.successBg,
                  ),
              ],
            ),
            // Fase 84 (A.1): de dónde sale el ahorro. Con extra 0 también
            // hay ahorro: las cuotas que se liberan pasan a la siguiente
            // deuda (bola de nieve); "sin plan" no las reasigna.
            if ((meses != null && meses > 0) || (ahorro != null && ahorro >= 1))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  textoOrigenAhorro(extra),
                  style: muted.copyWith(fontSize: 13),
                ),
              ),
            if (!comparacion.base.seCompleta && plan.seCompleta)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sin plan, alguna deuda no se termina de pagar (no tiene '
                  'pago mínimo o no cubre su interés).',
                  style: muted.copyWith(fontSize: 13),
                ),
              ),
            // Fase 84b (C): el supuesto, fijo (también con extra 0).
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                textoSupuestoPlan(
                  minimos: plan.minimosMensuales,
                  extra: plan.extraMensual,
                  moneda: moneda,
                ),
                style: muted.copyWith(fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),
            Divider(
              height: 1,
              color: context.heroMuted.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                Text.rich(
                  TextSpan(
                    style: muted,
                    children: [
                      const TextSpan(text: 'Te quedan '),
                      TextSpan(
                        text: formatearMonto(plan.capitalTotal, moneda),
                        style: TextStyle(
                          color: context.heroText,
                          fontWeight: FontWeight.w800,
                          fontFeatures: cifrasTabulares,
                        ),
                      ),
                    ],
                  ),
                ),
                Text.rich(
                  TextSpan(
                    style: muted,
                    children: [
                      const TextSpan(text: 'Pago extra '),
                      TextSpan(
                        text: '${formatearMonto(extra, moneda)}/mes',
                        style: TextStyle(
                          color: t.successText,
                          fontWeight: FontWeight.w800,
                          fontFeatures: cifrasTabulares,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipHero extends StatelessWidget {
  const _ChipHero({
    required this.texto,
    required this.color,
    required this.fondo,
  });

  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          fontFeatures: cifrasTabulares,
        ),
      ),
    );
  }
}

/// Avalancha vs Bola de nieve: dos tarjetas seleccionables (botones con
/// estado "seleccionado"), con meses e interés de cada una, y el texto de
/// la recomendación.
class _Comparador extends StatelessWidget {
  const _Comparador({
    required this.comparacion,
    required this.seleccionada,
    required this.onElegir,
  });

  final ComparacionPlanes comparacion;
  final EstrategiaPago seleccionada;
  final ValueChanged<EstrategiaPago> onElegir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = comparacion.recomendacion;
    final diferencia = r.diferenciaInteres.abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Elige cómo atacar tus deudas',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final e in [
                EstrategiaPago.avalancha,
                EstrategiaPago.bolaDeNieve,
              ]) ...[
                if (e == EstrategiaPago.bolaDeNieve) const SizedBox(width: 10),
                Expanded(
                  child: _TarjetaEstrategia(
                    estrategia: e,
                    plan: comparacion.plan(e),
                    seleccionada: e == seleccionada,
                    recomendada: e == r.estrategia,
                    onTap: () => onElegir(e),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          seleccionada == EstrategiaPago.avalancha
              ? 'Pagas primero la deuda con mayor interés. Es la que más '
                    'dinero ahorra.'
              : 'Pagas primero la deuda más pequeña. Ves avances rápido y '
                    'eso ayuda a no rendirse.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          r.texto,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (diferencia >= 0.01)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Diferencia en intereses: '
              '${formatearMonto(diferencia, comparacion.moneda)}.',
              style: estiloMonto(
                theme.textTheme.bodySmall?.copyWith(
                  color: context.textSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TarjetaEstrategia extends StatelessWidget {
  const _TarjetaEstrategia({
    required this.estrategia,
    required this.plan,
    required this.seleccionada,
    required this.recomendada,
    required this.onTap,
  });

  final EstrategiaPago estrategia;
  final ResultadoPlan plan;
  final bool seleccionada;
  final bool recomendada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nombre = nombreEstrategia(estrategia);
    final meses = plan.meses;
    final textoMeses = meses == null
        ? 'No termina a este ritmo'
        : (meses == 1 ? '1 mes' : '$meses meses');
    final interes = formatearMonto(plan.interesTotal, plan.moneda);

    return Semantics(
      button: true,
      selected: seleccionada,
      inMutuallyExclusiveGroup: true,
      label:
          '$nombre${recomendada ? ', recomendada' : ''}. $textoMeses. '
          'Interés total $interes.',
      excludeSemantics: true,
      child: Material(
        color: seleccionada ? context.successBg : context.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: seleccionada ? context.successText : context.borderCard,
            width: seleccionada ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombre,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (seleccionada)
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: context.successText,
                        ),
                    ],
                  ),
                  if (recomendada) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Recomendada',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.successText,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    textoMeses,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Interés: $interes',
                    style: estiloMonto(
                      theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Presupuesto extends StatelessWidget {
  const _Presupuesto({
    required this.controller,
    required this.moneda,
    required this.onCambiar,
    required this.onSumar,
    required this.onAbrir,
  });

  final TextEditingController controller;
  final Moneda moneda;
  final ValueChanged<double> onCambiar;
  final ValueChanged<double> onSumar;

  /// Fase 86: abre la capacidad o el simulador (ruta con nombre).
  final ValueChanged<String> onAbrir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Cuánto puedes pagar de más cada mes',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: InputDecoration(
              labelText: 'Pago extra mensual',
              prefixText: '${simboloMoneda(moneda)} ',
              hintText: '0',
              border: const OutlineInputBorder(),
            ),
            onChanged: (texto) => onCambiar(
              double.tryParse(texto.trim().replaceAll(',', '.')) ?? 0,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final inc in incrementosExtra)
                ActionChip(
                  label: Text('+${inc.toStringAsFixed(0)}'),
                  tooltip: 'Sumar ${formatearMonto(inc, moneda)} al pago extra',
                  onPressed: () => onSumar(inc),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Fase 86: de dónde sale el monto y qué pasaría si cambia.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => onAbrir('/plan-pago/capacidad'),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('Calcular mi capacidad'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => onAbrir('/plan-pago/simulador'),
                icon: const Icon(Icons.tune),
                label: const Text('Simular otro escenario'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListaOrdenada extends StatelessWidget {
  const _ListaOrdenada({
    required this.plan,
    required this.estrategia,
    required this.ahora,
  });

  final ResultadoPlan plan;
  final EstrategiaPago estrategia;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Orden de pago',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          for (final d in plan.deudas) ...[
            if (d.orden > 1) Divider(height: 1, color: context.borderCard),
            _FilaPlan(
              resultado: d,
              plan: plan,
              estrategia: estrategia,
              ahora: ahora,
            ),
          ],
        ],
      ),
    );
  }
}

/// Texto del motivo de "Paga primero".
String motivoPrimero(ResultadoDeudaPlan d, EstrategiaPago e) =>
    e == EstrategiaPago.bolaDeNieve
    ? 'menor saldo'
    : (d.tasa == null || d.tasa == 0
          ? 'mayor interés'
          : 'mayor interés: ${(d.tasa! * 100).toStringAsFixed(0)} %');

class _FilaPlan extends ConsumerWidget {
  const _FilaPlan({
    required this.resultado,
    required this.plan,
    required this.estrategia,
    required this.ahora,
  });

  final ResultadoDeudaPlan resultado;
  final ResultadoPlan plan;
  final EstrategiaPago estrategia;
  final DateTime ahora;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final d = resultado;
    final deuda = d.deuda;
    final primera = d.orden == 1;
    final moneda = plan.moneda;
    // La primera recibe además el pago extra desde el primer mes.
    final cuotaMes = d.pagoMinimoMensual + (primera ? plan.extraMensual : 0);
    final nombre =
        deuda.tipoAcreedor == TipoAcreedor.personaNatural &&
            deuda.nombreAcreedor.trim().isNotEmpty
        ? 'Debes a ${deuda.nombreAcreedor.trim()}'
        : deuda.nombreDeuda;
    final fin = d.mesLibre == null
        ? 'no se paga a este ritmo'
        : 'termina ${formatearMesAnioCorto(fechaDelMes(ahora, d.mesLibre!))}';
    final tasaTexto = d.faltaTasa
        ? 'Falta la tasa'
        : (d.tasa == 0
              ? 'Sin interés'
              : '${(d.tasa! * 100).toStringAsFixed(0)} % de interés anual');

    final esTarjeta = deuda.cuentaId != null;
    // Fase 84 (E): la información es un solo nodo de lectura; los botones
    // (agregar tasa, registrar pago) quedan FUERA para ser alcanzables.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label:
                '${d.orden}. $nombre. ${formatearMonto(cuotaMes, moneda)} al '
                'mes. $tasaTexto, $fin.'
                '${esTarjeta && !d.faltaTasa ? ' $notaTasaTarjeta.' : ''}'
                '${esTarjeta ? ' $notaTarjetaSinPago.' : ''}'
                '${primera ? ' Paga primero: ${motivoPrimero(d, estrategia)}.' : ''}',
            excludeSemantics: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primera ? context.brandAction : context.borderCard,
                  ),
                  child: Text(
                    '${d.orden}',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: primera ? colorSobreEstado : context.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 8,
                        children: [
                          Text(
                            nombre,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            cuotaMes > 0
                                ? '${formatearMonto(cuotaMes, moneda)}/mes'
                                : formatearMonto(d.capitalInicial, moneda),
                            style: estiloMonto(
                              theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$tasaTexto · $fin',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: d.faltaTasa || d.mesLibre == null
                              ? context.warningText
                              : context.textSecondary,
                          fontWeight: d.faltaTasa ? FontWeight.w700 : null,
                        ),
                      ),
                      // Fase 84 (A.2): la TCEA se aplica aquí al saldo completo
                      // (aproximación); en la realidad no cobra si pagas todo.
                      if (deuda.cuentaId != null && !d.faltaTasa)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            notaTasaTarjeta,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (primera) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: context.dangerBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Paga primero: ${motivoPrimero(d, estrategia)}',
                            style: TextStyle(
                              color: context.dangerText,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      // Fase 84 (E): la deuda de tarjeta no se paga desde aquí.
                      if (esTarjeta)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            notaTarjetaSinPago,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (d.faltaTasa)
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    foregroundColor: context.successText,
                  ),
                  // La deuda de una tarjeta se corrige en su cuenta
                  // (TCEA); el resto, editando la deuda.
                  onPressed: () => Navigator.of(context).pushNamed(
                    esTarjeta ? '/cuentas/nueva' : '/deudas/nueva',
                    arguments: deuda.cuentaId ?? deuda.id,
                  ),
                  child: Text(
                    esTarjeta
                        ? 'Agregar la TCEA de la tarjeta'
                        : 'Agregar la tasa',
                  ),
                ),
              ),
            ),
          if (!esTarjeta)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _registrarPago(context, ref, primera),
                  child: Text(
                    'Registrar pago',
                    semanticsLabel: 'Registrar pago de $nombre',
                  ),
                ),
              ),
            ),
          // Fase 85: la tarjeta se paga con una transferencia (no cuenta
          // como gasto); "Se actualiza con los movimientos…" queda arriba
          // como ayuda.
          if (esTarjeta)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: () => _pagarTarjeta(context, ref, primera),
                  child: Text(
                    'Pagar tarjeta',
                    semanticsLabel: 'Pagar tarjeta $nombre',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Fase 85 — abre la transferencia hacia la tarjeta. Monto sugerido:
  /// el mínimo, más el extra del plan si es la primera deuda; nunca más de
  /// lo que se debe.
  Future<void> _pagarTarjeta(
    BuildContext context,
    WidgetRef ref,
    bool primera,
  ) async {
    final deuda = resultado.deuda;
    final extra = primera ? plan.extraMensual : 0.0;
    final saldo = saldoPendiente(deuda);
    final sugerido = resultado.pagoMinimoMensual + extra;
    await Navigator.of(context).pushNamed(
      '/transferencias/nueva',
      arguments: TransferenciaRouteArgs(
        destinoId: deuda.cuentaId,
        montoSugerido: sugerido <= 0
            ? null
            : (sugerido > saldo ? saldo : sugerido),
      ),
    );
    ref.invalidate(deudasProvider);
  }

  /// Abre la pantalla de pago. En cuotas fijas, con "Abono a capital"
  /// preseleccionado; la primera deuda lleva el extra del plan como
  /// sugerencia editable (en pago libre, mínimo + extra). Al volver, el
  /// plan se recalcula con la deuda ya actualizada.
  Future<void> _registrarPago(
    BuildContext context,
    WidgetRef ref,
    bool primera,
  ) async {
    final deuda = resultado.deuda;
    final esCuotas = deuda.estructuraPago == EstructuraPago.cuotasFijas;
    final extra = primera ? plan.extraMensual : 0.0;
    final sugerido = esCuotas
        ? (extra > 0 ? extra : null)
        : (resultado.pagoMinimoMensual + extra > 0
              ? resultado.pagoMinimoMensual + extra
              : null);
    final saldo = saldoPendiente(deuda);
    await Navigator.of(context).pushNamed(
      '/deudas/pago',
      arguments: PagoDeudaRouteArgs(
        deudaId: deuda.id,
        modoInicial: esCuotas ? ModoPagoDeuda.abono : null,
        montoEsperadoInicial: sugerido == null
            ? null
            : (sugerido > saldo ? saldo : sugerido),
      ),
    );
    ref.invalidate(deudasProvider);
  }
}

/// Monedas que no son la principal: resumen compacto (sin pago extra).
class _OtraMoneda extends StatelessWidget {
  const _OtraMoneda({
    required this.comparacion,
    required this.estrategia,
    required this.ahora,
  });

  final ComparacionPlanes comparacion;
  final EstrategiaPago estrategia;
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = comparacion.plan(estrategia);
    final fecha = fechaLibre(plan, ahora);
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Deudas en ${simboloMoneda(comparacion.moneda)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fecha == null
                ? 'A este ritmo no terminas de pagarlas.'
                : 'Libre en ${formatearMesAnio(fecha)} (aprox.), sin pago '
                      'extra. Se calculan aparte: nunca se suman monedas.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TonoAviso { neutro, aviso }

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icono, required this.texto, required this.tono});

  final IconData icono;
  final String texto;
  final _TonoAviso tono;

  @override
  Widget build(BuildContext context) {
    final (color, fondo) = tono == _TonoAviso.aviso
        ? (context.warningText, context.warningBg)
        : (context.textSecondary, context.borderCard);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: tono == _TonoAviso.aviso ? color : context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 48, color: context.successText),
            const SizedBox(height: 12),
            Text(
              'No tienes deudas que planificar',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando registres una deuda que debes, aquí verás en qué orden '
              'pagarla y cuándo podrías quedar libre.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.of(
                context,
              ).pushNamed('/deudas/nueva', arguments: DireccionDeuda.debo),
              icon: const Icon(Icons.add),
              label: const Text('Agregar deuda'),
            ),
          ],
        ),
      ),
    );
  }
}
