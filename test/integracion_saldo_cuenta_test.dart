import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_gasto.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_ingreso.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/domain/entities/amistad.dart';

/// `AmistadRepository` no tiene adapter Drift (Fase 63/64, ver `CONTEXTO.md`
/// — solo Supabase, como `AutomatizacionRepository`): un fake mínimo basta
/// aquí, `RegistrarPagoDeuda` solo lo usa para notificar a un amigo, algo
/// ajeno a lo que este archivo verifica (persistencia real de saldos).
class _FakeAmistadRepository implements AmistadRepository {
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}

  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async =>
      throw UnimplementedError();
  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async =>
      throw UnimplementedError();
  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      throw UnimplementedError();
  @override
  Future<List<PerfilPublico>> obtenerAmigos() async =>
      throw UnimplementedError();
  @override
  Future<void> aceptarSolicitud(String solicitudId) async =>
      throw UnimplementedError();
  @override
  Future<void> rechazarSolicitud(String solicitudId) async =>
      throw UnimplementedError();
}

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
        deudaRepository: DeudaRepositoryDrift(db),
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
        deudaRepository: DeudaRepositoryDrift(db),
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
        deudaRepository: DeudaRepositoryDrift(db),
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
        deudaRepository: DeudaRepositoryDrift(db),
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
        deudaRepository: DeudaRepositoryDrift(db),
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
        amistadRepository: _FakeAmistadRepository(),
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

  test(
    'Fase 62: un gasto sobre una tarjeta de crédito recién creada '
    'actualiza montoPagado de su Deuda vinculada en la base de datos real',
    () async {
      final cuentaRepo = CuentaRepositoryDrift(db);
      final transaccionRepo = TransaccionRepositoryDrift(db);
      final deudaRepo = DeudaRepositoryDrift(db);

      final registrarCuenta = RegistrarCuenta(
        cuentaRepository: cuentaRepo,
        deudaRepository: deudaRepo,
      );
      final tarjeta = await registrarCuenta(
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        lineaCredito: 2000,
        fechaCorte: DateTime(2026, 1, 10),
        fechaPago: DateTime(2026, 1, 20),
      );

      final deudasIniciales = await deudaRepo.obtenerTodas();
      expect(deudasIniciales, hasLength(1));
      expect(deudasIniciales.single.cuentaId, tarjeta.id);
      expect(deudasIniciales.single.montoPagado, 2000);

      final registrarGasto = RegistrarGasto(
        cuentaRepository: cuentaRepo,
        transaccionRepository: transaccionRepo,
        deudaRepository: deudaRepo,
      );
      await registrarGasto(
        cuentaId: tarjeta.id,
        categoriaId: 'cat-compras',
        monto: 800,
        moneda: Moneda.pen,
        concepto: 'Compra online',
        metodoPago: MetodoPago.tarjeta,
      );

      final deudaTrasGasto = (await deudaRepo.obtenerTodas()).single;
      expect(deudaTrasGasto.montoTotal, 2000);
      expect(deudaTrasGasto.montoPagado, 1200);
      expect(deudaTrasGasto.montoTotal - deudaTrasGasto.montoPagado, 800);
    },
  );
}
