import '../cronograma_cuotas.dart';
import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../saldo_deuda.dart';

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
    String? amigoUsuarioId,
  }) async {
    final actual = await _deudaRepository.obtenerPorId(deudaId);
    if (actual == null) {
      throw ArgumentError('La deuda $deudaId no existe');
    }
    if (actual.cuentaId != null) {
      throw StateError(
        'Edita o elimina la cuenta de crédito directamente, esta deuda se '
        'sincroniza sola.',
      );
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

    // Fase 84: con abonos, lo abonado también se pagó (ver `totalAPagar`)
    // y la TEA quedó congelada en `tasaInteres` (ver `tasaEfectivaAnual`).
    final conAbonos = esCuotasFijas && actual.montoAbonadoCapital > 0;
    // Fase 84b: la última cuota parcial se conserva (solo en cuotas fijas
    // y mientras no supere la cuota editada).
    final montoUltimaCuota =
        esCuotasFijas &&
            actual.montoUltimaCuota != null &&
            montoCuota != null &&
            actual.montoUltimaCuota! <= montoCuota
        ? actual.montoUltimaCuota
        : null;
    double? interesTotal;
    if (esCuotasFijas && numeroCuotasTotal != null && montoCuota != null) {
      interesTotal =
          totalAPagarDe(
            estructuraPago: estructuraPago,
            montoTotal: montoTotal,
            montoCuota: montoCuota,
            numeroCuotasTotal: numeroCuotasTotal,
            montoAbonadoCapital: actual.montoAbonadoCapital,
            montoUltimaCuota: montoUltimaCuota,
          ) -
          montoTotal;
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
          montoUltimaCuota: montoUltimaCuota,
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
      tasaInteres: conAbonos
          ? actual.tasaInteres
          : (esCuotasFijas ? null : tasaInteres),
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
      // Siempre `null` aquí (las deudas de tarjeta se rechazan arriba),
      // pero se copia explícito: esta reconstrucción a mano (necesaria para
      // poder anular campos de cuotas/interés) debe listar los 29 campos.
      cuentaId: actual.cuentaId,
      amigoUsuarioId: amigoUsuarioId,
      // Fase 82: la dirección se fija al crear y no se edita (cambiarla
      // invertiría el sentido de los pagos ya registrados, y en Supabase
      // `debo` no se envía mientras no exista la columna — ver aFila).
      direccion: actual.direccion,
      // Fase 84: los abonos ya hechos se conservan al editar.
      montoAbonadoCapital: actual.montoAbonadoCapital,
      montoUltimaCuota: montoUltimaCuota,
    );

    await _deudaRepository.actualizar(actualizada);
    return actualizada;
  }
}
