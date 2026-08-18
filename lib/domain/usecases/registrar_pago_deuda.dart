import 'package:uuid/uuid.dart';

import '../cronograma_cuotas.dart';
import '../entities/deuda.dart';
import '../entities/pago_deuda.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';

class RegistrarPagoDeuda {
  final PagoDeudaRepository _pagoDeudaRepository;
  final DeudaRepository _deudaRepository;
  final CuentaRepository _cuentaRepository;
  final Uuid _uuid;

  RegistrarPagoDeuda({
    required PagoDeudaRepository pagoDeudaRepository,
    required DeudaRepository deudaRepository,
    required CuentaRepository cuentaRepository,
    Uuid? uuid,
  }) : _pagoDeudaRepository = pagoDeudaRepository,
       _deudaRepository = deudaRepository,
       _cuentaRepository = cuentaRepository,
       _uuid = uuid ?? const Uuid();

  /// Si [cuentaId] es `null`, el pago se trata como retroactivo: ya ocurrió
  /// antes y no debe descontarse de ninguna cuenta ni validarse contra su
  /// moneda.
  Future<PagoDeuda> call({
    required String deudaId,
    String? cuentaId,
    required double montoPagado,
    double? montoCapital,
    double? montoInteres,
    int? numeroCuota,
    DateTime? fechaPago,
  }) async {
    final deuda = await _deudaRepository.obtenerPorId(deudaId);
    if (deuda == null) {
      throw ArgumentError('La deuda $deudaId no existe');
    }
    if (deuda.estado == EstadoDeuda.pagada) {
      throw StateError('La deuda "${deuda.nombreDeuda}" ya está pagada');
    }

    var cuenta = cuentaId == null
        ? null
        : await _cuentaRepository.obtenerPorId(cuentaId);
    if (cuentaId != null) {
      if (cuenta == null) {
        throw ArgumentError('La cuenta $cuentaId no existe');
      }
      if (cuenta.moneda != deuda.moneda) {
        throw StateError(
          'La cuenta está en ${cuenta.moneda.name.toUpperCase()} pero la deuda '
          'está en ${deuda.moneda.name.toUpperCase()} — no se puede registrar '
          'el pago',
        );
      }
    }

    final pago = PagoDeuda(
      id: _uuid.v4(),
      deudaId: deudaId,
      cuentaId: cuentaId,
      montoPagado: montoPagado,
      montoCapital: montoCapital,
      montoInteres: montoInteres,
      fechaPago: fechaPago ?? DateTime.now(),
      numeroCuota: numeroCuota,
    );

    await _pagoDeudaRepository.crear(pago);

    final nuevoMontoPagado = deuda.montoPagado + montoPagado;
    final nuevoEstado = nuevoMontoPagado >= deuda.montoTotal
        ? EstadoDeuda.pagada
        : deuda.estado;
    final esCuotasFijas = deuda.estructuraPago == EstructuraPago.cuotasFijas;
    final seSaldo = nuevoEstado == EstadoDeuda.pagada;

    DateTime? proximaFechaPago = deuda.proximaFechaPago;
    if (esCuotasFijas) {
      final pagosActualizados = await _pagoDeudaRepository.obtenerPorDeuda(
        deudaId,
      );
      final cronograma = generarCronogramaCuotas(deuda, pagosActualizados);
      proximaFechaPago = proximaFechaPagoDesdeCronograma(cronograma);
    }

    // Reconstrucción explícita en vez de `copyWith`: cuando ya no quedan
    // cuotas pendientes, `proximaFechaPago` debe pasar a `null`, y
    // `copyWith` no distingue "no cambiar" de "poner en null" para campos
    // nullable (usa `??`).
    await _deudaRepository.actualizar(
      Deuda(
        id: deuda.id,
        nombreDeuda: deuda.nombreDeuda,
        tipoDeuda: deuda.tipoDeuda,
        tipoAcreedor: deuda.tipoAcreedor,
        nombreAcreedor: deuda.nombreAcreedor,
        moneda: deuda.moneda,
        montoTotal: deuda.montoTotal,
        montoPagado: nuevoMontoPagado,
        tieneInteres: deuda.tieneInteres,
        tasaInteres: deuda.tasaInteres,
        tipoTasa: deuda.tipoTasa,
        estructuraPago: deuda.estructuraPago,
        numeroCuotasTotal: deuda.numeroCuotasTotal,
        numeroCuotasPagadas: esCuotasFijas
            ? (deuda.numeroCuotasPagadas ?? 0) + 1
            : deuda.numeroCuotasPagadas,
        montoCuota: deuda.montoCuota,
        pagoMinimo: deuda.pagoMinimo,
        periodicidadCuotas: deuda.periodicidadCuotas,
        interesTotal: deuda.interesTotal,
        fechaInicio: deuda.fechaInicio,
        fechaVencimientoFinal: deuda.fechaVencimientoFinal,
        diaPago: deuda.diaPago,
        proximaFechaPago: proximaFechaPago,
        // Si el pago salda la deuda, ya no tiene sentido que siga marcada
        // en mora — evita que quede "atascada" con enMora/diasMora viejos.
        enMora: seSaldo ? false : deuda.enMora,
        diasMora: seSaldo ? 0 : deuda.diasMora,
        tasaInteresMoratorio: deuda.tasaInteresMoratorio,
        estado: nuevoEstado,
        notas: deuda.notas,
      ),
    );

    if (cuenta != null) {
      await _cuentaRepository.actualizar(
        cuenta.copyWith(saldoActual: cuenta.saldoActual - montoPagado),
      );
    }

    return pago;
  }
}
