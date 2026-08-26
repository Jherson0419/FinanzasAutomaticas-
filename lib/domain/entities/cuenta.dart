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

  /// Fecha ancla (día + mes; el año es solo el punto de partida) de corte y
  /// pago (Fase 62, reemplaza `diaCorte`/`diaPago` de la Fase 29). Cada una
  /// avanza de forma INDEPENDIENTE un mes exacto a la vez desde su propia
  /// ancla hasta llegar a una fecha `>= hoy` (`proximaOcurrenciaMensual`) —
  /// así corte y pago mantienen su relación real (ej. pago el 27, corte el
  /// 7 del mes siguiente) sin importar cuál día numérico es mayor, algo que
  /// el `int` 1-31 de la Fase 29 no podía representar.
  final DateTime? fechaCorte;
  final DateTime? fechaPago;

  /// Últimos 4 dígitos de la tarjeta/cuenta (Fase 57), solo para mostrarlos
  /// en la UI (ej. "•••• 4821") — no identifica la cuenta ni se usa en
  /// ninguna validación. Opcional para todos los tipos de cuenta.
  final String? ultimosDigitos;

  /// Pago mínimo mensual de la tarjeta (Fase 65) — solo aplica a
  /// `tipo == credito`, y ahí mismo es opcional (a diferencia de
  /// `lineaCredito`/`fechaCorte`/`fechaPago`, que sí son obligatorios): una
  /// cuenta de crédito recién migrada o creada antes de esta fase no lo
  /// tiene, y la UI debe mostrar "No configurado" en vez de inventar un
  /// S/ 0.00 engañoso (`TarjetaCreditoPagosSection`).
  final double? pagoMinimo;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldoActual,
    this.lineaCredito,
    this.fechaCorte,
    this.fechaPago,
    this.ultimosDigitos,
    this.pagoMinimo,
  });

  /// Nota: como con `Deuda.copyWith` (ver `INFORME_PROYECTO.md`), el patrón
  /// `campo ?? this.campo` no permite volver a poner `lineaCredito`/
  /// `fechaCorte`/`fechaPago` en `null`. `EditarCuenta` reconstruye `Cuenta`
  /// directamente en vez de usar `copyWith` cuando el tipo deja de ser
  /// `credito` y esos campos deben anularse.
  Cuenta copyWith({
    String? nombre,
    TipoCuenta? tipo,
    Moneda? moneda,
    double? saldoActual,
    double? lineaCredito,
    DateTime? fechaCorte,
    DateTime? fechaPago,
    String? ultimosDigitos,
    double? pagoMinimo,
  }) {
    return Cuenta(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      moneda: moneda ?? this.moneda,
      saldoActual: saldoActual ?? this.saldoActual,
      lineaCredito: lineaCredito ?? this.lineaCredito,
      fechaCorte: fechaCorte ?? this.fechaCorte,
      fechaPago: fechaPago ?? this.fechaPago,
      ultimosDigitos: ultimosDigitos ?? this.ultimosDigitos,
      pagoMinimo: pagoMinimo ?? this.pagoMinimo,
    );
  }
}
