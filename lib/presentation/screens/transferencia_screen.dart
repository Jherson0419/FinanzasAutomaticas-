import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/entities/transaccion.dart';
import '../../domain/usecases/registrar_transferencia.dart';
import '../shared/app_card.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';

/// Argumentos de `/transferencias/nueva` (Fase 85). "Pagar tarjeta" abre
/// la pantalla con [destinoId] = la tarjeta y, desde el plan, con
/// [montoSugerido] = mínimo + extra.
class TransferenciaRouteArgs {
  const TransferenciaRouteArgs({
    this.origenId,
    this.destinoId,
    this.montoSugerido,
  });

  final String? origenId;
  final String? destinoId;
  final double? montoSugerido;
}

/// Monto usado de una tarjeta (lo que se debe): `|saldo|` si es negativo.
double usadoDeTarjeta(Cuenta cuenta) =>
    cuenta.saldoActual < 0 ? -cuenta.saldoActual : 0;

/// Invalida todo lo que cambia tras crear o borrar una transferencia.
void refrescarTrasTransferencia(WidgetRef ref, Iterable<String> cuentaIds) {
  for (final id in cuentaIds) {
    ref.invalidate(cuentaPorIdProvider(id));
    ref.invalidate(transaccionesPorCuentaProvider(id));
  }
  ref.invalidate(cuentasProvider);
  ref.invalidate(todasLasTransaccionesProvider);
  ref.invalidate(resumenDashboardProvider);
  // La deuda de una tarjeta se sincroniza con su saldo.
  ref.invalidate(deudasProvider);
}

/// Fase 85 — mover dinero entre cuentas propias (no es ingreso ni gasto).
/// Con destino una tarjeta de crédito es "Pagar tarjeta": chips de monto
/// "Pago mínimo", "Deuda total" y "Otro monto".
class TransferenciaScreen extends ConsumerStatefulWidget {
  const TransferenciaScreen({
    super.key,
    this.origenId,
    this.destinoId,
    this.montoSugerido,
  });

  final String? origenId;
  final String? destinoId;
  final double? montoSugerido;

  @override
  ConsumerState<TransferenciaScreen> createState() =>
      _TransferenciaScreenState();
}

class _TransferenciaScreenState extends ConsumerState<TransferenciaScreen> {
  final _montoController = TextEditingController();
  final _notaController = TextEditingController();
  final _montoFocus = FocusNode();
  String? _origenId;
  String? _destinoId;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  bool _iniciado = false;

  @override
  void dispose() {
    _montoController.dispose();
    _notaController.dispose();
    _montoFocus.dispose();
    super.dispose();
  }

  double? get _monto {
    final texto = _montoController.text.trim().replaceAll(',', '.');
    return texto.isEmpty ? null : double.tryParse(texto);
  }

  void _iniciar(List<Cuenta> cuentas) {
    if (_iniciado) return;
    _iniciado = true;
    final porId = {for (final c in cuentas) c.id: c};
    _destinoId = porId.containsKey(widget.destinoId) ? widget.destinoId : null;
    final destino = porId[_destinoId];
    if (porId.containsKey(widget.origenId)) {
      _origenId = widget.origenId;
    } else {
      // Por defecto: la primera cuenta de fondos (no tarjeta) en la moneda
      // del destino.
      final candidatas = cuentas.where(
        (c) =>
            c.id != _destinoId &&
            (destino == null || c.moneda == destino.moneda),
      );
      _origenId =
          (candidatas.where((c) => c.tipo != TipoCuenta.credito).firstOrNull ??
                  candidatas.firstOrNull)
              ?.id;
    }
    final sugerido = widget.montoSugerido;
    if (sugerido != null && sugerido > 0) {
      _montoController.text = sugerido.toStringAsFixed(2);
    }
  }

  /// Error de validación visible, o `null`.
  String? _error(Map<String, Cuenta> porId) {
    final origen = porId[_origenId];
    final destino = porId[_destinoId];
    if (origen != null && destino != null) {
      if (origen.id == destino.id) return 'Elige dos cuentas distintas.';
      if (origen.moneda != destino.moneda) {
        return 'Las dos cuentas deben estar en la misma moneda.';
      }
    }
    final monto = _monto;
    if (_montoController.text.trim().isNotEmpty &&
        (monto == null || monto <= 0)) {
      return 'El monto debe ser mayor a 0.';
    }
    return null;
  }

  bool _esValido(Map<String, Cuenta> porId) =>
      porId[_origenId] != null &&
      porId[_destinoId] != null &&
      (_monto ?? 0) > 0 &&
      _error(porId) == null;

