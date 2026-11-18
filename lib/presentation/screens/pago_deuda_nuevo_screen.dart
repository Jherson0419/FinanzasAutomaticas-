import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/abono_capital.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/entities/pago_deuda.dart';
import '../../domain/saldo_deuda.dart';
import '../../domain/usecases/registrar_adelanto_cuotas.dart';
import '../shared/app_card.dart';
import '../shared/enum_labels.dart';
import '../shared/estilos.dart';
import '../shared/formatters.dart';
import '../shared/mensajes_error.dart';
import '../shared/selector_segmentado.dart';
import '../state/dashboard/dashboard_providers.dart';
import '../state/providers.dart';

/// Fase 84 — qué registra la pantalla en una deuda de cuotas fijas que yo
/// debo. En pago libre y en "me deben" solo existe [cuota] (sin selector).
enum ModoPagoDeuda { cuota, adelanto, abono }

const avisoAdelantoCuotas =
    'Tu banco puede cobrar menos por adelantar; si es así, registra el '
    'monto real';

String textoEstimacionAbono({required int quedan, required int antes}) =>
    'Estimamos que te quedarán $quedan ${quedan == 1 ? 'cuota' : 'cuotas'} '
    '(antes $antes). Confírmalo con tu banco.';

/// Fase 85 (A.3) — el banco dio otro número de cuotas y no el monto de la
/// última: sin ese monto, la última se cuenta completa.
const avisoUltimaCuotaBanco =
    'Si tu banco te da el monto de la última cuota, ingrésalo para un '
    'saldo exacto';

/// Fase 84b — vista previa de la última cuota cuando el abono la cambia.
String textoUltimaCuotaAbono({
  required double despues,
  required double antes,
  required Moneda moneda,
}) =>
    'Tu última cuota bajaría a ${formatearMonto(despues, moneda)} '
    '(antes ${formatearMonto(antes, moneda)}).';

/// `true` si la deuda ofrece "Adelantar cuotas" y "Abono a capital".
bool ofreceModosDePago(Deuda deuda) =>
    deuda.estructuraPago == EstructuraPago.cuotasFijas &&
    !deuda.meDeben &&
    deuda.cuentaId == null &&
    deuda.montoCuota != null &&
    deuda.numeroCuotasTotal != null &&
    cuotasRestantes(deuda) > 0;

/// Argumentos de la ruta `/deudas/pago` cuando se navega con precarga de
/// cronograma (swipe-to-pay desde `deuda_detalle_screen.dart`). Los
/// llamadores que solo necesitan abrir el formulario en blanco pueden seguir
/// pasando el `deudaId` como `String` directamente.
class PagoDeudaRouteArgs {
  const PagoDeudaRouteArgs({
    required this.deudaId,
    this.numeroCuotaInicial,
    this.montoEsperadoInicial,
    this.modoInicial,
  });

  final String deudaId;
  final int? numeroCuotaInicial;
  final double? montoEsperadoInicial;

  /// Fase 84: modo preseleccionado (el plan abre "Abono a capital" con el
  /// extra mensual en [montoEsperadoInicial]). Se ignora si la deuda no
  /// ofrece ese modo.
  final ModoPagoDeuda? modoInicial;
}

class PagoDeudaNuevoScreen extends ConsumerStatefulWidget {
  const PagoDeudaNuevoScreen({
    super.key,
    required this.deudaId,
    this.numeroCuotaInicial,
    this.montoEsperadoInicial,
    this.modoInicial,
  });

  final String deudaId;

  /// Precarga desde el cronograma (swipe-to-pay en la pantalla de detalle).
  final int? numeroCuotaInicial;
  final double? montoEsperadoInicial;
  final ModoPagoDeuda? modoInicial;

  @override
  ConsumerState<PagoDeudaNuevoScreen> createState() =>
      _PagoDeudaNuevoScreenState();
}

