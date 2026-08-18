import '../entities/transaccion.dart';

abstract class TransaccionRepository {
  Future<List<Transaccion>> obtenerTodas();
  Future<Transaccion?> obtenerPorId(String id);
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId);
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId);
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  );
  Future<List<Transaccion>> obtenerRecientes(int limite);
  Future<void> crear(Transaccion transaccion);
  Future<void> actualizar(Transaccion transaccion);
  Future<void> eliminar(String id);
}
