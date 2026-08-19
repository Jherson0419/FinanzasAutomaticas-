enum TipoCuenta { debito, credito, billetera, efectivo }

enum Moneda { pen, usd }

class Cuenta {
  final String id;
  final String nombre;
  final TipoCuenta tipo;
  final Moneda moneda;
  final double saldoActual;

  /// Los siguientes 3 campos solo aplican a `tipo == TipoCuenta.credito`
  /// (obligatorios en ese caso, `null` para los demás tipos — validado por
  /// `RegistrarCuenta`/`EditarCuenta`, Fase 29). No existe un campo de
  /// "monto utilizado": se deriva de `saldoActual` — cuando `saldoActual`
  /// es negativo en una cuenta de crédito, su valor absoluto ES lo usado de
  /// la línea; un pago a la tarjeta es un `ingreso` más a esa cuenta, ya
  /// soportado por `aplicarEfectoTransaccion` sin cambios.
  final double? lineaCredito;
  final int? diaCorte;
  final int? diaPago;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldoActual,
    this.lineaCredito,
    this.diaCorte,
    this.diaPago,
  });

  /// Nota: como con `Deuda.copyWith` (ver `INFORME_PROYECTO.md`), el patrón
  /// `campo ?? this.campo` no permite volver a poner `lineaCredito`/
  /// `diaCorte`/`diaPago` en `null`. `EditarCuenta` reconstruye `Cuenta`
  /// directamente en vez de usar `copyWith` cuando el tipo deja de ser
  /// `credito` y esos campos deben anularse.
  Cuenta copyWith({
    String? nombre,
    TipoCuenta? tipo,
    Moneda? moneda,
    double? saldoActual,
    double? lineaCredito,
    int? diaCorte,
    int? diaPago,
  }) {
    return Cuenta(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      moneda: moneda ?? this.moneda,
      saldoActual: saldoActual ?? this.saldoActual,
      lineaCredito: lineaCredito ?? this.lineaCredito,
      diaCorte: diaCorte ?? this.diaCorte,
      diaPago: diaPago ?? this.diaPago,
    );
  }
}
