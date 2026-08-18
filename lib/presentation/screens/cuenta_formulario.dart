import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../shared/dialogos_eliminar.dart';
import '../shared/enum_labels.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';
import 'dashboard/widgets/wallet_account_card.dart';

/// Formulario de cuenta, reutilizado por [CuentaNuevaScreen] (crear/editar,
/// según [cuentaId]) y por la pantalla de onboarding (siempre creación).
///
/// En modo edición el saldo ya no es un campo editable: se calcula solo a
/// partir de los movimientos. Para corregirlo (p. ej. al empezar a usar la
/// app con una cuenta que ya tenía plata) se usa "Ajustar", que registra la
/// diferencia como una transacción más en vez de sobrescribir el número.
class CuentaFormulario extends ConsumerStatefulWidget {
  const CuentaFormulario({
    super.key,
    this.cuentaId,
    required this.onGuardadoExitoso,
  });

  /// Si no es nulo, el formulario carga esa cuenta y edita en vez de crear.
  final String? cuentaId;

  /// Se invoca después de guardar con éxito. La navegación posterior
  /// (pop, o simplemente no hacer nada porque el árbol reactivo ya cambió)
  /// queda a criterio de quien use el formulario.
  final VoidCallback onGuardadoExitoso;

  @override
  ConsumerState<CuentaFormulario> createState() => _CuentaFormularioState();
}

class _CuentaFormularioState extends ConsumerState<CuentaFormulario> {
  final _nombreController = TextEditingController();
  final _saldoController = TextEditingController(text: '0');

  TipoCuenta _tipo = TipoCuenta.efectivo;
  Moneda _moneda = Moneda.pen;
  bool _guardando = false;
  bool _eliminando = false;
  bool _valoresPrecargados = false;

  bool get _editando => widget.cuentaId != null;

  @override
  void dispose() {
    _nombreController.dispose();
    _saldoController.dispose();
    super.dispose();
  }

