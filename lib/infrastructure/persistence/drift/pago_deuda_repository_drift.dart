import 'package:drift/drift.dart';

import '../../../domain/entities/pago_deuda.dart';
import '../../../domain/repositories/pago_deuda_repository.dart';
import 'app_database.dart';

class PagoDeudaRepositoryDrift implements PagoDeudaRepository {
  final AppDatabase _db;

  PagoDeudaRepositoryDrift(this._db);

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async {
    final rows = await (_db.select(
      _db.pagosDeuda,
    )..where((t) => t.deudaId.equals(deudaId))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async {
    final rows = await (_db.select(
      _db.pagosDeuda,
    )..where((t) => t.cuentaId.equals(cuentaId))).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> crear(PagoDeuda pago) {
    return _db.into(_db.pagosDeuda).insert(_toCompanion(pago));
  }

  @override
  Future<void> eliminar(String id) async {
    await (_db.delete(_db.pagosDeuda)..where((t) => t.id.equals(id))).go();
  }

  PagoDeuda _toDomain(PagoDeudaRow row) {
    return PagoDeuda(
      id: row.id,
      deudaId: row.deudaId,
      cuentaId: row.cuentaId,
      montoPagado: row.montoPagado,
      montoCapital: row.montoCapital,
      montoInteres: row.montoInteres,
      fechaPago: row.fechaPago,
      numeroCuota: row.numeroCuota,
    );
  }

  PagosDeudaCompanion _toCompanion(PagoDeuda pago) {
    return PagosDeudaCompanion.insert(
      id: pago.id,
      deudaId: pago.deudaId,
      cuentaId: Value(pago.cuentaId),
      montoPagado: pago.montoPagado,
      montoCapital: Value(pago.montoCapital),
      montoInteres: Value(pago.montoInteres),
      fechaPago: pago.fechaPago,
      numeroCuota: Value(pago.numeroCuota),
    );
  }
}
