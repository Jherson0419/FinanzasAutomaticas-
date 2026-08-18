import 'package:uuid/uuid.dart';

import '../entities/categoria.dart';
import '../repositories/categoria_repository.dart';

class CrearCategoria {
  final CategoriaRepository _categoriaRepository;
  final Uuid _uuid;

  CrearCategoria({required CategoriaRepository categoriaRepository, Uuid? uuid})
    : _categoriaRepository = categoriaRepository,
      _uuid = uuid ?? const Uuid();

  Future<Categoria> call({
    required String nombre,
    required TipoCategoria tipo,
    required String iconName,
  }) async {
    final categoria = Categoria(
      id: _uuid.v4(),
      nombre: nombre,
      tipo: tipo,
      iconName: iconName,
      esPredeterminada: false,
    );

    await _categoriaRepository.crear(categoria);
    return categoria;
  }
}
