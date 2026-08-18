import '../entities/deuda.dart';

abstract class DeudaRepository {
  Future<List<Deuda>> obtenerTodas();
  Future<List<Deuda>> obtenerActivas();
  Future<Deuda?> obtenerPorId(String id);
  Future<void> crear(Deuda deuda);
  Future<void> actualizar(Deuda deuda);
  Future<void> eliminar(String id);
}
