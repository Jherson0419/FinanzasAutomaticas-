import 'entities/transaccion.dart';

/// Aplica el efecto de una transacción sobre un saldo: resta si es gasto,
/// suma si es ingreso. Compartido por `RegistrarGasto`, `RegistrarIngreso`
/// y `EditarTransaccion` para no repetir la aritmética en cada caso de uso.
double aplicarEfectoTransaccion(
  double saldoActual,
  TipoTransaccion tipo,
  double monto,
) {
  return tipo == TipoTransaccion.gasto
      ? saldoActual - monto
      : saldoActual + monto;
}

/// Inversa de [aplicarEfectoTransaccion]: revierte el efecto de una
/// transacción sobre un saldo (usado al editar o eliminar una transacción
/// ya registrada, antes de aplicar el nuevo efecto si corresponde).
double revertirEfectoTransaccion(
  double saldoActual,
  TipoTransaccion tipo,
  double monto,
) {
  return tipo == TipoTransaccion.gasto
      ? saldoActual + monto
      : saldoActual - monto;
}
