import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_gasto.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_ingreso.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';

/// Tests de integración real: contra `AppDatabase` en memoria (Drift real,
/// sin repositorios fake), para distinguir un bug de escritura real en la
/// base de datos de un bug de refresco de UI (que un test con fakes no
/// puede detectar, porque los fakes no pasan por Drift).
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test(
    'RegistrarIngreso persiste el nuevo saldoActual en la base de datos real',
    () async {
      final cuentaRepo = CuentaRepositoryDrift(db);
      final transaccionRepo = TransaccionRepositoryDrift(db);

      await cuentaRepo.crear(
        const Cuenta(
          id: 'cta-1',
          nombre: 'BCP Cuenta sueldo',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
      );

      final registrarIngreso = RegistrarIngreso(
        cuentaRepository: cuentaRepo,
        transaccionRepository: transaccionRepo,
      );
      await registrarIngreso(
        cuentaId: 'cta-1',
        categoriaId: 'cat-sueldo',
        monto: 500,
        moneda: Moneda.pen,
        concepto: 'Sueldo',
        metodoPago: MetodoPago.transferencia,
      );

      // Releída con una instancia nueva de repositorio, no el mismo objeto
      // en memoria — para verificar que quedó realmente en la BD.
      final cuentaReleida = await CuentaRepositoryDrift(
        db,
      ).obtenerPorId('cta-1');

      expect(cuentaReleida, isNotNull);
      expect(cuentaReleida!.saldoActual, 1500);
    },
  );

  test(
    'EliminarTransaccion revierte el saldoActual a su valor previo en la base de datos real',
    () async {
      final cuentaRepo = CuentaRepositoryDrift(db);
      final transaccionRepo = TransaccionRepositoryDrift(db);

      await cuentaRepo.crear(
        const Cuenta(
          id: 'cta-2',
          nombre: 'BCP Cuenta sueldo',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
      );

      final registrarGasto = RegistrarGasto(
        cuentaRepository: cuentaRepo,
        transaccionRepository: transaccionRepo,
      );
      final gasto = await registrarGasto(
        cuentaId: 'cta-2',
        categoriaId: 'cat-comida',
        monto: 200,
        moneda: Moneda.pen,
        concepto: 'Supermercado',
        metodoPago: MetodoPago.tarjeta,
      );

      final cuentaTrasGasto = await CuentaRepositoryDrift(
        db,
      ).obtenerPorId('cta-2');
      expect(cuentaTrasGasto!.saldoActual, 800);

      final eliminarTransaccion = EliminarTransaccion(
        transaccionRepository: transaccionRepo,
        cuentaRepository: cuentaRepo,
      );
      await eliminarTransaccion(transaccionId: gasto.id);

      final cuentaTrasEliminar = await CuentaRepositoryDrift(
        db,
      ).obtenerPorId('cta-2');
      expect(cuentaTrasEliminar!.saldoActual, 1000);
    },
  );

  test(
    'EditarTransaccion ajusta el saldoActual al nuevo monto en la base de datos real',
    () async {
      final cuentaRepo = CuentaRepositoryDrift(db);
      final transaccionRepo = TransaccionRepositoryDrift(db);

      await cuentaRepo.crear(
        const Cuenta(
          id: 'cta-3',
          nombre: 'BCP Cuenta sueldo',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
      );

      final registrarGasto = RegistrarGasto(
        cuentaRepository: cuentaRepo,
        transaccionRepository: transaccionRepo,
      );
      final gasto = await registrarGasto(
        cuentaId: 'cta-3',
        categoriaId: 'cat-comida',
        monto: 200,
        moneda: Moneda.pen,
        concepto: 'Supermercado',
        metodoPago: MetodoPago.tarjeta,
      );

      final editarTransaccion = EditarTransaccion(
        transaccionRepository: transaccionRepo,
        cuentaRepository: cuentaRepo,
      );
      await editarTransaccion(
        transaccionId: gasto.id,
        cuentaId: 'cta-3',
        categoriaId: 'cat-comida',
        monto: 350,
        moneda: Moneda.pen,
        tipo: TipoTransaccion.gasto,
        concepto: 'Supermercado (corregido)',
        metodoPago: MetodoPago.tarjeta,
      );

      final cuentaTrasEditar = await CuentaRepositoryDrift(
        db,
      ).obtenerPorId('cta-3');
      // 1000 - 200 (gasto original) + 200 (revertido) - 350 (nuevo monto) = 650
      expect(cuentaTrasEditar!.saldoActual, 650);
    },
  );

  test(
    'RegistrarPagoDeuda (no retroactivo) descuenta el saldoActual en la base de datos real',
    () async {
      final cuentaRepo = CuentaRepositoryDrift(db);
      final deudaRepo = DeudaRepositoryDrift(db);
      final pagoDeudaRepo = PagoDeudaRepositoryDrift(db);

      await cuentaRepo.crear(
        const Cuenta(
          id: 'cta-4',
          nombre: 'BCP Cuenta sueldo',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
      );

      final registrarDeuda = RegistrarDeuda(deudaRepository: deudaRepo);
      final deuda = await registrarDeuda(
        nombreDeuda: 'Tarjeta de crédito',
        tipoDeuda: TipoDeuda.tarjetaCredito,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BBVA',
        moneda: Moneda.pen,
        montoTotal: 500,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
      );

      final registrarPagoDeuda = RegistrarPagoDeuda(
        pagoDeudaRepository: pagoDeudaRepo,
        deudaRepository: deudaRepo,
        cuentaRepository: cuentaRepo,
      );
      await registrarPagoDeuda(
        deudaId: deuda.id,
        cuentaId: 'cta-4',
        montoPagado: 300,
      );

      final cuentaTrasPago = await CuentaRepositoryDrift(
        db,
      ).obtenerPorId('cta-4');
      expect(cuentaTrasPago!.saldoActual, 700);
    },
  );
}
