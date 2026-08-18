import '../repositories/categoria_repository.dart';
import '../repositories/transaccion_repository.dart';

class EliminarCategoria {
  final CategoriaRepository _categoriaRepository;
  final TransaccionRepository _transaccionRepository;

  EliminarCategoria({
    required CategoriaRepository categoriaRepository,
    required TransaccionRepository transaccionRepository,
  }) : _categoriaRepository = categoriaRepository,
       _transaccionRepository = transaccionRepository;

  Future<void> call({required String categoriaId}) async {
    final actual = await _categoriaRepository.obtenerPorId(categoriaId);
    if (actual == null) {
      throw ArgumentError('La categoría $categoriaId no existe');
    }
    if (actual.esPredeterminada) {
      throw StateError(
        'Las categorías predeterminadas no se pueden editar ni eliminar',
      );
    }

    final transacciones = await _transaccionRepository.obtenerPorCategoria(
      categoriaId,
    );
    if (transacciones.isNotEmpty) {
      throw StateError(
        'No se puede eliminar una categoría con movimientos registrados',
      );
    }

    await _categoriaRepository.eliminar(categoriaId);
  }
}
