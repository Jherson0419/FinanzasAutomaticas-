import 'package:drift/drift.dart';

import '../../../domain/entities/categoria.dart';
import '../../../domain/repositories/categoria_repository.dart';
import 'app_database.dart';

class CategoriaRepositoryDrift implements CategoriaRepository {
  final AppDatabase _db;

  CategoriaRepositoryDrift(this._db);

  @override
  Future<List<Categoria>> obtenerTodas() async {
    final rows = await _db.select(_db.categorias).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Categoria?> obtenerPorId(String id) async {
    final row = await (_db.select(
      _db.categorias,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> crear(Categoria categoria) {
    return _db.into(_db.categorias).insert(_toCompanion(categoria));
  }

  @override
  Future<void> actualizar(Categoria categoria) {
    return _db.update(_db.categorias).replace(_toCompanion(categoria));
  }

  @override
  Future<void> eliminar(String id) async {
    await (_db.delete(_db.categorias)..where((t) => t.id.equals(id))).go();
  }

  Categoria _toDomain(CategoriaRow row) {
    return Categoria(
      id: row.id,
      nombre: row.nombre,
      tipo: TipoCategoria.values.byName(row.tipo),
      iconName: row.iconName,
      esPredeterminada: row.esPredeterminada,
    );
  }

  CategoriasCompanion _toCompanion(Categoria categoria) {
    return CategoriasCompanion.insert(
      id: categoria.id,
      nombre: categoria.nombre,
      tipo: categoria.tipo.name,
      iconName: categoria.iconName,
      esPredeterminada: Value(categoria.esPredeterminada),
    );
  }
}