  Future<void> _seleccionarFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _guardar(Map<String, Cuenta> porId) async {
    if (!_esValido(porId) || _guardando) return;
    setState(() => _guardando = true);
    final ids = [_origenId!, _destinoId!];
    String? aviso;
    try {
      await ref.read(registrarTransferenciaProvider)(
        origenId: _origenId!,
        destinoId: _destinoId!,
        monto: _monto!,
        fecha: _fecha,
        nota: _notaController.text,
      );
      aviso = porId[_destinoId]!.tipo == TipoCuenta.credito
          ? 'Pago a la tarjeta registrado'
          : 'Transferencia registrada';
    } on TransferenciaIncompleta catch (e) {
      // Algo quedó escrito: se refresca igual y se dice qué.
      aviso = e.mensaje;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo registrar la transferencia: ${mensajeDeError(e)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
    if (aviso == null) return;
    refrescarTrasTransferencia(ref, ids);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);
    final destino = cuentasAsync.valueOrNull
        ?.where((c) => c.id == (_destinoId ?? widget.destinoId))
        .firstOrNull;
    final esPagoTarjeta = destino?.tipo == TipoCuenta.credito;
    return Scaffold(
      appBar: AppBar(
        title: Text(esPagoTarjeta ? 'Pagar tarjeta' : 'Transferencia'),
      ),
      body: SafeArea(
        child: cuentasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('No se pudieron cargar las cuentas.\n$e')),
          data: (cuentas) {
            _iniciar(cuentas);
            return _formulario(cuentas);
          },
        ),
      ),
    );
  }

  Widget _formulario(List<Cuenta> cuentas) {
    final theme = Theme.of(context);
    final porId = {for (final c in cuentas) c.id: c};
    final origen = porId[_origenId];
    final destino = porId[_destinoId];
    final error = _error(porId);

    if (cuentas.length < 2) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Necesitas al menos dos cuentas para transferir. Crea otra '
            'desde "Mis cuentas".',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Destinos posibles: otra cuenta, en la moneda del origen.
    final destinos = [
      for (final c in cuentas)
        if (c.id != _origenId && (origen == null || c.moneda == origen.moneda))
          c,
    ];

    DropdownMenuItem<String> item(Cuenta c) => DropdownMenuItem(
      value: c.id,
      child: Text(
        '${c.nombre} · ${formatearMonto(c.saldoActual, c.moneda)}',
        overflow: TextOverflow.ellipsis,
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('transferencia-origen'),
          isExpanded: true,
          initialValue: _origenId,
          decoration: const InputDecoration(
            labelText: 'Desde',
            border: OutlineInputBorder(),
          ),
          items: [for (final c in cuentas) item(c)],
          onChanged: _guardando
              ? null
              : (id) => setState(() {
                  _origenId = id;
                  final o = porId[id];
                  final d = porId[_destinoId];
                  // Un destino que ya no sirve se limpia.
                  if (d != null &&
                      (d.id == id || (o != null && d.moneda != o.moneda))) {
                    _destinoId = null;
                  }
                }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // La clave cambia con el origen para que el campo se reconstruya
          // si su valor se limpió.
          key: ValueKey('transferencia-destino-$_origenId-$_destinoId'),
          isExpanded: true,
          initialValue: destinos.any((c) => c.id == _destinoId)
              ? _destinoId
              : null,
          decoration: const InputDecoration(
            labelText: 'Hacia',
            border: OutlineInputBorder(),
          ),
          items: [for (final c in destinos) item(c)],
          onChanged: _guardando
              ? null
              : (id) => setState(() => _destinoId = id),
        ),
        const SizedBox(height: 16),
        if (destino != null && destino.tipo == TipoCuenta.credito) ...[
          _ChipsPagoTarjeta(
            tarjeta: destino,
            montoActual: _monto,
            onElegir: (monto) => setState(() {
              if (monto == null) {
                _montoController.clear();
                _montoFocus.requestFocus();
              } else {
                _montoController.text = monto.toStringAsFixed(2);
              }
            }),
          ),
          const SizedBox(height: 12),
        ],
        TextFormField(
          controller: _montoController,
          focusNode: _montoFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto',
            prefixText: origen == null ? null : '${simboloMoneda(origen.moneda)} ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fecha'),
          subtitle: Text(formatearFecha(_fecha)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _seleccionarFecha,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _notaController,
          decoration: const InputDecoration(
            labelText: 'Nota (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Una transferencia entre tus cuentas no cuenta como ingreso ni '
          'como gasto.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: _esValido(porId) && !_guardando
              ? () => _guardar(porId)
              : null,
          child: _guardando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Text('Transferir'),
        ),
      ],
    );
  }
}

