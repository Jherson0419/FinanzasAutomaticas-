import '../cronograma_cuotas.dart';
import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';

/// Edita los campos "de definición" de una deuda. Nunca toca
/// `montoPagado`, `numeroCuotasPagadas`, `estado`, `enMora` ni `diasMora`
/// — esos son derivados de los pagos registrados, no editables a mano.
class EditarDeuda {
  final DeudaRepository _deudaRepository;
  final PagoDeudaRepository _pagoDeudaRepository;

  EditarDeuda({
    required DeudaRepository deudaRepository,
    required PagoDeudaRepository pagoDeudaRepository,
  }) : _deudaRepository = deudaRepository,
       _pagoDeudaRepository = pagoDeudaRepository;

  Future<Deuda> call({
    required String deudaId,
    required String nombreDeuda,
    required TipoDeuda tipoDeuda,
    required TipoAcreedor tipoAcreedor,
    required String nombreAcreedor,
    required Moneda moneda,
    required double montoTotal,
    required EstructuraPago estructuraPago,
    bool tieneInteres = false,
    double? tasaInteres,
    TipoTasa? tipoTasa,
    double? pagoMinimo,
    int? numeroCuotasTotal,
    double? montoCuota,
    PeriodicidadCuota? periodicidadCuotas,
    required DateTime fechaInicio,
    int? diaPago,
    String? notas,
  }) async {
    final actual = await _deudaRepository.obtenerPorId(deudaId);
    if (actual == null) {
      throw ArgumentError('La deuda $deudaId no existe');
    }

    final pagos = await _pagoDeudaRepository.obtenerPorDeuda(deudaId);
    if (pagos.isNotEmpty) {
      if (moneda != actual.moneda) {
        throw StateError(
          'No se puede cambiar la moneda de una deuda con pagos registrados',
        );
      }
      if (estructuraPago != actual.estructuraPago) {
        throw StateError(
          'No se puede cambiar la estructura de pago de una deuda con pagos registrados',
        );
      }
      if (periodicidadCuotas != actual.periodicidadCuotas) {
        throw StateError(
          'No se puede cambiar la periodicidad de cuotas de una deuda con pagos registrados',
        );
      }
    }

    final esCuotasFijas = estructuraPago == EstructuraPago.cuotasFijas;

    double? interesTotal;
    if (esCuotasFijas && numeroCuotasTotal != null && montoCuota != null) {
      interesTotal = (montoCuota * numeroCuotasTotal) - montoTotal;
    }
    final tieneInteresFinal = esCuotasFijas
        ? (interesTotal != null && interesTotal > 0)
        : tieneInteres;

    DateTime? proximaFechaPago;
    DateTime? fechaVencimientoFinal;
    if (esCuotasFijas &&
        numeroCuotasTotal != null &&
        montoCuota != null &&
        periodicidadCuotas != null) {
      final cronograma = generarCronogramaCuotas(
        Deuda(
          id: deudaId,
          nombreDeuda: nombreDeuda,
          tipoDeuda: tipoDeuda,
          tipoAcreedor: tipoAcreedor,
          nombreAcreedor: nombreAcreedor,
          moneda: moneda,
          montoTotal: montoTotal,
          montoPagado: actual.montoPagado,
          tieneInteres: tieneInteresFinal,
          estructuraPago: estructuraPago,
          numeroCuotasTotal: numeroCuotasTotal,
          montoCuota: montoCuota,
          periodicidadCuotas: periodicidadCuotas,
          fechaInicio: fechaInicio,
          enMora: actual.enMora,
          estado: actual.estado,
        ),
        pagos,
      );
      proximaFechaPago = proximaFechaPagoDesdeCronograma(cronograma);
      fechaVencimientoFinal = fechaVencimientoFinalDesdeCronograma(cronograma);
    }

    final actualizada = Deuda(
      id: deudaId,
      nombreDeuda: nombreDeuda,
      tipoDeuda: tipoDeuda,
      tipoAcreedor: tipoAcreedor,
      nombreAcreedor: nombreAcreedor,
      moneda: moneda,
      montoTotal: montoTotal,
      montoPagado: actual.montoPagado,
      tieneInteres: tieneInteresFinal,
      tasaInteres: esCuotasFijas ? null : tasaInteres,
      tipoTasa: esCuotasFijas ? null : tipoTasa,
      estructuraPago: estructuraPago,
      numeroCuotasTotal: numeroCuotasTotal,
      numeroCuotasPagadas: actual.numeroCuotasPagadas,
      montoCuota: montoCuota,
      pagoMinimo: esCuotasFijas ? null : pagoMinimo,
      periodicidadCuotas: esCuotasFijas ? periodicidadCuotas : null,
      interesTotal: esCuotasFijas ? interesTotal : null,
      fechaInicio: fechaInicio,
      fechaVencimientoFinal: fechaVencimientoFinal,
      diaPago: diaPago,
      proximaFechaPago: proximaFechaPago,
      enMora: actual.enMora,
      diasMora: actual.diasMora,
      tasaInteresMoratorio: actual.tasaInteresMoratorio,
      estado: actual.estado,
      notas: notas,
    );

    await _deudaRepository.actualizar(actualizada);
    return actualizada;
  }
}
