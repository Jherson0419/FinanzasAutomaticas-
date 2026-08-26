import 'package:uuid/uuid.dart';

import '../cronograma_cuotas.dart';
import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../repositories/deuda_repository.dart';

class RegistrarDeuda {
  final DeudaRepository _deudaRepository;
  final Uuid _uuid;

  RegistrarDeuda({required DeudaRepository deudaRepository, Uuid? uuid})
    : _deudaRepository = deudaRepository,
      _uuid = uuid ?? const Uuid();

  Future<Deuda> call({
    required String nombreDeuda,
    required TipoDeuda tipoDeuda,
    required TipoAcreedor tipoAcreedor,
    required String nombreAcreedor,
    required Moneda moneda,
    required double montoTotal,
    required EstructuraPago estructuraPago,
    // Solo relevantes para `pagoLibre`: en `cuotasFijas` el interés se
    // deriva de `interesTotal` (monto de cuota × número de cuotas − monto
    // total), nunca se pide manualmente.
    bool tieneInteres = false,
    double? tasaInteres,
    TipoTasa? tipoTasa,
    double? pagoMinimo,
    // Solo relevantes para `cuotasFijas`.
    int? numeroCuotasTotal,
    double? montoCuota,
    PeriodicidadCuota? periodicidadCuotas,
    required DateTime fechaInicio,
    int? diaPago,
    String? notas,
    String? amigoUsuarioId,
  }) async {
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
          id: '',
          nombreDeuda: nombreDeuda,
          tipoDeuda: tipoDeuda,
          tipoAcreedor: tipoAcreedor,
          nombreAcreedor: nombreAcreedor,
          moneda: moneda,
          montoTotal: montoTotal,
          montoPagado: 0,
          tieneInteres: tieneInteresFinal,
          estructuraPago: estructuraPago,
          numeroCuotasTotal: numeroCuotasTotal,
          montoCuota: montoCuota,
          periodicidadCuotas: periodicidadCuotas,
          fechaInicio: fechaInicio,
          enMora: false,
          estado: EstadoDeuda.activa,
        ),
        const [],
      );
      proximaFechaPago = proximaFechaPagoDesdeCronograma(cronograma);
      fechaVencimientoFinal = fechaVencimientoFinalDesdeCronograma(cronograma);
    }

    final deuda = Deuda(
      id: _uuid.v4(),
      nombreDeuda: nombreDeuda,
      tipoDeuda: tipoDeuda,
      tipoAcreedor: tipoAcreedor,
      nombreAcreedor: nombreAcreedor,
      moneda: moneda,
      montoTotal: montoTotal,
      montoPagado: 0,
      tieneInteres: tieneInteresFinal,
      tasaInteres: esCuotasFijas ? null : tasaInteres,
      tipoTasa: esCuotasFijas ? null : tipoTasa,
      estructuraPago: estructuraPago,
      numeroCuotasTotal: numeroCuotasTotal,
      numeroCuotasPagadas: esCuotasFijas ? 0 : null,
      montoCuota: montoCuota,
      pagoMinimo: esCuotasFijas ? null : pagoMinimo,
      periodicidadCuotas: esCuotasFijas ? periodicidadCuotas : null,
      interesTotal: esCuotasFijas ? interesTotal : null,
      fechaInicio: fechaInicio,
      fechaVencimientoFinal: fechaVencimientoFinal,
      diaPago: diaPago,
      proximaFechaPago: proximaFechaPago,
      enMora: false,
      diasMora: null,
      tasaInteresMoratorio: null,
      estado: EstadoDeuda.activa,
      notas: notas,
      amigoUsuarioId: amigoUsuarioId,
    );

    await _deudaRepository.crear(deuda);
    return deuda;
  }
}