/// "Pago mínimo S/ X" (si la tarjeta lo tiene), "Deuda total S/ Y" (si
/// debe algo) y "Otro monto" (limpia el campo y lo enfoca).
class _ChipsPagoTarjeta extends StatelessWidget {
  const _ChipsPagoTarjeta({
    required this.tarjeta,
    required this.montoActual,
    required this.onElegir,
  });

  final Cuenta tarjeta;
  final double? montoActual;

  /// `null` = "Otro monto".
  final ValueChanged<double?> onElegir;

  @override
  Widget build(BuildContext context) {
    final minimo = tarjeta.pagoMinimo;
    final total = usadoDeTarjeta(tarjeta);
    bool igual(double v) =>
        montoActual != null && (montoActual! - v).abs() < 0.005;
    final opciones = <(String, double?)>[
      if (minimo != null && minimo > 0)
        ('Pago mínimo ${formatearMonto(minimo, tarjeta.moneda)}', minimo),
      if (total > 0)
        ('Deuda total ${formatearMonto(total, tarjeta.moneda)}', total),
      ('Otro monto', null),
    ];
    final algunoElegido = opciones.any((o) => o.$2 != null && igual(o.$2!));
    return Semantics(
      container: true,
      label: 'Cuánto pagar',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (texto, valor) in opciones)
            ChoiceChip(
              label: Text(texto, style: estiloMonto(null)),
              selected: valor == null
                  ? (montoActual != null && !algunoElegido)
                  : igual(valor),
              materialTapTargetSize: MaterialTapTargetSize.padded,
              onSelected: (_) => onElegir(valor),
            ),
        ],
      ),
    );
  }
}

/// Fase 85 — detalle de una transferencia ya registrada: no se edita; se
/// puede eliminar (borra los dos movimientos y revierte ambos saldos).
class TransferenciaDetalleScreen extends ConsumerStatefulWidget {
  const TransferenciaDetalleScreen({super.key, required this.transferenciaId});

  final String transferenciaId;

  @override
  ConsumerState<TransferenciaDetalleScreen> createState() =>
      _TransferenciaDetalleScreenState();
}

class _TransferenciaDetalleScreenState
    extends ConsumerState<TransferenciaDetalleScreen> {
  bool _eliminando = false;

  Future<void> _eliminar(List<Transaccion> caras, String resumen) async {
    final confirmado = await confirmarEliminar(
      context,
      titulo: 'Eliminar transferencia',
      mensaje:
          '¿Eliminar $resumen? Se borran los dos movimientos y se '
          'revierten los saldos de ambas cuentas.',
    );
    if (!confirmado || !mounted) return;
    setState(() => _eliminando = true);
    try {
      await ref.read(eliminarTransferenciaProvider)(
        transferenciaId: widget.transferenciaId,
      );
      refrescarTrasTransferencia(ref, caras.map((t) => t.cuentaId));
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      await mostrarErrorEliminar(context, e);
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transacciones = ref.watch(todasLasTransaccionesProvider);
    final cuentas = ref.watch(cuentasProvider).valueOrNull ?? const [];
    final nombre = {for (final c in cuentas) c.id: c.nombre};
    return Scaffold(
      appBar: AppBar(title: const Text('Transferencia')),
      body: SafeArea(
        child: transacciones.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('No se pudo cargar.\n$e')),
          data: (todas) {
            final caras = todas
                .where((t) => t.transferenciaId == widget.transferenciaId)
                .toList();
            if (caras.isEmpty) {
              return const Center(
                child: Text('Esta transferencia ya no existe.'),
              );
            }
            final salida = caras
                .where((t) => t.tipo == TipoTransaccion.transferenciaSalida)
                .firstOrNull;
            final entrada = caras
                .where((t) => t.tipo == TipoTransaccion.transferenciaEntrada)
                .firstOrNull;
            final base = salida ?? entrada!;
            final monto = formatearMonto(base.monto, base.moneda);
            final desde = salida == null ? '—' : nombre[salida.cuentaId] ?? '—';
            final hacia = entrada == null
                ? '—'
                : nombre[entrada.cuentaId] ?? '—';
            final nota = base.concepto == conceptoTransferencia
                ? null
                : base.concepto;
            Widget fila(String etiqueta, String valor) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: MergeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        etiqueta,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        valor,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.swap_horiz),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              monto,
                              style: estiloMonto(
                                theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      fila('Desde', desde),
                      fila('Hacia', hacia),
                      fila('Fecha', formatearFecha(base.fecha)),
                      if (nota != null) fila('Nota', nota),
                      if (salida == null || entrada == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Esta transferencia quedó a medias. Elimínala y '
                            'vuelve a registrarla.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Una transferencia no se edita: elimínala y vuelve a '
                  'crearla.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _eliminando
                      ? null
                      : () => _eliminar(
                          caras,
                          'la transferencia de $monto de $desde a $hacia',
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar transferencia'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
