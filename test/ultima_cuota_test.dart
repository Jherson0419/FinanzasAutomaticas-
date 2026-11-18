import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/abono_capital.dart';
import 'package:finanzas_automaticas/domain/cronograma_cuotas.dart';
import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_adelanto_cuotas.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';

/// Fase 84b (B) — un abono que no libera una cuota entera baja la ÚLTIMA.
///
/// Script Python independiente (Decimal con 50 dígitos; tasa por bisección
/// sobre la suma de valores presentes; amortización período a período, sin
/// fórmulas cerradas). Préstamo S/ 10,000, 36 cuotas de S/ 450, 12 pagadas:
///
///   i = 0.028818655066628278840022518435346566545892920692950
///   capital antes = 7718.8903818616941181932902975122717108503743582201
///   saldo sin abono = 10800
///   abono 3000: completas=12 F=300.6941838124 n'=25 total=14100.6942
///               saldo=5700.6941838124
///   abono 200:  completas=23 F=54.4859390909 n'=36 total=16004.4859
///               saldo=10404.4859390909
///   B: baja de saldo = 395.5140609091326…  baja última cuota = 395.5140…
///      200 × (1+i)^24 = 395.5140609091326…
///   sin tasa abono 3000: completas=17 F=150 n'=30
class _SinAmigos implements AmistadRepository {
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}
  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;
  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {}
  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      const [];
  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => const [];
  @override
  Future<void> aceptarSolicitud(String solicitudId) async {}
  @override
  Future<void> rechazarSolicitud(String solicitudId) async {}
}

const _fA = 300.6941838124;
const _fB = 54.4859390909;
const _bajaB = 395.5140609091326;

Deuda _credito({double montoTotal = 10000}) => Deuda(
  id: 'auto',
  nombreDeuda: 'Crédito auto',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: montoTotal,
  montoPagado: 5400,
  tieneInteres: true,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: 36,
  numeroCuotasPagadas: 12,
  montoCuota: 450,
  periodicidadCuotas: PeriodicidadCuota.mensual,
  fechaInicio: DateTime(2026, 1, 15),
  proximaFechaPago: DateTime(2027, 1, 15),
  enMora: false,
  estado: EstadoDeuda.activa,
);

