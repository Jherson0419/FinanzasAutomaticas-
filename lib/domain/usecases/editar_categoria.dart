import '../entities/categoria.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/transaccion_repository.dart';

/// Edita nombre, tipo e ícono de una categoría propia del usuario. Las
/// categorías predeterminadas (sembradas por la app) nunca se pueden editar.
class EditarCategoria {
  final CategoriaRepository _categoriaRepository;
  final TransaccionRepository _transaccionRepository;

  EditarCategoria({
    required CategoriaRepository categoriaRepository,
    required TransaccionRepository transaccionRepository,
  }) : _categoriaRepository = categoriaRepository,
       _transaccionRepository = transaccionRepository;

  Future<Categoria> call({
    required String categoriaId,
    required String nombre,
    required TipoCategoria tipo,
    required String iconName,
  }) async {
    final actual = await _categoriaRepository.obtenerPorId(categoriaId);
    if (actual == null) {
      throw ArgumentError('La categoría $categoriaId no existe');
    }
    if (actual.esPredeterminada) {
      throw StateError(
        'Las categorías predeterminadas no se pueden editar ni eliminar',
      );
    }

    if (tipo != actual.tipo) {
      final transacciones = await _transaccionRepository.obtenerPorCategoria(
        categoriaId,
      );
      if (transacciones.isNotEmpty) {
        throw StateError(
          'No se puede cambiar el tipo de una categoría con movimientos registrados',
        );
      }
    }

    final actualizada = actual.copyWith(
      nombre: nombre,
      tipo: tipo,
      iconName: iconName,
    );
    await _categoriaRepository.actualizar(actualizada);
    return actualizada;
  }
}
