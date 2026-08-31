import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';

void main() {
  test(
    'Fase 68: obtenerDeudasDondeSoyElAmigo siempre devuelve vacío, aunque '
    'haya deudas locales — el almacenamiento local nunca ve filas de otro '
    'usuario',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DeudaRepositoryDrift(db);

      await repo.crear(
        Deuda(
          id: 'd1',
          nombreDeuda: 'Préstamo',
          tipoDeuda: TipoDeuda.deudaInformal,
          tipoAcreedor: TipoAcreedor.personaNatural,
          nombreAcreedor: 'jherson23',
          moneda: Moneda.pen,
          montoTotal: 100,
          montoPagado: 0,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
          amigoUsuarioId: 'user-amigo',
        ),
      );

      expect(await repo.obtenerDeudasDondeSoyElAmigo(), isEmpty);
    },
  );
}
