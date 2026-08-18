import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';

part 'app_database.g.dart';

@DataClassName('CuentaRow')
class Cuentas extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();
  TextColumn get tipo => text()();
  TextColumn get moneda => text()();
  RealColumn get saldoActual => real()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('CategoriaRow')
class Categorias extends Table {
  TextColumn get id => text()();
  TextColumn get nombre => text()();
  TextColumn get tipo => text()();
  TextColumn get iconName => text()();
  BoolColumn get esPredeterminada =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('TransaccionRow')
class Transacciones extends Table {
  TextColumn get id => text()();
  TextColumn get cuentaId => text()();
  TextColumn get categoriaId => text()();
  RealColumn get monto => real()();
  TextColumn get moneda => text()();
  TextColumn get tipo => text()();
  TextColumn get concepto => text()();
  TextColumn get metodoPago => text()();
  BoolColumn get esRecurrente => boolean().withDefault(const Constant(false))();
  TextColumn get comprobanteUrl => text().nullable()();
  TextColumn get fuenteCaptura => text()();
  TextColumn get dataRaw => text().nullable()();
  DateTimeColumn get fecha => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DeudaRow')
class Deudas extends Table {
  TextColumn get id => text()();
  TextColumn get nombreDeuda => text()();
  TextColumn get tipoDeuda => text()();
  TextColumn get tipoAcreedor => text()();
  TextColumn get nombreAcreedor => text()();
  TextColumn get moneda => text()();
  RealColumn get montoTotal => real()();
  RealColumn get montoPagado => real()();
  BoolColumn get tieneInteres => boolean()();
  RealColumn get tasaInteres => real().nullable()();
  TextColumn get tipoTasa => text().nullable()();
  TextColumn get estructuraPago => text()();
  IntColumn get numeroCuotasTotal => integer().nullable()();
  IntColumn get numeroCuotasPagadas => integer().nullable()();
  RealColumn get montoCuota => real().nullable()();
  RealColumn get pagoMinimo => real().nullable()();
  TextColumn get periodicidadCuotas => text().nullable()();
  RealColumn get interesTotal => real().nullable()();
  DateTimeColumn get fechaInicio => dateTime()();
  DateTimeColumn get fechaVencimientoFinal => dateTime().nullable()();
  IntColumn get diaPago => integer().nullable()();
  DateTimeColumn get proximaFechaPago => dateTime().nullable()();
  BoolColumn get enMora => boolean().withDefault(const Constant(false))();
  IntColumn get diasMora => integer().nullable()();
  RealColumn get tasaInteresMoratorio => real().nullable()();
  TextColumn get estado => text()();
  TextColumn get notas => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PagoDeudaRow')
class PagosDeuda extends Table {
  TextColumn get id => text()();
  TextColumn get deudaId => text()();
  TextColumn get cuentaId => text().nullable()();
  RealColumn get montoPagado => real()();
  RealColumn get montoCapital => real().nullable()();
  RealColumn get montoInteres => real().nullable()();
  DateTimeColumn get fechaPago => dateTime()();
  IntColumn get numeroCuota => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Cuentas, Categorias, Transacciones, Deudas, PagosDeuda])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCategoriasDefault(this);
      await _seedCategoriasAjuste(this);
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(deudas, deudas.notas);
      }
      if (from < 3) {
        await m.addColumn(deudas, deudas.periodicidadCuotas);
        await m.addColumn(deudas, deudas.interesTotal);
        // `cuentaId` pasa a ser nullable (pagos retroactivos sin cuenta
        // asociada) — requiere recrear la tabla en SQLite.
        await m.alterTable(TableMigration(pagosDeuda));
        await asignarPeriodicidadMensualLegacy();
      }
      if (from < 5) {
        // Debe ejecutarse antes del bloque `from < 4` de abajo: agrega la
        // columna que `_seedCategoriasAjuste` necesita poder escribir si
        // esta instalación viene de antes de la Fase 16 (from < 4).
        await m.addColumn(categorias, categorias.esPredeterminada);
      }
      if (from < 4) {
        // Categorías nuevas para `AjustarSaldoCuenta` (Fase 16) — las
        // instalaciones existentes no las tienen porque `_seedCategoriasDefault`
        // solo corre en `onCreate`.
        await _seedCategoriasAjuste(this);
      }
      if (from < 5) {
        // Categorías propias del usuario (Fase 20): toda categoría que ya
        // existía en una instalación anterior a esta fase fue sembrada por
        // la app (`_seedCategoriasDefault`/`_seedCategoriasAjuste`), nunca
        // creada por el usuario — no existía otra forma de crear una.
        await update(
          categorias,
        ).write(const CategoriasCompanion(esPredeterminada: Value(true)));
      }
    },
  );

  /// Asunción explícita de la migración a schemaVersion 3: las deudas
  /// `cuotasFijas` existentes no tenían periodicidad, se asume `mensual`.
  /// No recalcula `fechaVencimientoFinal` — se deriva dinámicamente del
  /// cronograma cada vez que se lee la deuda. Extraído como método propio
  /// (en vez de código inline en `onUpgrade`) para poder probarlo de forma
  /// aislada.
  Future<void> asignarPeriodicidadMensualLegacy() async {
    await (update(deudas)..where(
          (t) =>
              t.estructuraPago.equals('cuotasFijas') &
              t.periodicidadCuotas.isNull(),
        ))
        .write(const DeudasCompanion(periodicidadCuotas: Value('mensual')));
  }

  /// Borra los datos financieros locales tras una migración exitosa a
  /// Supabase (Fase 21) — `MigrarDatosScreen` la llama solo después de que
  /// `MigrarDatosALaNube` termina sin errores y verifica los conteos.
  /// Orden de borrado por dependencias (hijos antes que padres): las
  /// categorías predeterminadas se dejan (ya no se usan, pero borrarlas no
  /// es necesario y así se documenta explícitamente qué se conserva).
  Future<void> limpiarTrasMigracion() async {
    await delete(transacciones).go();
    await delete(pagosDeuda).go();
    await delete(deudas).go();
    await delete(cuentas).go();
    await (delete(
      categorias,
    )..where((c) => c.esPredeterminada.equals(false))).go();
  }
}

