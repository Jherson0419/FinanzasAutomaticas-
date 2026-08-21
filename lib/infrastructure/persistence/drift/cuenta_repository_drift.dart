import 'package:drift/drift.dart';

import '../../../domain/entities/cuenta.dart';
import '../../../domain/repositories/cuenta_repository.dart';
import 'app_database.dart';

class CuentaRepositoryDrift implements CuentaRepository {
  final AppDatabase _db;

  CuentaRepositoryDrift(this._db);

  @override
  Future<List<Cuenta>> obtenerTodas() async {
    final rows = await _db.select(_db.cuentas).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Cuenta?> obtenerPorId(String id) async {
    final row = await (_db.select(
      _db.cuentas,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> crear(Cuenta cuenta) {
    return _db.into(_db.cuentas).insert(_toCompanion(cuenta));
  }

  @override
  Future<void> actualizar(Cuenta cuenta) {
    return _db.update(_db.cuentas).replace(_toCompanion(cuenta));
  }

  @override
  Future<void> eliminar(String id) async {
    await (_db.delete(_db.cuentas)..where((t) => t.id.equals(id))).go();
  }

  Cuenta _toDomain(CuentaRow row) {
    return Cuenta(
      id: row.id,
      nombre: row.nombre,
      tipo: TipoCuenta.values.byName(row.tipo),
      moneda: Moneda.values.byName(row.moneda),
      saldoActual: row.saldoActual,
      lineaCredito: row.lineaCredito,
      diaCorte: row.diaCorte,
      diaPago: row.diaPago,
      ultimosDigitos: row.ultimosDigitos,
    );
  }

  CuentasCompanion _toCompanion(Cuenta cuenta) {
    return CuentasCompanion.insert(
      id: cuenta.id,
      nombre: cuenta.nombre,
      tipo: cuenta.tipo.name,
      moneda: cuenta.moneda.name,
      saldoActual: cuenta.saldoActual,
      lineaCredito: Value(cuenta.lineaCredito),
      diaCorte: Value(cuenta.diaCorte),
      diaPago: Value(cuenta.diaPago),
      ultimosDigitos: Value(cuenta.ultimosDigitos),
    );
  }
}
