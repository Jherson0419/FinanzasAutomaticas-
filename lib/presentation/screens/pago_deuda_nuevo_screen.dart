import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../shared/app_card.dart';
import '../shared/enum_labels.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';

/// Argumentos de la ruta `/deudas/pago` cuando se navega con precarga de
/// cronograma (swipe-to-pay desde `deuda_detalle_screen.dart`). Los
/// llamadores que solo necesitan abrir el formulario en blanco pueden seguir
/// pasando el `deudaId` como `String` directamente.
class PagoDeudaRouteArgs {
  const PagoDeudaRouteArgs({
    required this.deudaId,
    this.numeroCuotaInicial,
    this.montoEsperadoInicial,
  });

  final String deudaId;
  final int? numeroCuotaInicial;
  final double? montoEsperadoInicial;
}

class PagoDeudaNuevoScreen extends ConsumerStatefulWidget {
  const PagoDeudaNuevoScreen({
    super.key,
    required this.deudaId,
    this.numeroCuotaInicial,
    this.montoEsperadoInicial,
  });

  final String deudaId;

  /// Precarga desde el cronograma (swipe-to-pay en la pantalla de detalle).
  final int? numeroCuotaInicial;
  final double? montoEsperadoInicial;

  @override
  ConsumerState<PagoDeudaNuevoScreen> createState() =>
      _PagoDeudaNuevoScreenState();
}

class _PagoDeudaNuevoScreenState extends ConsumerState<PagoDeudaNuevoScreen> {
  final _montoPagadoController = TextEditingController();
  final _montoCapitalController = TextEditingController();
  final _montoInteresController = TextEditingController();
  final _numeroCuotaController = TextEditingController();

  String? _cuentaId;
  DateTime _fechaPago = DateTime.now();
  bool _esRetroactivo = false;
  bool _guardando = false;
  bool _valoresPorDefectoAplicados = false;

  @override
  void dispose() {
    _montoPagadoController.dispose();
    _montoCapitalController.dispose();
    _montoInteresController.dispose();
    _numeroCuotaController.dispose();
    super.dispose();
  }

  double? _parseDouble(String texto) {
    final valor = texto.trim();
    if (valor.isEmpty) return null;
    return double.tryParse(valor.replaceAll(',', '.'));
  }

  void _aplicarValoresPorDefecto(Deuda deuda) {
    if (_valoresPorDefectoAplicados) return;
    _valoresPorDefectoAplicados = true;

    if (widget.numeroCuotaInicial != null) {
      _numeroCuotaController.text = widget.numeroCuotaInicial!.toString();
    } else if (deuda.estructuraPago == EstructuraPago.cuotasFijas) {
      _numeroCuotaController.text = ((deuda.numeroCuotasPagadas ?? 0) + 1)
          .toString();
    }

    if (widget.montoEsperadoInicial != null) {
      _montoPagadoController.text = widget.montoEsperadoInicial!
          .toStringAsFixed(2);
    } else if (deuda.estructuraPago == EstructuraPago.cuotasFijas &&
        deuda.montoCuota != null) {
      _montoPagadoController.text = deuda.montoCuota!.toStringAsFixed(2);
    }
  }

  /// Devuelve null si el desglose es válido (o no aplica); en caso contrario
  /// el mensaje de error a mostrar bajo los campos de capital/interés.
  String? _errorDesglose(Deuda deuda) {
    if (!deuda.tieneInteres) return null;
    final capitalTexto = _montoCapitalController.text.trim();
    final interesTexto = _montoInteresController.text.trim();
    if (capitalTexto.isEmpty && interesTexto.isEmpty) return null;

    final monto = _parseDouble(_montoPagadoController.text);
    final capital = _parseDouble(_montoCapitalController.text) ?? 0;
    final interes = _parseDouble(_montoInteresController.text) ?? 0;
    if (monto == null) return null;

    if ((capital + interes - monto).abs() > 0.005) {
      return 'Capital + interés debe sumar el monto pagado';
    }
    return null;
  }

  bool _esValido(Deuda deuda) {
    final monto = _parseDouble(_montoPagadoController.text);
    if (monto == null || monto <= 0) return false;
    if (!_esRetroactivo && _cuentaId == null) return false;
    if (_errorDesglose(deuda) != null) return false;
    return true;
  }

