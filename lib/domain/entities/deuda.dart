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

  /// Solo para deudas auto-generadas y vinculadas 1:1 a una cuenta de
  /// crédito (Fase 62) — `null` para cualquier deuda normal creada a mano.
  /// Cuando no es `null`, esta deuda se sincroniza sola desde los
  /// movimientos de esa cuenta (`SincronizarDeudaTarjeta`) y no se
  /// administra como una deuda cualquiera: `RegistrarPagoDeuda`,
  /// `EditarDeuda` y `EliminarDeuda` la rechazan explícitamente.
  final String? cuentaId;

  /// `usuario_id` de un amigo de Finzo (Fase 64) cuando esta deuda es con
  /// él — `null` para cualquier deuda normal, incluida la mayoría de las
  /// deudas con `tipoAcreedor == personaNatural` (vincular un amigo es
  /// opcional, no automático solo por ser una persona natural). Habilita
  /// notificarle un pago (`RegistrarPagoDeuda`) sin exponerle el resto de
  /// la deuda.
  final String? amigoUsuarioId;

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
    this.cuentaId,
    this.amigoUsuarioId,
  });

  /// [montoTotal]/[nombreDeuda] agregados (Fase 62) para que
  /// `EditarCuenta` pueda sincronizar la deuda vinculada a una tarjeta de
  /// crédito cuando cambia la línea o el nombre de la cuenta, sin tener que
  /// reconstruir `Deuda` a mano — mismo criterio que `montoPagado`, ambos
  /// campos no-nulos sin ninguna ambigüedad "no cambiar" vs. "poner null".
  Deuda copyWith({
    String? nombreDeuda,
    double? montoTotal,
    double? montoPagado,
    int? numeroCuotasPagadas,
    DateTime? proximaFechaPago,
    bool? enMora,
    int? diasMora,
    EstadoDeuda? estado,
  }) {
    return Deuda(
      id: id,
      nombreDeuda: nombreDeuda ?? this.nombreDeuda,
      tipoDeuda: tipoDeuda,
      tipoAcreedor: tipoAcreedor,
      nombreAcreedor: nombreAcreedor,
      moneda: moneda,
      montoTotal: montoTotal ?? this.montoTotal,
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
      cuentaId: cuentaId,
      amigoUsuarioId: amigoUsuarioId,
    );
  }
}

/// Vista de solo lectura de una deuda vinculada a mí como amigo (Fase 68,
/// `deudas.amigo_usuario_id = auth.uid()`) — deliberadamente NO es un
/// `Deuda` completo: quien la ve no es su dueño, así que solo expone lo
/// mínimo para mostrar "{nick del deudor} te debe {monto}" en "Te deben"
/// (`presentation/screens/dashboard/widgets/te_deben_section.dart`), nunca
/// el resto de los campos de una deuda ajena.
class DeudaDeAmigo {
  final String id;

  /// `user_id` de la fila — quien registró la deuda y me la debe a mí, no
  /// quien la está viendo. `DeudaRepositoryDrift` nunca puede resolver
  /// esto (no hay forma de ver deudas de otro usuario en almacenamiento
  /// local); solo `DeudaRepositorySupabase` lo devuelve de verdad.
  final String deudorUsuarioId;
  final String nombreDeuda;

  /// `montoTotal - montoPagado` de la deuda original, ya calculado —
  /// "Te deben" no necesita el desglose completo.
  final double montoAdeudado;
  final Moneda moneda;

  const DeudaDeAmigo({
    required this.id,
    required this.deudorUsuarioId,
    required this.nombreDeuda,
    required this.montoAdeudado,
    required this.moneda,
  });
}
