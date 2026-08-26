import 'package:uuid/uuid.dart';

import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../validacion_cuenta_credito.dart';

class RegistrarCuenta {
  final CuentaRepository _cuentaRepository;
  final DeudaRepository _deudaRepository;
  final Uuid _uuid;

  RegistrarCuenta({
    required CuentaRepository cuentaRepository,
    required DeudaRepository deudaRepository,
    Uuid? uuid,
  }) : _cuentaRepository = cuentaRepository,
       _deudaRepository = deudaRepository,
       _uuid = uuid ?? const Uuid();

  Future<Cuenta> call({
    required String nombre,
    required TipoCuenta tipo,
    required Moneda moneda,
    double saldoInicial = 0,
    double? lineaCredito,
    DateTime? fechaCorte,
    DateTime? fechaPago,
    String? ultimosDigitos,
    double? pagoMinimo,
  }) async {
    validarCamposDeCredito(
      tipo: tipo,
      lineaCredito: lineaCredito,
      fechaCorte: fechaCorte,
      fechaPago: fechaPago,
      pagoMinimo: pagoMinimo,
    );

    final cuenta = Cuenta(
      id: _uuid.v4(),
      nombre: nombre,
      tipo: tipo,
      moneda: moneda,
      saldoActual: saldoInicial,
      lineaCredito: lineaCredito,
      fechaCorte: fechaCorte,
      fechaPago: fechaPago,
      ultimosDigitos: ultimosDigitos,
      pagoMinimo: pagoMinimo,
    );

    await _cuentaRepository.crear(cuenta);

    // Fase 62: toda cuenta de crédito recién creada trae su propia `Deuda`
    // vinculada 1:1 (`cuentaId`), para que aparezca en "Deudas activas"
    // igual que cualquier otra. El crédito DISPONIBLE se guarda como
    // `montoPagado` (reutiliza el modelo existente sin campos nuevos de
    // progreso): `montoTotal - montoPagado` da exactamente lo usado, la
    // deuda pendiente real. Se mantiene sincronizada por
    // `SincronizarDeudaTarjeta` en cada transacción sobre esta cuenta.
    if (tipo == TipoCuenta.credito) {
      final montoUsado = saldoInicial < 0 ? saldoInicial.abs() : 0.0;
      final lineaTotal = lineaCredito ?? 0.0;
      await _deudaRepository.crear(
        Deuda(
          id: _uuid.v4(),
          nombreDeuda: nombre,
          tipoDeuda: TipoDeuda.tarjetaCredito,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: nombre,
          moneda: moneda,
          montoTotal: lineaTotal,
          montoPagado: lineaTotal - montoUsado,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime.now(),
          enMora: false,
          estado: EstadoDeuda.activa,
          cuentaId: cuenta.id,
        ),
      );
    }

    return cuenta;
  }
}
