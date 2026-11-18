import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';

void main() {
  late AppDatabase db;
  late CuentaRepositoryDrift cuentas;
  late CategoriaRepositoryDrift categorias;
  late TransaccionRepositoryDrift transacciones;
  late DeudaRepositoryDrift deudas;
  late PagoDeudaRepositoryDrift pagos;
  late SembrarDatosDemo sembrar;

  final ahora = DateTime(2026, 11, 16, 10);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cuentas = CuentaRepositoryDrift(db);
    categorias = CategoriaRepositoryDrift(db);
    transacciones = TransaccionRepositoryDrift(db);
    deudas = DeudaRepositoryDrift(db);
    pagos = PagoDeudaRepositoryDrift(db);
    sembrar = SembrarDatosDemo(
      cuentaRepository: cuentas,
      categoriaRepository: categorias,
      transaccionRepository: transacciones,
      deudaRepository: deudas,
      pagoDeudaRepository: pagos,
    );
  });

  tearDown(() => db.close());

  double suma(Iterable<Transaccion> txs) =>
      txs.fold(0.0, (total, t) => total + t.monto);

  test(
    'crea 3 cuentas con los saldos ya ajustados por los movimientos',
    () async {
      await sembrar(ahora: ahora);

      final todas = {for (final c in await cuentas.obtenerTodas()) c.nombre: c};
      // Fase 84: más la Visa BCP de ejemplo (crédito, TCEA 48 %).
      expect(
        todas.keys,
        unorderedEquals(['Efectivo', 'Débito BCP', 'Yape', 'Visa BCP']),
      );
      expect(todas['Visa BCP']!.saldoActual, -1200);
      expect(todas['Visa BCP']!.tcea, 0.48);
      expect(todas['Efectivo']!.saldoActual, 60);
      expect(todas['Débito BCP']!.saldoActual, 3160);
      expect(todas['Yape']!.saldoActual, 70);
    },
  );

  test(
    'sueldo de S/ 3,200 y S/ 2,560 de gastos en Comida/Transporte/Servicios',
    () async {
      await sembrar(ahora: ahora);

      // Fase 86: solo el mes de `ahora` (el historial va en otra prueba).
      final txs = (await transacciones.obtenerTodas())
          .where((t) => t.fecha.month == ahora.month)
          .toList();
      final ingresos = txs.where((t) => t.tipo == TipoTransaccion.ingreso);
      final gastos = txs.where((t) => t.tipo == TipoTransaccion.gasto);
      expect(suma(ingresos), 3200);
      expect(suma(gastos), 2560);

      final nombrePorId = {
        for (final c in await categorias.obtenerTodas()) c.id: c.nombre,
      };
      expect(gastos.map((t) => nombrePorId[t.categoriaId]).toSet(), {
        'Comida',
        'Transporte',
        'Servicios',
      });
      // Reutiliza las categorías predeterminadas que siembra Drift en vez de
      // crear duplicadas.
      expect(
        (await categorias.obtenerTodas()).where((c) => c.nombre == 'Comida'),
        hasLength(1),
      );
      // Todo cae en el mes de `ahora` y nunca en el futuro.
      for (final t in txs) {
        expect(t.fecha.year, 2026);
        expect(t.fecha.month, 11);
        expect(t.fecha.isAfter(ahora.add(const Duration(days: 1))), isFalse);
      }
    },
  );

  test('a inicios de mes ninguna transacción queda con fecha futura', () async {
    final dia3 = DateTime(2026, 11, 3, 9);
    await sembrar(ahora: dia3);

    for (final t in await transacciones.obtenerTodas()) {
      // Fase 86: el historial cae en meses anteriores, siempre en el pasado.
      if (t.fecha.month != dia3.month) {
        expect(t.fecha.isBefore(DateTime(2026, 11)), isTrue);
        continue;
      }
      expect(t.fecha.day, lessThanOrEqualTo(3));
    }
  });

  test('Fase 86: historial de 3 meses completos (uno de ingreso bajo) que '
      'no cambia los saldos', () async {
    await sembrar(ahora: ahora);
    final historial = (await transacciones.obtenerTodas())
        .where((t) => t.fecha.isBefore(DateTime(2026, 11)))
        .toList();
    double total(int mes, TipoTransaccion tipo) => suma(
      historial.where((t) => t.fecha.month == mes && t.tipo == tipo),
    );
    expect(total(10, TipoTransaccion.ingreso), 3800);
    expect(total(9, TipoTransaccion.ingreso), 3200);
    expect(total(8, TipoTransaccion.ingreso), 3600);
    expect(total(10, TipoTransaccion.gasto), 1850);
    expect(total(9, TipoTransaccion.gasto), 1750);
    expect(total(8, TipoTransaccion.gasto), 1900);
    expect(historial, hasLength(14));
    // Los saldos siguen siendo los de siempre (el historial ya está en el
    // saldo de apertura).
    final todas = {for (final c in await cuentas.obtenerTodas()) c.nombre: c};
    expect(todas['Débito BCP']!.saldoActual, 3160);
    // Idempotente también con el historial.
    expect((await sembrar(ahora: ahora)).yaEstabaCargado, isTrue);
  });

  test(
    'préstamo personal: 10 cuotas de S/ 440, 8 pagadas, próxima a futuro',
    () async {
      await sembrar(ahora: ahora);

      final prestamo = (await deudas.obtenerPorId(
        SembrarDatosDemo.idDeudaPrestamo,
      ))!;
      expect(prestamo.estructuraPago, EstructuraPago.cuotasFijas);
      expect(prestamo.montoCuota, 440);
      expect(prestamo.numeroCuotasTotal, 10);
      expect(prestamo.numeroCuotasPagadas, 8);
      expect(prestamo.montoTotal, 3800);
      expect(prestamo.montoPagado, 3520);
      expect(prestamo.interesTotal, 600);
      expect(saldoPendiente(prestamo), 880);
      expect(prestamo.periodicidadCuotas, PeriodicidadCuota.mensual);
      expect(prestamo.estado, EstadoDeuda.activa);
      expect(prestamo.proximaFechaPago, DateTime(2026, 11, 20));
      expect(prestamo.fechaVencimientoFinal, DateTime(2026, 12, 20));

      final pagosPrestamo = await pagos.obtenerPorDeuda(prestamo.id);
      expect(pagosPrestamo, hasLength(8));
      expect(pagosPrestamo.map((p) => p.numeroCuota).toSet(), {
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      });
      for (final p in pagosPrestamo) {
        expect(p.montoCapital, 380);
        expect(p.montoInteres, 60);
        expect(p.cuentaId, isNull);
      }
    },
  );

  test(
    'laptop en cuotas (12 × S/ 210, 3 pagadas) y deuda informal de pago libre',
    () async {
      await sembrar(ahora: ahora);

      final laptop = (await deudas.obtenerPorId(
        SembrarDatosDemo.idDeudaLaptop,
      ))!;
      expect(laptop.tipoDeuda, TipoDeuda.compraCuotas);
      expect(laptop.montoCuota, 210);
      expect(laptop.numeroCuotasTotal, 12);
      expect(laptop.numeroCuotasPagadas, 3);
      expect(laptop.montoTotal, 2000);
      expect(laptop.interesTotal, 520);
      expect(laptop.tieneInteres, isTrue);
      expect(saldoPendiente(laptop), 1890);
      expect(laptop.proximaFechaPago, DateTime(2026, 12, 5));
      expect(await pagos.obtenerPorDeuda(laptop.id), hasLength(3));

      final informal = (await deudas.obtenerPorId(
        SembrarDatosDemo.idDeudaInformal,
      ))!;
      expect(informal.tipoDeuda, TipoDeuda.deudaInformal);
      expect(informal.estructuraPago, EstructuraPago.pagoLibre);
      expect(informal.montoTotal, 250);
      expect(informal.montoPagado, 100);
      expect(saldoPendiente(informal), 150);
      final pagosInformal = await pagos.obtenerPorDeuda(informal.id);
      expect(pagosInformal.fold(0.0, (t, p) => t + p.montoPagado), 100);
    },
  );

  test(
    'es idempotente: la segunda corrida no crea nada ni mueve saldos',
    () async {
      final primera = await sembrar(ahora: ahora);
      expect(primera.yaEstabaCargado, isFalse);

      final cuentasAntes = await cuentas.obtenerTodas();
      final txAntes = await transacciones.obtenerTodas();
      final deudasAntes = await deudas.obtenerTodas();

      final segunda = await sembrar(ahora: ahora);
      expect(segunda.registrosCreados, 0);
      expect(segunda.yaEstabaCargado, isTrue);

      expect(await transacciones.obtenerTodas(), hasLength(txAntes.length));
      expect(await deudas.obtenerTodas(), hasLength(deudasAntes.length));
      final saldosDespues = {
        for (final c in await cuentas.obtenerTodas()) c.id: c.saldoActual,
      };
      for (final c in cuentasAntes) {
        expect(saldosDespues[c.id], c.saldoActual);
      }
      expect(
        await pagos.obtenerPorDeuda(SembrarDatosDemo.idDeudaPrestamo),
        hasLength(8),
      );
    },
  );

  test(
    'completa solo lo que falta si una corrida anterior quedó a medias',
    () async {
      await sembrar(ahora: ahora);
      final pagoBorrado = (await pagos.obtenerPorDeuda(
        SembrarDatosDemo.idDeudaLaptop,
      )).first;
      await pagos.eliminar(pagoBorrado.id);

      final resultado = await sembrar(ahora: ahora);

      expect(resultado.registrosCreados, 1);
      expect(
        await pagos.obtenerPorDeuda(SembrarDatosDemo.idDeudaLaptop),
        hasLength(3),
      );
    },
  );

  test('los ids son UUID válidos (migrables a columnas uuid de Postgres)', () {
    final regexUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(SembrarDatosDemo.idCuentaEfectivo, matches(regexUuid));
    expect(SembrarDatosDemo.idDeudaPrestamo, matches(regexUuid));
    expect(
      SembrarDatosDemo.idDemo('x'),
      SembrarDatosDemo.idDemo('x'),
      reason: 'deterministas',
    );
  });
}