class _PagoDeudaNuevoScreenState extends ConsumerState<PagoDeudaNuevoScreen> {
  final _montoPagadoController = TextEditingController();
  final _montoCapitalController = TextEditingController();
  final _montoInteresController = TextEditingController();
  final _numeroCuotaController = TextEditingController();
  final _montoAbonoController = TextEditingController();
  final _cuotasBancoController = TextEditingController();
  final _ultimaBancoController = TextEditingController();

  String? _cuentaId;
  DateTime _fechaPago = DateTime.now();
  bool _esRetroactivo = false;
  bool _guardando = false;
  bool _valoresPorDefectoAplicados = false;
  ModoPagoDeuda _modo = ModoPagoDeuda.cuota;
  int _cantidadAdelanto = 1;

  @override
  void dispose() {
    _montoPagadoController.dispose();
    _montoCapitalController.dispose();
    _montoInteresController.dispose();
    _numeroCuotaController.dispose();
    _montoAbonoController.dispose();
    _cuotasBancoController.dispose();
    _ultimaBancoController.dispose();
    super.dispose();
  }

  /// Modo efectivo: sin selector siempre es cuota.
  ModoPagoDeuda _modoDe(Deuda deuda) =>
      ofreceModosDePago(deuda) ? _modo : ModoPagoDeuda.cuota;

  /// `null` = campo vacío (opcional); `-1` = valor inválido.
  int? _cuotasSegunBanco(Deuda deuda) {
    final texto = _cuotasBancoController.text.trim();
    if (texto.isEmpty) return null;
    final n = int.tryParse(texto);
    if (n == null || n < 0 || n > cuotasRestantes(deuda)) return -1;
    return n;
  }

  /// Error de los campos del abono, o `null` si son válidos.
  String? _errorAbono(Deuda deuda) {
    final monto = _parseDouble(_montoAbonoController.text);
    if (monto != null && monto > saldoPendiente(deuda) + 0.005) {
      return 'El abono supera lo que falta pagar '
          '(${formatearMonto(saldoPendiente(deuda), deuda.moneda)}).';
    }
    if (_cuotasSegunBanco(deuda) == -1) {
      return 'Las cuotas según tu banco deben estar entre 0 y '
          '${cuotasRestantes(deuda)}.';
    }
    final textoUltima = _ultimaBancoController.text.trim();
    if (textoUltima.isNotEmpty) {
      final ultima = _parseDouble(textoUltima);
      final cuota = deuda.montoCuota ?? 0;
      if (ultima == null ||
          ultima <= 0 ||
          ultima > cuota + toleranciaUltimaCuota) {
        return 'La última cuota según tu banco debe ser mayor a 0 y no '
            'mayor a ${formatearMonto(cuota, deuda.moneda)}.';
      }
      if (_cuotasSegunBanco(deuda) == 0) {
        return 'Si no te quedan cuotas, no hay última cuota.';
      }
    }
    return null;
  }

  /// Fase 84b — "Monto de la última cuota según tu banco"; `null` si está
  /// vacío (o inválido: `_errorAbono` lo bloquea antes de guardar).
  double? _ultimaSegunBanco() {
    final texto = _ultimaBancoController.text.trim();
    return texto.isEmpty ? null : _parseDouble(texto);
  }

  double? _parseDouble(String texto) {
    final valor = texto.trim();
    if (valor.isEmpty) return null;
    return double.tryParse(valor.replaceAll(',', '.'));
  }