  Future<void> _seleccionarFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (seleccionada != null) setState(() => _fechaPago = seleccionada);
  }

  Future<void> _guardar(Deuda deuda) async {
    if (!_esValido(deuda)) return;

    setState(() => _guardando = true);
    final monto = _parseDouble(_montoPagadoController.text)!;
    double? montoCapital;
    double? montoInteres;
    if (deuda.tieneInteres) {
      final capitalTexto = _montoCapitalController.text.trim();
      final interesTexto = _montoInteresController.text.trim();
      if (capitalTexto.isEmpty && interesTexto.isEmpty) {
        montoCapital = monto;
        montoInteres = null;
      } else {
        montoCapital = _parseDouble(_montoCapitalController.text) ?? 0;
        montoInteres = _parseDouble(_montoInteresController.text) ?? 0;
      }
    }
    final numeroCuota = deuda.estructuraPago == EstructuraPago.cuotasFijas
        ? int.tryParse(_numeroCuotaController.text.trim())
        : null;

    try {
      await ref.read(registrarPagoDeudaProvider)(
        deudaId: deuda.id,
        cuentaId: _esRetroactivo ? null : _cuentaId,
        montoPagado: monto,
        montoCapital: montoCapital,
        montoInteres: montoInteres,
        numeroCuota: numeroCuota,
        fechaPago: _fechaPago,
      );
      if (!_esRetroactivo && _cuentaId != null) {
        // Un pago no retroactivo descuenta `Cuenta.saldoActual` — sin esto,
        // el carrusel del dashboard y "Mis cuentas" quedan con el saldo
        // viejo (mismo bug que en transaccion_nueva_screen.dart).
        ref.invalidate(cuentaPorIdProvider(_cuentaId!));
        ref.invalidate(cuentasProvider);
      }
      ref.invalidate(resumenDashboardProvider);
      ref.invalidate(deudaPorIdProvider(deuda.id));
      ref.invalidate(pagosPorDeudaProvider(deuda.id));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pago registrado')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo registrar el pago: ${mensajeDeError(error)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deudaAsync = ref.watch(deudaPorIdProvider(widget.deudaId));
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pago')),
      body: SafeArea(
        child: deudaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text('No se pudo cargar la deuda.\n$error')),
          data: (deuda) {
            if (deuda == null) {
              return const Center(child: Text('Esta deuda ya no existe.'));
            }
            if (deuda.estado == EstadoDeuda.pagada) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '"${deuda.nombreDeuda}" ya está completamente pagada.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              );
            }
            return cuentasAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Text('No se pudieron cargar las cuentas.\n$error'),
              ),
              data: (cuentas) {
                _aplicarValoresPorDefecto(deuda);
                return _construirFormulario(deuda, cuentas);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _construirFormulario(Deuda deuda, List<Cuenta> cuentas) {
    final cuentasEnMoneda = cuentas
        .where((cuenta) => cuenta.moneda == deuda.moneda)
        .toList();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorDesglose = _errorDesglose(deuda);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deuda.nombreDeuda,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pagado ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(deuda.montoTotal, deuda.moneda)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                deuda.estructuraPago == EstructuraPago.cuotasFijas
                    ? (deuda.proximaFechaPago != null
                          ? 'Próxima cuota: ${formatearFecha(deuda.proximaFechaPago!)}'
                          : 'Próxima cuota: —')
                    : 'Sin cuota fija (pago libre)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _montoPagadoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monto pagado',
            prefixText: '${simboloMoneda(deuda.moneda)} ',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Este pago ya ocurrió antes'),
          subtitle: const Text('No descontar de mi saldo actual'),
          value: _esRetroactivo,
          onChanged: (valor) => setState(() => _esRetroactivo = valor),
        ),
        if (!_esRetroactivo) ...[
          const SizedBox(height: 8),
          if (cuentasEnMoneda.isEmpty)
            Text(
              'No tienes ninguna cuenta en ${labelMoneda(deuda.moneda)}. '
              'Créala desde "Mis cuentas" o marca este pago como ya ocurrido.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _cuentaId,
              decoration: const InputDecoration(
                labelText: 'Cuenta de origen',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final cuenta in cuentasEnMoneda)
                  DropdownMenuItem(
                    value: cuenta.id,
                    child: Text(
                      '${cuenta.nombre} (${simboloMoneda(cuenta.moneda)})',
                    ),
                  ),
              ],
              onChanged: (valor) => setState(() => _cuentaId = valor),
            ),
        ],
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fecha de pago'),
          subtitle: Text(formatearFecha(_fechaPago)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _seleccionarFecha,
        ),
        if (deuda.tieneInteres) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Desglose del pago (opcional)',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _montoCapitalController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto a capital',
              prefixText: '${simboloMoneda(deuda.moneda)} ',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _montoInteresController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto a interés',
              prefixText: '${simboloMoneda(deuda.moneda)} ',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (errorDesglose != null) ...[
            const SizedBox(height: 6),
            Text(
              errorDesglose,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error,
              ),
            ),
          ],
        ],
        if (deuda.estructuraPago == EstructuraPago.cuotasFijas) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _numeroCuotaController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Número de cuota (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: (_esValido(deuda) && !_guardando)
              ? () => _guardar(deuda)
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
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