Future<void> _seedCategoriasDefault(AppDatabase db) async {
  const uuid = Uuid();
  const gastos = <String, String>{
    'Comida': 'restaurant',
    'Transporte': 'directions_bus',
    'Salud': 'health_and_safety',
    'Entretenimiento': 'movie',
    'Servicios': 'bolt',
    'Educación': 'school',
    'Hogar': 'home',
    'Otros gastos': 'category',
  };
  const ingresos = <String, String>{
    'Sueldo': 'payments',
    'Freelance': 'work',
    'Otros ingresos': 'attach_money',
  };

  await db.batch((batch) {
    batch.insertAll(db.categorias, [
      for (final entry in gastos.entries)
        CategoriasCompanion.insert(
          id: uuid.v4(),
          nombre: entry.key,
          tipo: 'gasto',
          iconName: entry.value,
          esPredeterminada: const Value(true),
        ),
      for (final entry in ingresos.entries)
        CategoriasCompanion.insert(
          id: uuid.v4(),
          nombre: entry.key,
          tipo: 'ingreso',
          iconName: entry.value,
          esPredeterminada: const Value(true),
        ),
    ]);
  });
}

/// Categorías usadas por `AjustarSaldoCuenta` (Fase 16) para registrar la
/// diferencia entre el saldo calculado y el saldo real como una transacción
/// más, en vez de sobrescribir `saldoActual` directamente.
Future<void> _seedCategoriasAjuste(AppDatabase db) async {
  const uuid = Uuid();
  await db.batch((batch) {
    batch.insertAll(db.categorias, [
      CategoriasCompanion.insert(
        id: uuid.v4(),
        nombre: 'Ajuste de saldo',
        tipo: 'ingreso',
        iconName: 'tune',
        esPredeterminada: const Value(true),
      ),
      CategoriasCompanion.insert(
        id: uuid.v4(),
        nombre: 'Ajuste de saldo',
        tipo: 'gasto',
        iconName: 'tune',
        esPredeterminada: const Value(true),
      ),
    ]);
  });
}

QueryExecutor _openConnection() {
  return driftDatabase(name: 'finanzas_automaticas');
}