  double? _parseDouble(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  bool get _esValido {
    if (_nombreController.text.trim().isEmpty) return false;
    if (_editando) return true;
    return _parseDouble(_saldoController.text) != null;
  }

  void _precargar(Cuenta cuenta) {
    if (_valoresPrecargados) return;
    _valoresPrecargados = true;
    _nombreController.text = cuenta.nombre;
    _tipo = cuenta.tipo;
    _moneda = cuenta.moneda;
  }

  Future<void> _guardar() async {
    if (!_esValido) return;

    setState(() => _guardando = true);
    try {
      if (_editando) {
        await ref.read(editarCuentaProvider)(
          cuentaId: widget.cuentaId!,
          nombre: _nombreController.text.trim(),
          tipo: _tipo,
          moneda: _moneda,
        );
        ref.invalidate(cuentaPorIdProvider(widget.cuentaId!));
      } else {
        await ref.read(registrarCuentaProvider)(
          nombre: _nombreController.text.trim(),
          tipo: _tipo,
          moneda: _moneda,
          saldoInicial: _parseDouble(_saldoController.text)!,
        );
      }
      ref.invalidate(cuentasProvider);
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      if (!_editando) {
        _nombreController.clear();
        _saldoController.text = '0';
        setState(() {
          _tipo = TipoCuenta.efectivo;
          _moneda = Moneda.pen;
        });
      }
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

  Future<void> _eliminar() async {
    final confirmado = await confirmarEliminar(
      context,
      titulo: 'Eliminar cuenta',
      mensaje: '¿Eliminar esta cuenta? Esta acción no se puede deshacer.',
    );
    if (!confirmado) return;
    if (!mounted) return;

    setState(() => _eliminando = true);
    try {
      await ref.read(eliminarCuentaProvider)(cuentaId: widget.cuentaId!);
      ref.invalidate(cuentasProvider);
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      widget.onGuardadoExitoso();
    } catch (error) {
      // El spinner solo debe reflejar la operación en sí — se apaga antes
      // de mostrar el diálogo de error, no mientras el usuario lo lee.
      if (mounted) setState(() => _eliminando = false);
      if (!mounted) return;
      await mostrarErrorEliminar(context, error);
      return;
    }
    if (mounted) setState(() => _eliminando = false);
  }

  Future<void> _abrirModalAjuste(Cuenta cuenta) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ModalAjusteSaldo(cuenta: cuenta),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cuentaId != null) {
      final cuentaAsync = ref.watch(cuentaPorIdProvider(widget.cuentaId!));
      return cuentaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('No se pudo cargar la cuenta.\n$error')),
        data: (cuenta) {
          if (cuenta == null) {
            return const Center(child: Text('Esta cuenta ya no existe.'));
          }
          _precargar(cuenta);
          return _construirCamposEdicion(context, cuenta);
        },
      );
    }
    return _construirCamposCreacion(context);
  }

  Widget _construirCamposEdicion(BuildContext context, Cuenta cuenta) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final transaccionesAsync = ref.watch(
      transaccionesPorCuentaProvider(cuenta.id),
    );
    final pagosAsync = ref.watch(pagosPorCuentaProvider(cuenta.id));
    // Mientras no se sepa con certeza (cargando/error), se asume que sí
    // tiene movimientos — es la opción segura: evita permitir un cambio de
    // moneda que el caso de uso rechazaría de todos modos.
    final tieneMovimientos =
        (transaccionesAsync.valueOrNull?.isNotEmpty ?? true) ||
        (pagosAsync.valueOrNull?.isNotEmpty ?? true);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: WalletAccountCard(cuenta: cuenta)),
        const SizedBox(height: 24),
        Text('Datos de la cuenta', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la cuenta',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TipoCuenta>(
          initialValue: _tipo,
          decoration: const InputDecoration(
            labelText: 'Tipo de cuenta',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final tipo in TipoCuenta.values)
              DropdownMenuItem(value: tipo, child: Text(labelTipoCuenta(tipo))),
          ],
          onChanged: (valor) => setState(() => _tipo = valor ?? _tipo),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<Moneda>(
          initialValue: _moneda,
          decoration: InputDecoration(
            labelText: 'Moneda',
            border: const OutlineInputBorder(),
            helperText: tieneMovimientos
                ? 'No se puede cambiar: esta cuenta ya tiene movimientos.'
                : null,
          ),
          items: [
            for (final moneda in Moneda.values)
              DropdownMenuItem(value: moneda, child: Text(labelMoneda(moneda))),
          ],
          onChanged: tieneMovimientos
              ? null
              : (valor) => setState(() => _moneda = valor ?? _moneda),
        ),
        const SizedBox(height: 24),
        Text('Saldo', style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo actual',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatearMonto(cuenta.saldoActual, cuenta.moneda),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _abrirModalAjuste(cuenta),
              icon: const Icon(Icons.tune),
              label: const Text('Ajustar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'El saldo se calcula solo a partir de tus movimientos. '
          '"Ajustar" registra un movimiento con la diferencia en vez de '
          'sobrescribir el número.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(
            context,
          ).pushNamed('/cuentas/movimientos', arguments: cuenta.id),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('Ver movimientos de esta cuenta'),
        ),
        const SizedBox(height: 16),
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
              : const Text('Guardar cambios'),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.error,
            side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
          ),
          onPressed: _eliminando ? null : _eliminar,
          icon: _eliminando
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.error,
                  ),
                )
              : const Icon(Icons.delete_outline),
          label: const Text('Eliminar cuenta'),
        ),
      ],
    );
  }

  Widget _construirCamposCreacion(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _nombreController,
          decoration: const InputDecoration(
            labelText: 'Nombre de la cuenta',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<TipoCuenta>(
          initialValue: _tipo,
          decoration: const InputDecoration(
            labelText: 'Tipo de cuenta',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final tipo in TipoCuenta.values)
              DropdownMenuItem(value: tipo, child: Text(labelTipoCuenta(tipo))),
          ],
          onChanged: (valor) => setState(() => _tipo = valor ?? _tipo),
        ),
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
          controller: _saldoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Saldo inicial',
            prefixText: '${simboloMoneda(_moneda)} ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

/// Bottom sheet de un solo campo para invocar `AjustarSaldoCuenta`.
class _ModalAjusteSaldo extends ConsumerStatefulWidget {
  const _ModalAjusteSaldo({required this.cuenta});

  final Cuenta cuenta;

  @override
  ConsumerState<_ModalAjusteSaldo> createState() => _ModalAjusteSaldoState();
}

class _ModalAjusteSaldoState extends ConsumerState<_ModalAjusteSaldo> {
  late final TextEditingController _saldoRealController = TextEditingController(
    text: widget.cuenta.saldoActual.toStringAsFixed(2),
  );
  bool _guardando = false;

  @override
  void dispose() {
    _saldoRealController.dispose();
    super.dispose();
  }

  double? _parseDouble(String texto) =>
      double.tryParse(texto.trim().replaceAll(',', '.'));

  Future<void> _confirmar() async {
    final saldoReal = _parseDouble(_saldoRealController.text);
    if (saldoReal == null) return;

    setState(() => _guardando = true);
    try {
      await ref.read(ajustarSaldoCuentaProvider)(
        cuentaId: widget.cuenta.id,
        saldoReal: saldoReal,
      );
      ref.invalidate(cuentasProvider);
      ref.invalidate(cuentaPorIdProvider(widget.cuenta.id));
      ref.invalidate(transaccionesPorCuentaProvider(widget.cuenta.id));
      ref.invalidate(resumenDashboardProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo ajustar: ${mensajeDeError(error)}')),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esValido = _parseDouble(_saldoRealController.text) != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ajustar saldo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ingresa el saldo real de "${widget.cuenta.nombre}". Se '
            'registrará la diferencia como un movimiento de ajuste.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _saldoRealController,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Saldo real',
              prefixText: '${simboloMoneda(widget.cuenta.moneda)} ',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: (esValido && !_guardando) ? _confirmar : null,
            child: _guardando
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onPrimary,
                    ),
                  )
                : const Text('Confirmar ajuste'),
          ),
        ],
      ),
    );
  }
}
