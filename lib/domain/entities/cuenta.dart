enum TipoCuenta { debito, credito, billetera, efectivo }

enum Moneda { pen, usd }

class Cuenta {
  final String id;
  final String nombre;
  final TipoCuenta tipo;
  final Moneda moneda;
  final double saldoActual;

  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldoActual,
  });

  Cuenta copyWith({
    String? nombre,
    TipoCuenta? tipo,
    Moneda? moneda,
    double? saldoActual,
  }) {
    return Cuenta(
      id: id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      moneda: moneda ?? this.moneda,
      saldoActual: saldoActual ?? this.saldoActual,
    );
  }
}
