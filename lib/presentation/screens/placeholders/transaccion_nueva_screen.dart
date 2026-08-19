import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/categoria.dart';
import '../../../domain/entities/cuenta.dart';
import '../../../domain/entities/transaccion.dart';
import '../../state/dashboard/dashboard_providers.dart';
import '../../state/providers.dart';
import '../../shared/dialogos_eliminar.dart';
import '../../shared/enum_labels.dart';
import '../../shared/formatters.dart';
import '../../shared/mensajes_error.dart';
import '../categoria_formulario.dart';

/// Valor sentinela del último ítem del dropdown de categoría — nunca
/// coincide con un id real (uuid v4), así que es seguro distinguirlo de una
/// categoría de verdad seleccionada.
const _valorCrearCategoria = '__crear_categoria__';

class TransaccionNuevaScreen extends ConsumerStatefulWidget {
  const TransaccionNuevaScreen({super.key, this.transaccionId});

  /// Si no es nulo, la pantalla abre en modo edición sobre esta transacción.
  final String? transaccionId;

  @override
  ConsumerState<TransaccionNuevaScreen> createState() =>
      _TransaccionNuevaScreenState();
}

class _TransaccionNuevaScreenState
    extends ConsumerState<TransaccionNuevaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _conceptoController = TextEditingController();

  TipoTransaccion _tipo = TipoTransaccion.gasto;
  String? _cuentaId;
  String? _categoriaId;
  MetodoPago _metodoPago = MetodoPago.efectivo;
  bool _esRecurrente = false;
  DateTime _fecha = DateTime.now();
  bool _guardando = false;
  bool _eliminando = false;
  bool _valoresPrecargados = false;
  Transaccion? _original;

  bool get _editando => widget.transaccionId != null;

  @override
  void dispose() {
    _montoController.dispose();
    _conceptoController.dispose();
    super.dispose();
  }

  bool get _esValido {
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));
    return monto != null &&
        monto > 0 &&
        _cuentaId != null &&
        _categoriaId != null;
  }

  Cuenta? _buscarCuenta(List<Cuenta> cuentas, String? id) {
    for (final cuenta in cuentas) {
      if (cuenta.id == id) return cuenta;
    }
    return null;
  }

  void _precargar(Transaccion transaccion) {
    if (_valoresPrecargados) return;
    _valoresPrecargados = true;
    _original = transaccion;
    _tipo = transaccion.tipo;
    _cuentaId = transaccion.cuentaId;
    _categoriaId = transaccion.categoriaId;
    _montoController.text = transaccion.monto.toStringAsFixed(2);
    _conceptoController.text = transaccion.concepto;
    _metodoPago = transaccion.metodoPago;
    _esRecurrente = transaccion.esRecurrente;
    _fecha = transaccion.fecha;
  }

  Future<void> _abrirCrearCategoriaRapida(TipoCategoria tipoFijo) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nueva categoría',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              CategoriaFormulario(
                tipoFijo: tipoFijo,
                onGuardadoExitoso: (categoria) {
                  Navigator.of(context).pop();
                  if (!mounted) return;
                  setState(() => _categoriaId = categoria.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (seleccionada != null) {
      setState(() => _fecha = seleccionada);
    }
  }

  Future<void> _guardar(List<Cuenta> cuentas) async {
    if (!_esValido) return;
    final cuenta = _buscarCuenta(cuentas, _cuentaId);
    if (cuenta == null) return;

    setState(() => _guardando = true);
    final monto = double.parse(_montoController.text.replaceAll(',', '.'));
    try {
      if (_editando) {
        await ref.read(editarTransaccionProvider)(
          transaccionId: widget.transaccionId!,
          cuentaId: _cuentaId!,
          categoriaId: _categoriaId!,
          monto: monto,
          moneda: cuenta.moneda,
          tipo: _tipo,
          concepto: _conceptoController.text.trim(),
          metodoPago: _metodoPago,
          esRecurrente: _esRecurrente,
          fecha: _fecha,
        );
        ref.invalidate(transaccionPorIdProvider(widget.transaccionId!));
        // EditarTransaccion puede tocar el saldo de la cuenta original y/o
        // la nueva (si se cambió de cuenta) — invalidar ambas puntuales.
        ref.invalidate(cuentaPorIdProvider(_original!.cuentaId));
        if (_cuentaId != _original!.cuentaId) {
          ref.invalidate(cuentaPorIdProvider(_cuentaId!));
        }
      } else if (_tipo == TipoTransaccion.gasto) {
        await ref.read(registrarGastoProvider)(
          cuentaId: _cuentaId!,
          categoriaId: _categoriaId!,
          monto: monto,
          moneda: cuenta.moneda,
          concepto: _conceptoController.text.trim(),
          metodoPago: _metodoPago,
          esRecurrente: _esRecurrente,
          fecha: _fecha,
        );
        ref.invalidate(cuentaPorIdProvider(_cuentaId!));
      } else {
        await ref.read(registrarIngresoProvider)(
          cuentaId: _cuentaId!,
          categoriaId: _categoriaId!,
          monto: monto,
          moneda: cuenta.moneda,
          concepto: _conceptoController.text.trim(),
          metodoPago: _metodoPago,
          esRecurrente: _esRecurrente,
          fecha: _fecha,
        );
        ref.invalidate(cuentaPorIdProvider(_cuentaId!));
      }
      // RegistrarGasto/RegistrarIngreso/EditarTransaccion modifican
      // `Cuenta.saldoActual` — sin esto, el carrusel del dashboard y
      // "Mis cuentas" (que observan `cuentasProvider`) quedan con el saldo
      // viejo hasta que algo más invalide ese provider.
      ref.invalidate(cuentasProvider);
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      final mensajeGuardado = _editando
          ? 'Movimiento actualizado'
          : (_tipo == TipoTransaccion.gasto
                ? 'Gasto guardado'
                : 'Ingreso guardado');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensajeGuardado)));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _eliminar() async {
    if (_original == null) return;
    final esGasto = _original!.tipo == TipoTransaccion.gasto;
    final confirmado = await confirmarEliminar(
      context,
      titulo: esGasto ? 'Eliminar gasto' : 'Eliminar ingreso',
      mensaje:
          '¿Eliminar este ${esGasto ? 'gasto' : 'ingreso'} de '
          '${formatearMonto(_original!.monto, _original!.moneda)}? '
          'Esta acción no se puede deshacer.',
    );
    if (!confirmado) return;
    if (!mounted) return;

    setState(() => _eliminando = true);
    try {
      await ref.read(eliminarTransaccionProvider)(
        transaccionId: widget.transaccionId!,
      );
      // EliminarTransaccion revierte el efecto sobre `Cuenta.saldoActual`
      // de la cuenta original — mismo motivo que en `_guardar`.
      ref.invalidate(cuentaPorIdProvider(_original!.cuentaId));
      ref.invalidate(cuentasProvider);
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      await mostrarErrorEliminar(context, error);
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cuentasAsync = ref.watch(cuentasProvider);
    final categoriasAsync = ref.watch(categoriasProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar movimiento' : 'Nuevo gasto/ingreso'),
        actions: [
          if (_editando)
            IconButton(
              tooltip: 'Eliminar',
              icon: _eliminando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              onPressed: _eliminando ? null : _eliminar,
            ),
        ],
      ),
      body: SafeArea(
        child: cuentasAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('No se pudieron cargar las cuentas.\n$error')),
          data: (cuentas) => categoriasAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Text('No se pudieron cargar las categorías.\n$error'),
            ),
            data: (categorias) {
              if (!_editando) return _construirFormulario(cuentas, categorias);

              final transaccionAsync = ref.watch(
                transaccionPorIdProvider(widget.transaccionId!),
              );
              return transaccionAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('No se pudo cargar la transacción.\n$error'),
                ),
                data: (transaccion) {
                  if (transaccion == null) {
                    return const Center(
                      child: Text('Esta transacción ya no existe.'),
                    );
                  }
                  _precargar(transaccion);
                  return _construirFormulario(cuentas, categorias);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _construirFormulario(
    List<Cuenta> cuentas,
    List<Categoria> categorias,
  ) {
    final theme = Theme.of(context);
    final cuentaSeleccionada = _buscarCuenta(cuentas, _cuentaId);
    final simbolo = cuentaSeleccionada != null
        ? simboloMoneda(cuentaSeleccionada.moneda)
        : null;
    final tipoCategoriaEsperado = _tipo == TipoTransaccion.gasto
        ? TipoCategoria.gasto
        : TipoCategoria.ingreso;
    final categoriasFiltradas = categorias
        .where((c) => c.tipo == tipoCategoriaEsperado)
        .toList();
    if (_categoriaId != null &&
        !categoriasFiltradas.any((c) => c.id == _categoriaId)) {
      _categoriaId = null;
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<TipoTransaccion>(
            segments: const [
              ButtonSegment(
                value: TipoTransaccion.gasto,
                label: Text('Gasto'),
                icon: Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: TipoTransaccion.ingreso,
                label: Text('Ingreso'),
                icon: Icon(Icons.add_circle_outline),
              ),
            ],
            selected: {_tipo},
            onSelectionChanged: (seleccion) => setState(() {
              _tipo = seleccion.first;
              _categoriaId = null;
            }),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto',
              prefixText: simbolo != null ? '$simbolo ' : null,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _cuentaId,
            decoration: const InputDecoration(
              labelText: 'Cuenta',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final cuenta in cuentas)
                DropdownMenuItem(
                  value: cuenta.id,
                  child: Text(
                    '${cuenta.nombre} (${simboloMoneda(cuenta.moneda)})',
                  ),
                ),
            ],
            onChanged: (valor) => setState(() => _cuentaId = valor),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            // Cuando `_categoriaId` cambia por fuera de una interacción
            // directa con este dropdown (crear categoría rápida desde el
            // último ítem), forzar un widget nuevo es la única forma de que
            // el `FormFieldState` interno vuelva a leer `initialValue` en
            // vez de quedarse mostrando el ítem "+ Crear categoría nueva"
            // como seleccionado.
            key: ValueKey(_categoriaId),
            initialValue: _categoriaId,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final categoria in categoriasFiltradas)
                DropdownMenuItem(
                  value: categoria.id,
                  child: Text(categoria.nombre),
                ),
              const DropdownMenuItem(
                value: _valorCrearCategoria,
                child: Text('+ Crear categoría nueva'),
              ),
            ],
            onChanged: (valor) {
              if (valor == _valorCrearCategoria) {
                _abrirCrearCategoriaRapida(tipoCategoriaEsperado);
                return;
              }
              setState(() => _categoriaId = valor);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _conceptoController,
            decoration: const InputDecoration(
              labelText: 'Concepto (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MetodoPago>(
            initialValue: _metodoPago,
            decoration: const InputDecoration(
              labelText: 'Método de pago',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final metodo in MetodoPago.values)
                DropdownMenuItem(
                  value: metodo,
                  child: Text(labelMetodoPago(metodo)),
                ),
            ],
            onChanged: (valor) =>
                setState(() => _metodoPago = valor ?? _metodoPago),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recurrente'),
            subtitle: const Text('Se repite todos los meses'),
            value: _esRecurrente,
            onChanged: (valor) => setState(() => _esRecurrente = valor),
          ),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            subtitle: Text(formatearFecha(_fecha)),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _seleccionarFecha,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_esValido && !_guardando)
                ? () => _guardar(cuentas)
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
                : Text(_editando ? 'Guardar cambios' : 'Guardar'),
          ),
        ],
      ),
    );
  }
}
