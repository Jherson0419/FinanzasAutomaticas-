import 'cuenta.dart';

enum TipoDeuda {
  tarjetaCredito,
  prestamoPersonal,
  prestamoVehicular,
  hipoteca,
  prestamoEstudiantil,
  compraCuotas,
  deudaInformal,
  otro,
}

enum TipoAcreedor { entidadFinanciera, personaNatural, comercio }

enum TipoTasa { fija, variable }

enum EstructuraPago { cuotasFijas, pagoLibre }

enum EstadoDeuda { activa, pagada, enMora, refinanciada, cancelada }

/// Frecuencia entre cuotas de una deuda `cuotasFijas`. Requerida para esa
/// estructura de pago, `null` para `pagoLibre`.
enum PeriodicidadCuota { mensual, quincenal }

class Deuda {
  final String id;
  final String nombreDeuda;
  final TipoDeuda tipoDeuda;
  final TipoAcreedor tipoAcreedor;
  final String nombreAcreedor;
  final Moneda moneda;
  final double montoTotal;
  final double montoPagado;
  final bool tieneInteres;
  final double? tasaInteres;
  final TipoTasa? tipoTasa;
  final EstructuraPago estructuraPago;
  final int? numeroCuotasTotal;
  final int? numeroCuotasPagadas;
  final double? montoCuota;
  final double? pagoMinimo;
  final PeriodicidadCuota? periodicidadCuotas;
  final double? interesTotal;
  final DateTime fechaInicio;
  final DateTime? fechaVencimientoFinal;
  final int? diaPago;
  final DateTime? proximaFechaPago;
  final bool enMora;
  final int? diasMora;
  final double? tasaInteresMoratorio;
  final EstadoDeuda estado;
  final String? notas;

  const Deuda({
    required this.id,
    required this.nombreDeuda,
    required this.tipoDeuda,
    required this.tipoAcreedor,
    required this.nombreAcreedor,
    required this.moneda,
    required this.montoTotal,
    required this.montoPagado,
    required this.tieneInteres,
    this.tasaInteres,
    this.tipoTasa,
    required this.estructuraPago,
    this.numeroCuotasTotal,
    this.numeroCuotasPagadas,
    this.montoCuota,
    this.pagoMinimo,
    this.periodicidadCuotas,
    this.interesTotal,
    required this.fechaInicio,
    this.fechaVencimientoFinal,
    this.diaPago,
    this.proximaFechaPago,
    required this.enMora,
    this.diasMora,
    this.tasaInteresMoratorio,
    required this.estado,
    this.notas,
  });

  Deuda copyWith({
    double? montoPagado,
    int? numeroCuotasPagadas,
    DateTime? proximaFechaPago,
    bool? enMora,
    int? diasMora,
    EstadoDeuda? estado,
  }) {
    return Deuda(
      id: id,
      nombreDeuda: nombreDeuda,
      tipoDeuda: tipoDeuda,
      tipoAcreedor: tipoAcreedor,
      nombreAcreedor: nombreAcreedor,
      moneda: moneda,
      montoTotal: montoTotal,
      montoPagado: montoPagado ?? this.montoPagado,
      tieneInteres: tieneInteres,
      tasaInteres: tasaInteres,
      tipoTasa: tipoTasa,
      estructuraPago: estructuraPago,
      numeroCuotasTotal: numeroCuotasTotal,
      numeroCuotasPagadas: numeroCuotasPagadas ?? this.numeroCuotasPagadas,
      montoCuota: montoCuota,
      pagoMinimo: pagoMinimo,
      periodicidadCuotas: periodicidadCuotas,
      interesTotal: interesTotal,
      fechaInicio: fechaInicio,
      fechaVencimientoFinal: fechaVencimientoFinal,
      diaPago: diaPago,
      proximaFechaPago: proximaFechaPago ?? this.proximaFechaPago,
      enMora: enMora ?? this.enMora,
      diasMora: diasMora ?? this.diasMora,
      tasaInteresMoratorio: tasaInteresMoratorio,
      estado: estado ?? this.estado,
      notas: notas,
    );
  }
}
