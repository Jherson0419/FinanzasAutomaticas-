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

/// Fase 82 — quién le debe a quién. `debo`: yo le debo al acreedor (toda
/// deuda anterior a esta fase). `meDeben`: una persona me debe a mí (un
/// préstamo que hice). En `meDeben` el "acreedor" guardado es en realidad
/// el DEUDOR (`nombreAcreedor` = quién me debe) y un pago es un COBRO.
enum DireccionDeuda { debo, meDeben }

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

  /// Fase 82 — `debo` por defecto: toda deuda existente (Drift migrada a
  /// schemaVersion 11, filas de Supabase sin la columna) se comporta igual
  /// que antes.
  final DireccionDeuda direccion;

  bool get meDeben => direccion == DireccionDeuda.meDeben;

  /// Fase 84 — suma de los abonos a capital (solo cuotas fijas). Va dentro
  /// de `montoPagado` y de `totalAPagar` (`cuota × n + abonado`), así
  /// `saldoPendiente` sigue cuadrando aunque el plazo se acorte.
  final double montoAbonadoCapital;

  /// Fase 84b — monto de la ÚLTIMA cuota cuando un abono a capital la dejó
  /// menor que [montoCuota]. `null` = la última cuota es la normal (toda
  /// deuda sin abonos, o abonos que liberaron cuotas enteras).
  final double? montoUltimaCuota;

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
    this.direccion = DireccionDeuda.debo,
    this.montoAbonadoCapital = 0,
    this.montoUltimaCuota,
  });

  /// Copia con TODOS los campos (Fase 79 — antes cubría solo 8 y cada caso
  /// de uso que necesitaba otro reconstruía `Deuda` a mano; así fue como
  /// `RegistrarPagoDeuda` perdía `amigoUsuarioId`). Úsalo siempre que se
  /// actualice una deuda existente.
  ///
  /// Patrón `campo ?? this.campo`: pasar `null` significa "no cambiar".
  /// Para anular un campo nullable se reconstruye `Deuda` explícitamente
  /// con los 30 campos (como hace `EditarDeuda`), salvo
  /// [sinProximaFechaPago], el único caso que hoy lo necesita en una
  /// actualización parcial (`RegistrarPagoDeuda` al pagar la última cuota).
  Deuda copyWith({
    String? nombreDeuda,
    TipoDeuda? tipoDeuda,
    TipoAcreedor? tipoAcreedor,
    String? nombreAcreedor,
    Moneda? moneda,
    double? montoTotal,
    double? montoPagado,
    bool? tieneInteres,
    double? tasaInteres,
    bool sinTasaInteres = false,
    TipoTasa? tipoTasa,
    EstructuraPago? estructuraPago,
    int? numeroCuotasTotal,
    int? numeroCuotasPagadas,
    double? montoCuota,
    double? pagoMinimo,
    PeriodicidadCuota? periodicidadCuotas,
    double? interesTotal,
    DateTime? fechaInicio,
    DateTime? fechaVencimientoFinal,
    int? diaPago,
    DateTime? proximaFechaPago,
    bool sinProximaFechaPago = false,
    bool? enMora,
    int? diasMora,
    double? tasaInteresMoratorio,
    EstadoDeuda? estado,
    String? notas,
    String? cuentaId,
    String? amigoUsuarioId,
    DireccionDeuda? direccion,
    double? montoAbonadoCapital,
    double? montoUltimaCuota,
    bool sinMontoUltimaCuota = false,
  }) {
    return Deuda(
      id: id,
      nombreDeuda: nombreDeuda ?? this.nombreDeuda,
      tipoDeuda: tipoDeuda ?? this.tipoDeuda,
      tipoAcreedor: tipoAcreedor ?? this.tipoAcreedor,
      nombreAcreedor: nombreAcreedor ?? this.nombreAcreedor,
      moneda: moneda ?? this.moneda,
      montoTotal: montoTotal ?? this.montoTotal,
      montoPagado: montoPagado ?? this.montoPagado,
      tieneInteres: tieneInteres ?? this.tieneInteres,
      // Fase 83: `sinTasaInteres` permite borrarla (TCEA de tarjeta quitada).
      tasaInteres: sinTasaInteres ? null : (tasaInteres ?? this.tasaInteres),
      tipoTasa: tipoTasa ?? this.tipoTasa,
      estructuraPago: estructuraPago ?? this.estructuraPago,
      numeroCuotasTotal: numeroCuotasTotal ?? this.numeroCuotasTotal,
      numeroCuotasPagadas: numeroCuotasPagadas ?? this.numeroCuotasPagadas,
      montoCuota: montoCuota ?? this.montoCuota,
      pagoMinimo: pagoMinimo ?? this.pagoMinimo,
      periodicidadCuotas: periodicidadCuotas ?? this.periodicidadCuotas,
      interesTotal: interesTotal ?? this.interesTotal,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaVencimientoFinal:
          fechaVencimientoFinal ?? this.fechaVencimientoFinal,
      diaPago: diaPago ?? this.diaPago,
      proximaFechaPago: sinProximaFechaPago
          ? null
          : (proximaFechaPago ?? this.proximaFechaPago),
      enMora: enMora ?? this.enMora,
      diasMora: diasMora ?? this.diasMora,
      tasaInteresMoratorio: tasaInteresMoratorio ?? this.tasaInteresMoratorio,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      cuentaId: cuentaId ?? this.cuentaId,
      amigoUsuarioId: amigoUsuarioId ?? this.amigoUsuarioId,
      direccion: direccion ?? this.direccion,
      montoAbonadoCapital: montoAbonadoCapital ?? this.montoAbonadoCapital,
      // Fase 84b: `sinMontoUltimaCuota` la devuelve a la cuota normal (un
      // abono posterior que ya no deja última cuota parcial).
      montoUltimaCuota: sinMontoUltimaCuota
          ? null
          : (montoUltimaCuota ?? this.montoUltimaCuota),
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

  /// Fase 82 — dirección de la fila ORIGINAL, desde el punto de vista de
  /// su dueño (`deudorUsuarioId`, quien la registró). Quien la ve es el
  /// amigo, así que la etiqueta se invierte (ver [yoDebo]).
  final DireccionDeuda direccion;

  /// Desde mi punto de vista (soy el amigo vinculado): si el dueño la
  /// registró como `meDeben` ("el amigo me debe"), YO le debo a él →
  /// "Debes a {dueño}". Si la registró como `debo`, él me debe a mí →
  /// "{dueño} te debe" (comportamiento de siempre).
  bool get yoDebo => direccion == DireccionDeuda.meDeben;

  const DeudaDeAmigo({
    required this.id,
    required this.deudorUsuarioId,
    required this.nombreDeuda,
    required this.montoAdeudado,
    required this.moneda,
    this.direccion = DireccionDeuda.debo,
  });
}
