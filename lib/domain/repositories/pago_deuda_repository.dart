import '../entities/pago_deuda.dart';

abstract class PagoDeudaRepository {
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId);
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId);
  Future<void> crear(PagoDeuda pago);

  /// Borra un pago puntual. Ningún flujo de edición normal lo usa (un pago,
  /// una vez registrado, no se edita ni se borra desde la UI) — existe para
  /// `EliminarCuentaDeUsuario` (Fase 22), que necesita poder borrar todo el
  /// historial de pagos de un usuario antes de borrar sus deudas/cuentas.
  Future<void> eliminar(String id);
}