void main() {
  late AppDatabase db;
  late DeudaRepositoryDrift deudas;
  late PagoDeudaRepositoryDrift pagos;
  late CuentaRepositoryDrift cuentas;
  late RegistrarPagoDeuda registrar;

  Future<void> sembrar(Deuda deuda) async {
    await deudas.crear(deuda);
    for (var n = 1; n <= (deuda.numeroCuotasPagadas ?? 0); n++) {
      await pagos.crear(
        PagoDeuda(
          id: 'c$n',
          deudaId: deuda.id,
          montoPagado: 450,
          fechaPago: sumarMeses(deuda.fechaInicio, n - 1),
          numeroCuota: n,
        ),
      );
    }
  }

  Future<Deuda> abonar(
    double monto, {
    int? cuotasBanco,
    double? ultimaBanco,
  }) async {
    await registrar(
      deudaId: 'auto',
      montoPagado: monto,
      tipo: TipoPagoDeuda.abonoCapital,
      cuotasRestantesSegunBanco: cuotasBanco,
      montoUltimaCuotaSegunBanco: ultimaBanco,
    );
    return (await deudas.obtenerPorId('auto'))!;
  }

  /// Invariantes: saldo ≥ 0; saldo = suma de las cuotas pendientes del
  /// cronograma; el cronograma (más lo abonado) suma el total a pagar.
  Future<void> verificarInvariantes(Deuda d) async {
    final crono = generarCronogramaCuotas(
      d,
      await pagos.obtenerPorDeuda(d.id),
    );
    final pendiente = crono
        .where((c) => !c.pagada)
        .fold<double>(0, (s, c) => s + c.montoEsperado);
    final todas = crono.fold<double>(0, (s, c) => s + c.montoEsperado);
    expect(saldoPendiente(d), greaterThanOrEqualTo(0));
    expect(saldoPendiente(d), closeTo(pendiente, 1e-6));
    expect(todas + d.montoAbonadoCapital, closeTo(totalAPagar(d), 1e-6));
    expect(crono, hasLength(d.numeroCuotasTotal!));
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deudas = DeudaRepositoryDrift(db);
    pagos = PagoDeudaRepositoryDrift(db);
    cuentas = CuentaRepositoryDrift(db);
    registrar = RegistrarPagoDeuda(
      pagoDeudaRepository: pagos,
      deudaRepository: deudas,
      cuentaRepository: cuentas,
      amistadRepository: _SinAmigos(),
    );
    await cuentas.crear(
      const Cuenta(
        id: 'bcp',
        nombre: 'Débito BCP',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 20000,
      ),
    );
  });
  tearDown(() => db.close());

  group('simularCuotasRestantes (puro)', () {
    test('sin tasa: F = C − cuota × floor(C / cuota); residuo 0 → sin '
        'parcial', () {
      final a = simularCuotasRestantes(
        capital: 7800,
        cuota: 450,
        i: 0,
        maxCuotas: 24,
      )!;
      expect((a.completas, a.ultima, a.total), (17, 150.0, 18));
      final b = simularCuotasRestantes(
        capital: 4500,
        cuota: 450,
        i: 0,
        maxCuotas: 24,
      )!;
      expect((b.completas, b.ultima, b.total), (10, null, 10));
    });

    test('F < 0.01 → sin parcial; capital ≤ 0 → 0 cuotas; no termina → '
        'null', () {
      final casiExacto = simularCuotasRestantes(
        capital: 900.004,
        cuota: 450,
        i: 0,
        maxCuotas: 5,
      )!;
      expect((casiExacto.completas, casiExacto.ultima), (2, null));
      expect(
        simularCuotasRestantes(capital: 0, cuota: 450, i: 0.02, maxCuotas: 5)!
            .total,
        0,
      );
      expect(
        simularCuotasRestantes(capital: 1e6, cuota: 10, i: 0.02, maxCuotas: 9),
        isNull,
      );
    });
  });

  group('Caso A — abono de S/ 3,000', () {
    test('estimación pura: 12 completas + última de S/ 300.69', () {
      final e = estimarAbonoCapital(_credito(), 3000)!;
      expect(e.cuotasRestantesDespues, 13);
      expect(e.ultimaCuotaDespues, closeTo(_fA, 1e-6));
      expect(e.ultimaCuotaAntes, 450);
    });

    test('registrado: n\' = 25, F guardada, saldo 5,700.69, invariantes',
        () async {
      await sembrar(_credito());
      final d = await abonar(3000);
      expect(d.numeroCuotasTotal, 25);
      expect(d.montoUltimaCuota, closeTo(_fA, 1e-6));
      expect(saldoPendiente(d), closeTo(5700.6941838124, 1e-6));
      expect(totalAPagar(d), closeTo(14100.6941838124, 1e-6));
      await verificarInvariantes(d);
      final crono = generarCronogramaCuotas(
        d,
        await pagos.obtenerPorDeuda('auto'),
      );
      expect(crono.last.numero, 25);
      expect(crono.last.montoEsperado, closeTo(_fA, 1e-6));
      expect(crono[23].montoEsperado, 450);
    });

    test('pagar las 13 restantes (la última por F) salda la deuda',
        () async {
      await sembrar(_credito());
      await abonar(3000);
      for (var n = 13; n <= 25; n++) {
        final d = (await deudas.obtenerPorId('auto'))!;
        expect(d.estado, EstadoDeuda.activa, reason: 'antes de la cuota $n');
        await registrar(
          deudaId: 'auto',
          cuentaId: 'bcp',
          montoPagado: montoDeCuota(d, n)!,
          numeroCuota: n,
        );
      }
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.estado, EstadoDeuda.pagada);
      expect(saldoPendiente(d), closeTo(0, 0.01));
      expect(d.proximaFechaPago, isNull);
      expect(
        (await cuentas.obtenerPorId('bcp'))!.saldoActual,
        closeTo(20000 - 450 * 12 - _fA, 1e-6),
      );
    });
  });

  group('Caso B — abono de S/ 200 (no libera una cuota)', () {
    test('n\' igual, última cuota ≈ 54.49 (baja 200 × (1+i)^24 ≈ 395.51), '
        'saldo 395.51 menor', () async {
      await sembrar(_credito());
      final antes = (await deudas.obtenerPorId('auto'))!;
      final saldoAntes = saldoPendiente(antes);
      final d = await abonar(200);
      expect(d.numeroCuotasTotal, 36);
      expect(d.montoUltimaCuota, closeTo(_fB, 1e-6));
      expect(450 - d.montoUltimaCuota!, closeTo(_bajaB, 1e-6));
      expect(saldoAntes - saldoPendiente(d), closeTo(_bajaB, 1e-6));
      expect(saldoPendiente(d), closeTo(10404.4859390909, 1e-6));
      await verificarInvariantes(d);
    });

    test('un segundo abono parte de la última cuota parcial', () async {
      await sembrar(_credito());
      final tras1 = await abonar(200);
      final capital1 = capitalPendiente(tras1);
      // El capital que ve el plan es el de antes menos 200.
      expect(capital1, closeTo(7718.890381861695 - 200, 1e-6));
      final d = await abonar(100);
      // Equivale a un solo abono de 300 (misma tasa congelada).
      final unico = estimarAbonoCapital(_credito(), 300)!;
      expect(d.numeroCuotasTotal, 12 + unico.cuotasRestantesDespues);
      expect(d.montoUltimaCuota, closeTo(unico.ultimaCuotaDespues!, 1e-6));
      await verificarInvariantes(d);
    });
  });

  group('Sin tasa (0 %)', () {
    test('abono 3000 → 17 completas + última de 150', () async {
      await sembrar(_credito(montoTotal: 450.0 * 36));
      final d = await abonar(3000);
      expect(d.numeroCuotasTotal, 30);
      expect(d.montoUltimaCuota, closeTo(150, 1e-9));
      expect(saldoPendiente(d), closeTo(7800, 1e-9));
      await verificarInvariantes(d);
    });

    test('abono múltiplo de la cuota → sin parcial', () async {
      await sembrar(_credito(montoTotal: 450.0 * 36));
      final d = await abonar(900);
      expect(d.numeroCuotasTotal, 34);
      expect(d.montoUltimaCuota, isNull);
      expect(saldoPendiente(d), closeTo(450.0 * 22, 1e-9));
      await verificarInvariantes(d);
    });
  });

  group('Lo que dice el banco manda', () {
    test('solo la última cuota: manda sobre F', () async {
      await sembrar(_credito());
      final d = await abonar(3000, ultimaBanco: 280);
      expect(d.numeroCuotasTotal, 25);
      expect(d.montoUltimaCuota, 280);
      expect(saldoPendiente(d), closeTo(450.0 * 12 + 280, 1e-9));
      await verificarInvariantes(d);
    });

    test('cuotas y última: mandan las dos', () async {
      await sembrar(_credito());
      final d = await abonar(3000, cuotasBanco: 14, ultimaBanco: 120);
      expect(d.numeroCuotasTotal, 26);
      expect(d.montoUltimaCuota, 120);
      await verificarInvariantes(d);
    });

    test('mismas cuotas que la estimación, sin última → se usa F estimada',
        () async {
      await sembrar(_credito());
      final d = await abonar(3000, cuotasBanco: 13);
      expect(d.montoUltimaCuota, closeTo(_fA, 1e-6));
    });

    test('última igual a la cuota → sin parcial (null)', () async {
      await sembrar(_credito());
      final d = await abonar(3000, ultimaBanco: 450);
      expect(d.montoUltimaCuota, isNull);
      expect(saldoPendiente(d), 450.0 * 13);
    });

    test('rechazos: F ≤ 0, F > cuota, F con 0 cuotas, F en un pago normal',
        () async {
      await sembrar(_credito());
      await expectLater(abonar(3000, ultimaBanco: 0), throwsArgumentError);
      await expectLater(abonar(3000, ultimaBanco: 451), throwsArgumentError);
      await expectLater(
        abonar(3000, cuotasBanco: 0, ultimaBanco: 100),
        throwsArgumentError,
      );
      await expectLater(
        registrar(
          deudaId: 'auto',
          montoPagado: 450,
          numeroCuota: 13,
          montoUltimaCuotaSegunBanco: 100,
        ),
        throwsArgumentError,
      );
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.montoAbonadoCapital, 0);
      expect(d.montoUltimaCuota, isNull);
      expect(await pagos.obtenerPorDeuda('auto'), hasLength(12));
    });
  });

  test('un abono que cubre el capital pendiente salda la deuda y limpia F',
      () async {
    await sembrar(_credito());
    await abonar(200); // deja F
    final d0 = (await deudas.obtenerPorId('auto'))!;
    final d = await abonar(capitalPendiente(d0));
    expect(d.estado, EstadoDeuda.pagada);
    expect(d.numeroCuotasTotal, 12);
    expect(d.montoUltimaCuota, isNull);
    expect(saldoPendiente(d), closeTo(0, 0.01));
  });

  // Fase 85 (A.1) — deuda QUINCENAL: el período es de 15 días.
  //
  // Script Python independiente (mismo método: Decimal, bisección,
  // amortización período a período). S/ 5,000 en 48 cuotas quincenales de
  // S/ 130, 10 pagadas:
  //   i quincenal = 0.009431282624103271412159097680783827937107657489950
  //   TEA = 0.2566118442493100992159182615695460762630481557777
  //   capital antes = 4135.5056490992439520225349649056931540799235029602
  //   abono 1000: completas=27 F=64.4177851488 total cuotas=38
  //               saldo=3574.4177851488
  //     (si se usara la tasa mensual: completas=32 F=93.0132)
  //   abono 50:   completas=37 F=58.5689774903 total cuotas=48
  //               saldo=4868.5689774903
  //     (si se usara la tasa mensual: completas=48 F=85.7321)
  group('Quincenal', () {
    Deuda quincenal() => _credito().copyWith(
      montoTotal: 5000,
      montoPagado: 1300,
      numeroCuotasTotal: 48,
      numeroCuotasPagadas: 10,
      montoCuota: 130,
      periodicidadCuotas: PeriodicidadCuota.quincenal,
    );

    test('la tasa es la del período de 15 días, no la mensual', () {
      expect(
        tasaPeriodicaCuotasFijas(quincenal()),
        closeTo(0.009431282624103271, 1e-9),
      );
      final e = estimarAbonoCapital(quincenal(), 1000)!;
      expect(e.capitalAntes, closeTo(4135.505649099244, 1e-6));
    });

    test('abono 1000: 27 completas + última de 64.42, fechas cada 15 días',
        () async {
      await deudas.crear(quincenal());
      final d = await abonar(1000);
      expect(d.numeroCuotasTotal, 38);
      expect(d.montoUltimaCuota, closeTo(64.4177851488, 1e-6));
      expect(saldoPendiente(d), closeTo(3574.4177851488, 1e-6));
      expect(
        d.fechaVencimientoFinal,
        DateTime(2026, 1, 15).add(const Duration(days: 15 * 37)),
      );
    });

    test('abono 50: mismo número de cuotas, la última baja a 58.57',
        () async {
      await deudas.crear(quincenal());
      final d = await abonar(50);
      expect(d.numeroCuotasTotal, 48);
      expect(d.montoUltimaCuota, closeTo(58.5689774903, 1e-6));
      expect(saldoPendiente(d), closeTo(4868.5689774903, 1e-6));
    });
  });

  test('adelantar hasta la última paga F en esa cuota', () async {
    await sembrar(_credito());
    await abonar(3000);
    final d0 = (await deudas.obtenerPorId('auto'))!;
    expect(montoAdelantoCuotas(d0, 13), closeTo(450 * 12 + _fA, 1e-6));
    final hechos = await RegistrarAdelantoCuotas(
      deudaRepository: deudas,
      pagoDeudaRepository: pagos,
      cuentaRepository: cuentas,
      registrarPagoDeuda: registrar,
    )(deudaId: 'auto', cantidad: 13, cuentaId: 'bcp');
    expect(hechos.last.numeroCuota, 25);
    expect(hechos.last.montoPagado, closeTo(_fA, 1e-6));
    final d = (await deudas.obtenerPorId('auto'))!;
    expect(d.estado, EstadoDeuda.pagada);
    expect(saldoPendiente(d), closeTo(0, 0.01));
  });
}
