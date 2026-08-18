import 'package:drift/drift.dart';

import '../../../domain/entities/cuenta.dart';
import '../../../domain/entities/deuda.dart';
import '../../../domain/repositories/deuda_repository.dart';
import 'app_database.dart';

class DeudaRepositoryDrift implements DeudaRepository {
  final AppDatabase _db;

  DeudaRepositoryDrift(this._db);

  @override
  Future<List<Deuda>> obtenerTodas() async {
    final rows = await _db.select(_db.deudas).get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<Deuda>> obtenerActivas() async {
    final rows =
        await (_db.select(_db.deudas)..where(
              (t) =>
                  t.estado.equals(EstadoDeuda.activa.name) |
                  t.estado.equals(EstadoDeuda.enMora.name),
            ))
            .get();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<Deuda?> obtenerPorId(String id) async {
    final row = await (_db.select(
      _db.deudas,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row);
  }

  @override
  Future<void> crear(Deuda deuda) {
    return _db.into(_db.deudas).insert(_toCompanion(deuda));
  }

  @override
  Future<void> actualizar(Deuda deuda) {
    return _db.update(_db.deudas).replace(_toCompanion(deuda));
  }

  @override
  Future<void> eliminar(String id) async {
    await (_db.delete(_db.deudas)..where((t) => t.id.equals(id))).go();
  }

  Deuda _toDomain(DeudaRow row) {
    return Deuda(
      id: row.id,
      nombreDeuda: row.nombreDeuda,
      tipoDeuda: TipoDeuda.values.byName(row.tipoDeuda),
      tipoAcreedor: TipoAcreedor.values.byName(row.tipoAcreedor),
      nombreAcreedor: row.nombreAcreedor,
      moneda: Moneda.values.byName(row.moneda),
      montoTotal: row.montoTotal,
      montoPagado: row.montoPagado,
      tieneInteres: row.tieneInteres,
      tasaInteres: row.tasaInteres,
      tipoTasa: row.tipoTasa == null
          ? null
          : TipoTasa.values.byName(row.tipoTasa!),
      estructuraPago: EstructuraPago.values.byName(row.estructuraPago),
      numeroCuotasTotal: row.numeroCuotasTotal,
      numeroCuotasPagadas: row.numeroCuotasPagadas,
      montoCuota: row.montoCuota,
      pagoMinimo: row.pagoMinimo,
      periodicidadCuotas: row.periodicidadCuotas == null
          ? null
          : PeriodicidadCuota.values.byName(row.periodicidadCuotas!),
      interesTotal: row.interesTotal,
      fechaInicio: row.fechaInicio,
      fechaVencimientoFinal: row.fechaVencimientoFinal,
      diaPago: row.diaPago,
      proximaFechaPago: row.proximaFechaPago,
      enMora: row.enMora,
      diasMora: row.diasMora,
      tasaInteresMoratorio: row.tasaInteresMoratorio,
      estado: EstadoDeuda.values.byName(row.estado),
      notas: row.notas,
    );
  }

  DeudasCompanion _toCompanion(Deuda deuda) {
    return DeudasCompanion.insert(
      id: deuda.id,
      nombreDeuda: deuda.nombreDeuda,
      tipoDeuda: deuda.tipoDeuda.name,
      tipoAcreedor: deuda.tipoAcreedor.name,
      nombreAcreedor: deuda.nombreAcreedor,
      moneda: deuda.moneda.name,
      montoTotal: deuda.montoTotal,
      montoPagado: deuda.montoPagado,
      tieneInteres: deuda.tieneInteres,
      tasaInteres: Value(deuda.tasaInteres),
      tipoTasa: Value(deuda.tipoTasa?.name),
      estructuraPago: deuda.estructuraPago.name,
      numeroCuotasTotal: Value(deuda.numeroCuotasTotal),
      numeroCuotasPagadas: Value(deuda.numeroCuotasPagadas),
      montoCuota: Value(deuda.montoCuota),
      pagoMinimo: Value(deuda.pagoMinimo),
      periodicidadCuotas: Value(deuda.periodicidadCuotas?.name),
      interesTotal: Value(deuda.interesTotal),
      fechaInicio: deuda.fechaInicio,
      fechaVencimientoFinal: Value(deuda.fechaVencimientoFinal),
      diaPago: Value(deuda.diaPago),
      proximaFechaPago: Value(deuda.proximaFechaPago),
      enMora: Value(deuda.enMora),
      diasMora: Value(deuda.diasMora),
      tasaInteresMoratorio: Value(deuda.tasaInteresMoratorio),
      estado: deuda.estado.name,
      notas: Value(deuda.notas),
    );
  }
}
