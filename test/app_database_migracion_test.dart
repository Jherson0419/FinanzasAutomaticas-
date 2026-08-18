import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';

void main() {
  test(
    'asignarPeriodicidadMensualLegacy asigna "mensual" solo a deudas cuotasFijas sin periodicidad',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.deudas)
          .insert(
            DeudasCompanion.insert(
              id: 'd1',
              nombreDeuda: 'Préstamo legacy',
              tipoDeuda: 'prestamoPersonal',
              tipoAcreedor: 'entidadFinanciera',
              nombreAcreedor: 'BCP',
              moneda: 'pen',
              montoTotal: 1000,
              montoPagado: 0,
              tieneInteres: false,
              estructuraPago: 'cuotasFijas',
              fechaInicio: DateTime(2026, 1, 1),
              estado: 'activa',
            ),
          );
      await db
          .into(db.deudas)
          .insert(
            DeudasCompanion.insert(
              id: 'd2',
              nombreDeuda: 'Tarjeta',
              tipoDeuda: 'tarjetaCredito',
              tipoAcreedor: 'entidadFinanciera',
              nombreAcreedor: 'BBVA',
              moneda: 'pen',
              montoTotal: 500,
              montoPagado: 0,
              tieneInteres: false,
              estructuraPago: 'pagoLibre',
              fechaInicio: DateTime(2026, 1, 1),
              estado: 'activa',
            ),
          );

      await db.asignarPeriodicidadMensualLegacy();

      final d1 = await (db.select(
        db.deudas,
      )..where((t) => t.id.equals('d1'))).getSingle();
      final d2 = await (db.select(
        db.deudas,
      )..where((t) => t.id.equals('d2'))).getSingle();

      expect(d1.periodicidadCuotas, 'mensual');
      expect(d2.periodicidadCuotas, isNull);
    },
  );
}
