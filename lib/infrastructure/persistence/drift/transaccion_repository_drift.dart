import 'package:drift/drift.dart';

import '../../../domain/entities/cuenta.dart';
import '../../../domain/entities/transaccion.dart';
import '../../../domain/repositories/transaccion_repository.dart';
import 'app_database.dart';

class TransaccionRepositoryDrift implements TransaccionRepository {
  final AppDatabase _db;

  TransaccionRepositoryDrift(this._db);

  @override
  Future<List<Transaccion>> obtenerTodas() async {
    final rows = await _db.select(_db.transacciones).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Transaccion?> obtenerPorId(String id) async {
    final row = await (_db.select(
      _db.transacciones,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async {
    final rows = await (_db.select(
      _db.transacciones,
    )..where((t) => t.cuentaId.equals(cuentaId))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async {
    final rows = await (_db.select(
      _db.transacciones,
    )..where((t) => t.categoriaId.equals(categoriaId))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async {
    final rows =
        await (_db.select(_db.transacciones)..where(
              (t) =>
                  t.fecha.isBiggerOrEqualValue(desde) &
                  t.fecha.isSmallerOrEqualValue(hasta),
            ))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async {
    final rows =
        await (_db.select(_db.transacciones)
              ..orderBy([(t) => OrderingTerm.desc(t.fecha)])
              ..limit(limite))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> crear(Transaccion transaccion) {
    return _db.into(_db.transacciones).insert(_toCompanion(transaccion));
  }

  @override
  Future<void> actualizar(Transaccion transaccion) {
    return _db.update(_db.transacciones).replace(_toCompanion(transaccion));
  }

  @override
  Future<void> eliminar(String id) async {
    await (_db.delete(_db.transacciones)..where((t) => t.id.equals(id))).go();
  }

  Transaccion _toDomain(TransaccionRow row) {
    return Transaccion(
      id: row.id,
      cuentaId: row.cuentaId,
      categoriaId: row.categoriaId,
      monto: row.monto,
      moneda: Moneda.values.byName(row.moneda),
      tipo: TipoTransaccion.values.byName(row.tipo),
      concepto: row.concepto,
      metodoPago: MetodoPago.values.byName(row.metodoPago),
      esRecurrente: row.esRecurrente,
      comprobanteUrl: row.comprobanteUrl,
      fuenteCaptura: FuenteCaptura.values.byName(row.fuenteCaptura),
      dataRaw: row.dataRaw,
      fecha: row.fecha,
    );
  }

  TransaccionesCompanion _toCompanion(Transaccion transaccion) {
    return TransaccionesCompanion.insert(
      id: transaccion.id,
      cuentaId: transaccion.cuentaId,
      categoriaId: transaccion.categoriaId,
      monto: transaccion.monto,
      moneda: transaccion.moneda.name,
      tipo: transaccion.tipo.name,
      concepto: transaccion.concepto,
      metodoPago: transaccion.metodoPago.name,
      esRecurrente: Value(transaccion.esRecurrente),
      comprobanteUrl: Value(transaccion.comprobanteUrl),
      fuenteCaptura: transaccion.fuenteCaptura.name,
      dataRaw: Value(transaccion.dataRaw),
      fecha: transaccion.fecha,
    );
  }
}
