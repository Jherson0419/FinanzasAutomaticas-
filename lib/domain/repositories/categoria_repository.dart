import '../entities/categoria.dart';

abstract class CategoriaRepository {
  Future<List<Categoria>> obtenerTodas();
  Future<Categoria?> obtenerPorId(String id);
  Future<void> crear(Categoria categoria);
  Future<void> actualizar(Categoria categoria);
  Future<void> eliminar(String id);
}