  void _aplicarValoresPorDefecto(Deuda deuda) {
    if (_valoresPorDefectoAplicados) return;
    _valoresPorDefectoAplicados = true;

    final modoInicial = widget.modoInicial;
    if (modoInicial != null && ofreceModosDePago(deuda)) {
      _modo = modoInicial;
      if (modoInicial == ModoPagoDeuda.abono &&
          widget.montoEsperadoInicial != null) {
        // Sugerencia editable (p. ej. el extra mensual del plan), acotada a
        // lo que falta pagar.
        final sugerido = widget.montoEsperadoInicial!.clamp(
          0,
          saldoPendiente(deuda),
        );
        _montoAbonoController.text = sugerido.toStringAsFixed(2);
      }
    }

    if (widget.numeroCuotaInicial != null) {
      _numeroCuotaController.text = widget.numeroCuotaInicial!.toString();
    } else if (deuda.estructuraPago == EstructuraPago.cuotasFijas) {
      _numeroCuotaController.text = ((deuda.numeroCuotasPagadas ?? 0) + 1)
          .toString();
    }

    if (widget.montoEsperadoInicial != null &&
        widget.modoInicial != ModoPagoDeuda.abono) {
      _montoPagadoController.text = widget.montoEsperadoInicial!
          .toStringAsFixed(2);
    } else if (deuda.estructuraPago == EstructuraPago.cuotasFijas &&
        deuda.montoCuota != null) {
      // Fase 84b: si la siguiente es la última y un abono la dejó menor,
      // se sugiere ese monto (F).
      final numero =
          widget.numeroCuotaInicial ?? (deuda.numeroCuotasPagadas ?? 0) + 1;
      _montoPagadoController.text = (montoDeCuota(deuda, numero) ?? 0)
          .toStringAsFixed(2);
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
    if (!_esRetroactivo && _cuentaId == null) return false;
    switch (_modoDe(deuda)) {
      case ModoPagoDeuda.adelanto:
        return _cantidadAdelanto >= 1 &&
            _cantidadAdelanto <= cuotasRestantes(deuda);
      case ModoPagoDeuda.abono:
        final monto = _parseDouble(_montoAbonoController.text);
        return monto != null && monto > 0 && _errorAbono(deuda) == null;
      case ModoPagoDeuda.cuota:
        final monto = _parseDouble(_montoPagadoController.text);
        if (monto == null || monto <= 0) return false;
        return _errorDesglose(deuda) == null;
    }
  }

  /// Ejecuta el registro según el modo. Devuelve el texto del aviso.
  Future<String> _registrar(Deuda deuda) async {
    final cuentaId = _esRetroactivo ? null : _cuentaId;
    switch (_modoDe(deuda)) {
      case ModoPagoDeuda.adelanto:
        final pagos = await ref.read(registrarAdelantoCuotasProvider)(
          deudaId: deuda.id,
          cantidad: _cantidadAdelanto,
          cuentaId: cuentaId,
          fechaPago: _fechaPago,
        );
        return pagos.length == 1
            ? '1 cuota adelantada'
            : '${pagos.length} cuotas adelantadas';
      case ModoPagoDeuda.abono:
        final monto = _parseDouble(_montoAbonoController.text)!;
        final banco = _cuotasSegunBanco(deuda);
        await ref.read(registrarPagoDeudaProvider)(
          deudaId: deuda.id,
          cuentaId: cuentaId,
          montoPagado: monto,
          montoCapital: monto,
          montoInteres: 0,
          fechaPago: _fechaPago,
          tipo: TipoPagoDeuda.abonoCapital,
          cuotasRestantesSegunBanco: banco,
          montoUltimaCuotaSegunBanco: _ultimaSegunBanco(),
        );
        return 'Abono a capital registrado';
      case ModoPagoDeuda.cuota:
        await _registrarCuota(deuda, cuentaId);
        return deuda.meDeben ? 'Cobro registrado' : 'Pago registrado';
    }
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
    String? aviso;
    try {
      aviso = await _registrar(deuda);
    } on AdelantoCuotasIncompleto catch (incompleto) {
      // Parte quedó registrada: se refresca igual y se dice cuánto.
      aviso = incompleto.mensaje;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo registrar el pago: ${mensajeDeError(error)}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
    if (aviso == null) return;

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aviso)));
    Navigator.of(context).pop();
  }

  Future<void> _registrarCuota(Deuda deuda, String? cuentaId) async {
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

    await ref.read(registrarPagoDeudaProvider)(
      deudaId: deuda.id,
      cuentaId: cuentaId,
      montoPagado: monto,
      montoCapital: montoCapital,
      montoInteres: montoInteres,
      numeroCuota: numeroCuota,
      fechaPago: _fechaPago,
    );
  }

  @override
  Widget build(BuildContext context) {
    final deudaAsync = ref.watch(deudaPorIdProvider(widget.deudaId));
    final cuentasAsync = ref.watch(cuentasProvider);

    return Scaffold(
      // Fase 82: en "me deben" esto es un COBRO (el dinero entra).
      appBar: AppBar(
        title: Text(
          (deudaAsync.valueOrNull?.meDeben ?? false)
              ? 'Registrar cobro'
              : 'Registrar pago',
        ),
      ),
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

  List<Widget> _camposAbono(Deuda deuda) {
    final theme = Theme.of(context);
    final secundario = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final monto = _parseDouble(_montoAbonoController.text);
    final error = _errorAbono(deuda);
    final estimacion = (monto != null && monto > 0 && error == null)
        ? estimarAbonoCapital(deuda, monto)
        : null;
    // Lo que diga el banco manda sobre la estimación (misma regla que
    // `RegistrarPagoDeuda`).
    final bancoR = _cuotasSegunBanco(deuda);
    final double? ultimaResultante;
    if (estimacion == null ||
        (bancoR ?? estimacion.cuotasRestantesDespues) == 0) {
      ultimaResultante = null;
    } else if (_ultimaSegunBanco() != null) {
      ultimaResultante = _ultimaSegunBanco();
    } else if (bancoR == null || bancoR == estimacion.cuotasRestantesDespues) {
      ultimaResultante = estimacion.ultimaCuotaResultante;
    } else {
      ultimaResultante = estimacion.cuota;
    }
    return [
      TextFormField(
        controller: _montoAbonoController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monto del abono',
          prefixText: '${simboloMoneda(deuda.moneda)} ',
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _cuotasBancoController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Cuotas que te quedan según tu banco (opcional)',
          helperText: 'Si tu banco ya te lo dijo, manda su número.',
          helperMaxLines: 2,
          border: OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _ultimaBancoController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monto de la última cuota según tu banco (opcional)',
          prefixText: '${simboloMoneda(deuda.moneda)} ',
          helperText: 'Si tu banco te dio otro monto, manda el suyo.',
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (error != null) ...[
        const SizedBox(height: 8),
        Text(
          error,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
      if (estimacion != null) ...[
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            [
              textoEstimacionAbono(
                quedan: estimacion.cuotasRestantesDespues,
                antes: estimacion.cuotasRestantesAntes,
              ),
              // Fase 84b: solo cuando la última cuota cambia.
              if (ultimaResultante != null &&
                  (ultimaResultante - estimacion.ultimaCuotaAntes).abs() >=
                      toleranciaUltimaCuota)
                textoUltimaCuotaAbono(
                  despues: ultimaResultante,
                  antes: estimacion.ultimaCuotaAntes,
                  moneda: deuda.moneda,
                ),
            ].join(' '),
            style: secundario,
          ),
        ),
      ],
      if (estimacion != null &&
          bancoR != null &&
          bancoR > 0 &&
          bancoR != estimacion.cuotasRestantesDespues &&
          _ultimaBancoController.text.trim().isEmpty) ...[
        const SizedBox(height: 8),
        Text(avisoUltimaCuotaBanco, style: secundario),
      ],
    ];
  }

  Widget _construirFormulario(Deuda deuda, List<Cuenta> cuentas) {
    // Fase 83: un cobro ("me deben") no se recibe en una tarjeta de
    // crédito — el dinero que te devuelven entra a una cuenta de fondos.
    final cuentasEnMoneda = cuentas
        .where(
          (cuenta) =>
              cuenta.moneda == deuda.moneda &&
              !(deuda.meDeben && cuenta.tipo == TipoCuenta.credito),
        )
        .toList();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final errorDesglose = _errorDesglose(deuda);
    final modo = _modoDe(deuda);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (deuda.meDeben)
                Text(
                  'Cobrar a ${deuda.nombreAcreedor}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              Text(
                deuda.nombreDeuda,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${deuda.meDeben ? 'Cobrado' : 'Pagado'} ${formatearMonto(deuda.montoPagado, deuda.moneda)} de ${formatearMonto(totalAPagar(deuda), deuda.moneda)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFeatures: cifrasTabulares,
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
        if (ofreceModosDePago(deuda)) ...[
          SelectorSegmentado<ModoPagoDeuda>(
            etiquetaGrupo: 'Qué vas a registrar',
            opciones: const [
              (ModoPagoDeuda.cuota, 'Pagar cuota'),
              (ModoPagoDeuda.adelanto, 'Adelantar cuotas'),
              (ModoPagoDeuda.abono, 'Abono a capital'),
            ],
            seleccionado: modo,
            onCambio: _guardando ? null : (m) => setState(() => _modo = m),
          ),
          const SizedBox(height: 20),
        ],
        if (modo == ModoPagoDeuda.cuota)
          TextFormField(
            controller: _montoPagadoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: deuda.meDeben ? 'Monto cobrado' : 'Monto pagado',
              prefixText: '${simboloMoneda(deuda.moneda)} ',
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        if (modo == ModoPagoDeuda.adelanto)
          _Adelanto(
            cantidad: _cantidadAdelanto,
            maximo: cuotasRestantes(deuda),
            cuota: deuda.montoCuota!,
            total: montoAdelantoCuotas(deuda, _cantidadAdelanto),
            moneda: deuda.moneda,
            onCambio: (n) => setState(() => _cantidadAdelanto = n),
          ),
        if (modo == ModoPagoDeuda.abono) ..._camposAbono(deuda),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            deuda.meDeben
                ? 'Este cobro ya ocurrió antes'
                : 'Este pago ya ocurrió antes',
          ),
          subtitle: Text(
            deuda.meDeben
                ? 'No sumar a mi saldo actual'
                : 'No descontar de mi saldo actual',
          ),
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
              // Fase 84: sin esto el nombre de la cuenta desborda a 360 dp
              // con texto grande (mismo arreglo que deuda_formulario).
              isExpanded: true,
              initialValue: _cuentaId,
              decoration: InputDecoration(
                labelText: deuda.meDeben ? 'Recibir en' : 'Cuenta de origen',
                border: const OutlineInputBorder(),
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
          title: Text(deuda.meDeben ? 'Fecha del cobro' : 'Fecha de pago'),
          subtitle: Text(formatearFecha(_fechaPago)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: _seleccionarFecha,
        ),
        if (modo == ModoPagoDeuda.cuota && deuda.tieneInteres) ...[
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
        if (modo == ModoPagoDeuda.cuota &&
            deuda.estructuraPago == EstructuraPago.cuotasFijas) ...[
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

/// Fase 84 — "Adelantar cuotas": contador 1..[maximo] con botones de 48 dp,
/// el total resultante y el aviso de que el banco puede cobrar menos.
class _Adelanto extends StatelessWidget {
  const _Adelanto({
    required this.cantidad,
    required this.maximo,
    required this.cuota,
    required this.total,
    required this.moneda,
    required this.onCambio,
  });

  final int cantidad;
  final int maximo;
  final double cuota;

  /// Suma de las cuotas adelantadas (la última puede ser menor, Fase 84b).
  final double total;
  final Moneda moneda;
  final ValueChanged<int> onCambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalTexto = formatearMonto(total, moneda);
    final conParcial = (total - cuota * cantidad).abs() >= 0.005;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('¿Cuántas cuotas adelantas?', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              tooltip: 'Una cuota menos',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: cantidad > 1 ? () => onCambio(cantidad - 1) : null,
              icon: const Icon(Icons.remove),
            ),
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: true,
                label: '$cantidad de $maximo cuotas pendientes',
                excludeSemantics: true,
                child: Text(
                  '$cantidad',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: cifrasTabulares,
                  ),
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Una cuota más',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: cantidad < maximo
                  ? () => onCambio(cantidad + 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          conParcial
              ? '$cantidad ${cantidad == 1 ? 'cuota' : 'cuotas'} = '
                    '$totalTexto (incluye la última, menor) · te quedan '
                    '$maximo'
              : '$cantidad × ${formatearMonto(cuota, moneda)} = $totalTexto · '
                    'te quedan $maximo',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFeatures: cifrasTabulares,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          avisoAdelantoCuotas,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
