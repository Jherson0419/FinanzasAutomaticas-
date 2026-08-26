import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/cronograma_cuotas.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../shared/enum_labels.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import '../theme/app_theme.dart';

/// Formulario de deuda, reutilizado por [DeudaNuevaScreen] (crear/editar,
/// según [deudaId]) y por el paso de deudas del wizard de onboarding
/// (siempre en modo creación).
class DeudaFormulario extends ConsumerStatefulWidget {
  const DeudaFormulario({
    super.key,
    this.deudaId,
    required this.onGuardadoExitoso,
  });

  /// Si no es nulo, el formulario carga esa deuda y edita en vez de crear.
  final String? deudaId;

  /// Se invoca después de guardar con éxito.
  final VoidCallback onGuardadoExitoso;

  @override
  ConsumerState<DeudaFormulario> createState() => _DeudaFormularioState();
}

class _DeudaFormularioState extends ConsumerState<DeudaFormulario> {
  final _nombreController = TextEditingController();
  final _nombreAcreedorController = TextEditingController();
  final _montoTotalController = TextEditingController();
  final _tasaInteresController = TextEditingController();
  final _numeroCuotasController = TextEditingController();
  final _montoCuotaController = TextEditingController();
  final _pagoMinimoController = TextEditingController();
  final _notasController = TextEditingController();

  TipoDeuda _tipoDeuda = TipoDeuda.prestamoPersonal;
  TipoAcreedor _tipoAcreedor = TipoAcreedor.entidadFinanciera;
  Moneda _moneda = Moneda.pen;
  DateTime _fechaInicio = DateTime.now();
  bool _tieneInteres = false;
  TipoTasa _tipoTasa = TipoTasa.fija;
  EstructuraPago _estructuraPago = EstructuraPago.cuotasFijas;
  PeriodicidadCuota _periodicidadCuotas = PeriodicidadCuota.mensual;
  bool _guardando = false;
  bool _valoresPrecargados = false;

  /// Fase 64: vincular la deuda a un amigo de Finzo, solo disponible con
  /// `_tipoAcreedor == personaNatural` — opcional incluso ahí (la mayoría
  /// de las deudas con una persona natural no son con un amigo dentro de
  /// la app).
  bool _esAmigo = false;
  String? _amigoUsuarioId;

