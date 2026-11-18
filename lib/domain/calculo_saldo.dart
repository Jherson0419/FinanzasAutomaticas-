import 'entities/transaccion.dart';

/// Aplica el efecto de una transacción sobre un saldo: resta si sale dinero
/// de la cuenta (gasto o salida de una transferencia), suma si entra
/// (ingreso o entrada de una transferencia). Compartido por todos los casos
/// de uso que tocan `saldoActual`.
double aplicarEfectoTransaccion(
  double saldoActual,
  TipoTransaccion tipo,
  double monto,
) => switch (tipo) {
  TipoTransaccion.gasto ||
  TipoTransaccion.transferenciaSalida => saldoActual - monto,
  TipoTransaccion.ingreso ||
  TipoTransaccion.transferenciaEntrada => saldoActual + monto,
};

/// Inversa de [aplicarEfectoTransaccion]: revierte el efecto de una
/// transacción sobre un saldo (usado al editar o eliminar una transacción
/// ya registrada, antes de aplicar el nuevo efecto si corresponde).
double revertirEfectoTransaccion(
  double saldoActual,
  TipoTransaccion tipo,
  double monto,
) => saldoActual - (aplicarEfectoTransaccion(0, tipo, monto));
