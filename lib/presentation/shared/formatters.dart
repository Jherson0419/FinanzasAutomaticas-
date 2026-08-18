import 'package:intl/intl.dart';

import '../../domain/entities/cuenta.dart';

final _numeroFormatter = NumberFormat('#,##0.00');

String simboloMoneda(Moneda moneda) {
  switch (moneda) {
    case Moneda.pen:
      return 'S/';
    case Moneda.usd:
      return r'US$';
  }
}

String formatearMonto(double monto, Moneda moneda) {
  return '${simboloMoneda(moneda)} ${_numeroFormatter.format(monto)}';
}

String formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}