  bool get _editando => widget.deudaId != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _nombreAcreedorController.dispose();
    _montoTotalController.dispose();
    _tasaInteresController.dispose();
    _numeroCuotasController.dispose();
    _montoCuotaController.dispose();
    _pagoMinimoController.dispose();
    _notasController.dispose();
    super.dispose();
  }

  double? _parseDouble(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  bool get _esCuotasFijas => _estructuraPago == EstructuraPago.cuotasFijas;

  /// Interés total estimado (monto de cuota × número de cuotas − monto
  /// total); `null` si aún faltan datos para calcularlo.
  double? get _interesTotalPreview {
    final montoTotal = _parseDouble(_montoTotalController.text);
    final montoCuota = _parseDouble(_montoCuotaController.text);
    final numeroCuotas = int.tryParse(_numeroCuotasController.text.trim());
    if (montoTotal == null || montoCuota == null || numeroCuotas == null) {
      return null;
    }
    return (montoCuota * numeroCuotas) - montoTotal;
  }

  /// Fecha de vencimiento de la última cuota, calculada a partir del
  /// cronograma; `null` si aún faltan datos para calcularla.
  DateTime? get _fechaVencimientoEstimadaPreview {
    final montoCuota = _parseDouble(_montoCuotaController.text);
    final numeroCuotas = int.tryParse(_numeroCuotasController.text.trim());
    if (montoCuota == null || numeroCuotas == null || numeroCuotas <= 0) {
      return null;
    }
    final cronograma = generarCronogramaCuotas(
      Deuda(
        id: '',
        nombreDeuda: '',
        tipoDeuda: _tipoDeuda,
        tipoAcreedor: _tipoAcreedor,
        nombreAcreedor: '',
        moneda: _moneda,
        montoTotal: _parseDouble(_montoTotalController.text) ?? 0,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: numeroCuotas,
        montoCuota: montoCuota,
        periodicidadCuotas: _periodicidadCuotas,
        fechaInicio: _fechaInicio,
        enMora: false,
        estado: EstadoDeuda.activa,
      ),
      const [],
    );
    return fechaVencimientoFinalDesdeCronograma(cronograma);
  }

  bool get _esValido {
    if (_nombreController.text.trim().isEmpty) return false;
    if (_nombreAcreedorController.text.trim().isEmpty) return false;

    final montoTotal = _parseDouble(_montoTotalController.text);
    if (montoTotal == null || montoTotal <= 0) return false;

    if (_esCuotasFijas) {
      final cuotas = int.tryParse(_numeroCuotasController.text.trim());
      final montoCuota = _parseDouble(_montoCuotaController.text);
      if (cuotas == null || cuotas <= 0) return false;
      if (montoCuota == null || montoCuota <= 0) return false;
    } else if (_tieneInteres) {
      final tasa = _parseDouble(_tasaInteresController.text);
      if (tasa == null || tasa <= 0) return false;
    }

    if (_tipoAcreedor == TipoAcreedor.personaNatural &&
        _esAmigo &&
        _amigoUsuarioId == null) {
      return false;
    }

    return true;
  }

  void _precargar(Deuda deuda) {
    if (_valoresPrecargados) return;
    _valoresPrecargados = true;
    _nombreController.text = deuda.nombreDeuda;
    _nombreAcreedorController.text = deuda.nombreAcreedor;
    _montoTotalController.text = deuda.montoTotal.toStringAsFixed(2);
    _tasaInteresController.text = deuda.tasaInteres?.toStringAsFixed(2) ?? '';
    _numeroCuotasController.text = deuda.numeroCuotasTotal?.toString() ?? '';
    _montoCuotaController.text = deuda.montoCuota?.toStringAsFixed(2) ?? '';
    _pagoMinimoController.text = deuda.pagoMinimo?.toStringAsFixed(2) ?? '';
    _notasController.text = deuda.notas ?? '';
    _tipoDeuda = deuda.tipoDeuda;
    _tipoAcreedor = deuda.tipoAcreedor;
    _moneda = deuda.moneda;
    _fechaInicio = deuda.fechaInicio;
    _tieneInteres = deuda.tieneInteres;
    _tipoTasa = deuda.tipoTasa ?? TipoTasa.fija;
    _estructuraPago = deuda.estructuraPago;
    _periodicidadCuotas = deuda.periodicidadCuotas ?? PeriodicidadCuota.mensual;
    _esAmigo = deuda.amigoUsuarioId != null;
    _amigoUsuarioId = deuda.amigoUsuarioId;
  }

  Future<void> _seleccionarFechaInicio() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (seleccionada != null) setState(() => _fechaInicio = seleccionada);
  }

  void _reiniciar() {
    _nombreController.clear();
    _nombreAcreedorController.clear();
    _montoTotalController.clear();
    _tasaInteresController.clear();
    _numeroCuotasController.clear();
    _montoCuotaController.clear();
    _pagoMinimoController.clear();
    _notasController.clear();
    setState(() {
      _tipoDeuda = TipoDeuda.prestamoPersonal;
      _tipoAcreedor = TipoAcreedor.entidadFinanciera;
      _moneda = Moneda.pen;
      _fechaInicio = DateTime.now();
      _tieneInteres = false;
      _tipoTasa = TipoTasa.fija;
      _estructuraPago = EstructuraPago.cuotasFijas;
      _periodicidadCuotas = PeriodicidadCuota.mensual;
      _esAmigo = false;
      _amigoUsuarioId = null;
    });
  }

  Future<void> _guardar() async {
    if (!_esValido) return;

    setState(() => _guardando = true);
    try {
      final montoTotal = _parseDouble(_montoTotalController.text)!;
      final numeroCuotasTotal = _esCuotasFijas
          ? int.tryParse(_numeroCuotasController.text.trim())
          : null;
      final montoCuota = _esCuotasFijas
          ? _parseDouble(_montoCuotaController.text)
          : null;
      final pagoMinimo = !_esCuotasFijas
          ? _parseDouble(_pagoMinimoController.text)
          : null;
      final tieneInteresPagoLibre = !_esCuotasFijas && _tieneInteres;
      final tasaInteres = tieneInteresPagoLibre
          ? _parseDouble(_tasaInteresController.text)
          : null;
      final notas = _notasController.text.trim();
      final amigoUsuarioId =
          (_tipoAcreedor == TipoAcreedor.personaNatural && _esAmigo)
          ? _amigoUsuarioId
          : null;

      if (_editando) {
        await ref.read(editarDeudaProvider)(
          deudaId: widget.deudaId!,
          nombreDeuda: _nombreController.text.trim(),
          tipoDeuda: _tipoDeuda,
          tipoAcreedor: _tipoAcreedor,
          nombreAcreedor: _nombreAcreedorController.text.trim(),
          moneda: _moneda,
          montoTotal: montoTotal,
          tieneInteres: tieneInteresPagoLibre,
          tasaInteres: tasaInteres,
          tipoTasa: tieneInteresPagoLibre ? _tipoTasa : null,
          estructuraPago: _estructuraPago,
          numeroCuotasTotal: numeroCuotasTotal,
          montoCuota: montoCuota,
          pagoMinimo: pagoMinimo,
          periodicidadCuotas: _esCuotasFijas ? _periodicidadCuotas : null,
          fechaInicio: _fechaInicio,
          diaPago: null,
          notas: notas.isEmpty ? null : notas,
          amigoUsuarioId: amigoUsuarioId,
        );
        ref.invalidate(deudaPorIdProvider(widget.deudaId!));
      } else {
        await ref.read(registrarDeudaProvider)(
          nombreDeuda: _nombreController.text.trim(),
          tipoDeuda: _tipoDeuda,
          tipoAcreedor: _tipoAcreedor,
          nombreAcreedor: _nombreAcreedorController.text.trim(),
          moneda: _moneda,
          montoTotal: montoTotal,
          tieneInteres: tieneInteresPagoLibre,
          tasaInteres: tasaInteres,
          tipoTasa: tieneInteresPagoLibre ? _tipoTasa : null,
          estructuraPago: _estructuraPago,
          numeroCuotasTotal: numeroCuotasTotal,
          montoCuota: montoCuota,
          pagoMinimo: pagoMinimo,
          periodicidadCuotas: _esCuotasFijas ? _periodicidadCuotas : null,
          fechaInicio: _fechaInicio,
          diaPago: null,
          notas: notas.isEmpty ? null : notas,
          amigoUsuarioId: amigoUsuarioId,
        );
      }

      ref.invalidate(deudasProvider);
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      if (!_editando) _reiniciar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editando ? 'Deuda actualizada' : 'Deuda registrada'),
        ),
      );
      widget.onGuardadoExitoso();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.deudaId != null) {
      final deudaAsync = ref.watch(deudaPorIdProvider(widget.deudaId!));
      return deudaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudo cargar la deuda.\n$error')),
        data: (deuda) {
          if (deuda == null) {
            return const Center(child: Text('Esta deuda ya no existe.'));
          }
          _precargar(deuda);
          return _construirCampos(context);
        },
      );
    }
    return _construirCampos(context);
  }

  Widget _construirCampos(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la deuda',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TipoDeuda>(
          initialValue: _tipoDeuda,
          decoration: const InputDecoration(
            labelText: 'Tipo de deuda',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final tipo in TipoDeuda.values)
              DropdownMenuItem(value: tipo, child: Text(labelTipoDeuda(tipo))),
          ],
          onChanged: (valor) =>
              setState(() => _tipoDeuda = valor ?? _tipoDeuda),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TipoAcreedor>(
          initialValue: _tipoAcreedor,
          decoration: const InputDecoration(
            labelText: 'Tipo de acreedor',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final tipo in TipoAcreedor.values)
              DropdownMenuItem(
                value: tipo,
                child: Text(labelTipoAcreedor(tipo)),
              ),
          ],
          onChanged: (valor) =>
              setState(() => _tipoAcreedor = valor ?? _tipoAcreedor),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nombreAcreedorController,
          decoration: InputDecoration(
            labelText: 'Nombre del acreedor',
            hintText: placeholderNombreAcreedor(_tipoAcreedor),
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_tipoAcreedor == TipoAcreedor.personaNatural) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('¿Es un amigo de Finzo?'),
            value: _esAmigo,
            onChanged: (valor) => setState(() {
              _esAmigo = valor;
              if (!valor) _amigoUsuarioId = null;
            }),
          ),
          if (_esAmigo) _construirSelectorAmigo(theme),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<Moneda>(
          initialValue: _moneda,
          decoration: const InputDecoration(
            labelText: 'Moneda',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final moneda in Moneda.values)
              DropdownMenuItem(value: moneda, child: Text(labelMoneda(moneda))),
          ],
          onChanged: (valor) => setState(() => _moneda = valor ?? _moneda),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _montoTotalController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto total',
            prefixText: '${simboloMoneda(_moneda)} ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fecha de inicio'),
          subtitle: Text(formatearFecha(_fechaInicio)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _seleccionarFechaInicio,
        ),
        const SizedBox(height: 8),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text('Estructura de pago', style: theme.textTheme.titleSmall),
        ),
        SegmentedButton<EstructuraPago>(
          segments: const [
            ButtonSegment(
              value: EstructuraPago.cuotasFijas,
              label: Text('Cuotas fijas'),
            ),
            ButtonSegment(
              value: EstructuraPago.pagoLibre,
              label: Text('Pago libre'),
            ),
          ],
          selected: {_estructuraPago},
          onSelectionChanged: (seleccion) =>
              setState(() => _estructuraPago = seleccion.first),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _esCuotasFijas
              ? _construirCamposCuotasFijas(theme)
              : _construirCamposPagoLibre(theme),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notasController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notas (opcional)',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: (_esValido && !_guardando) ? _guardar : null,
          child: _guardando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : Text(_editando ? 'Guardar cambios' : 'Guardar'),
        ),
      ],
    );
  }

  /// Fase 64 — selector de amigo cuando `¿Es un amigo de Finzo?` está
  /// activo: reutiliza `amigosProvider` (Fase 63) en vez de una búsqueda
  /// nueva, porque solo tiene sentido vincular a alguien que ya es amigo
  /// aceptado, no a cualquier usuario de la app.
  Widget _construirSelectorAmigo(ThemeData theme) {
    final amigosAsync = ref.watch(amigosProvider);
    return amigosAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No se pudo cargar tu lista de amigos.',
          style: theme.textTheme.bodySmall?.copyWith(color: colorDanger),
        ),
      ),
      data: (amigos) {
        if (amigos.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Todavía no tienes amigos agregados en Finzo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: DropdownButtonFormField<String>(
            initialValue: _amigoUsuarioId,
            decoration: const InputDecoration(
              labelText: 'Selecciona a tu amigo',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final amigo in amigos)
                DropdownMenuItem(
                  value: amigo.usuarioId,
                  child: Text(
                    amigo.nick != null ? '@${amigo.nick}' : 'Sin nick',
                  ),
                ),
            ],
            onChanged: (valor) => setState(() => _amigoUsuarioId = valor),
          ),
        );
      },
    );
  }

  Widget _construirCamposCuotasFijas(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final interesTotal = _interesTotalPreview;
    final fechaVencimientoEstimada = _fechaVencimientoEstimadaPreview;

    return Column(
      key: const ValueKey('cuotas_fijas'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        TextFormField(
          controller: _numeroCuotasController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de cuotas',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _montoCuotaController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto de cuota',
            prefixText: '${simboloMoneda(_moneda)} ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PeriodicidadCuota>(
          initialValue: _periodicidadCuotas,
          decoration: const InputDecoration(
            labelText: 'Periodicidad de cuotas',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final periodicidad in PeriodicidadCuota.values)
              DropdownMenuItem(
                value: periodicidad,
                child: Text(labelPeriodicidadCuota(periodicidad)),
              ),
          ],
          onChanged: (valor) => setState(
            () => _periodicidadCuotas = valor ?? _periodicidadCuotas,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                interesTotal == null
                    ? 'Interés total: —'
                    : (interesTotal > 0
                          ? 'Interés total: ${formatearMonto(interesTotal, _moneda)}'
                          : 'Sin interés'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                fechaVencimientoEstimada == null
                    ? 'Fecha de vencimiento estimada: —'
                    : 'Fecha de vencimiento estimada: ${formatearFecha(fechaVencimientoEstimada)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirCamposPagoLibre(ThemeData theme) {
    return Column(
      key: const ValueKey('pago_libre'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('¿Tiene interés?'),
          value: _tieneInteres,
          onChanged: (valor) => setState(() => _tieneInteres = valor),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: !_tieneInteres
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tasaInteresController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Tasa de interés (%)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<TipoTasa>(
                      initialValue: _tipoTasa,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de tasa',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final tipo in TipoTasa.values)
                          DropdownMenuItem(
                            value: tipo,
                            child: Text(labelTipoTasa(tipo)),
                          ),
                      ],
                      onChanged: (valor) =>
                          setState(() => _tipoTasa = valor ?? _tipoTasa),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pagoMinimoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Pago mínimo (opcional)',
            prefixText: '${simboloMoneda(_moneda)} ',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
