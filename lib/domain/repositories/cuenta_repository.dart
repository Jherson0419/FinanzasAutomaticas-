import '../entities/cuenta.dart';

abstract class CuentaRepository {
  Future<List<Cuenta>> obtenerTodas();
  Future<Cuenta?> obtenerPorId(String id);
  Future<void> crear(Cuenta cuenta);
  Future<void> actualizar(Cuenta cuenta);
  Future<void> eliminar(String id);
}
