import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/abono_capital.dart';
import 'package:finanzas_automaticas/domain/costo_deuda.dart';
import 'package:finanzas_automaticas/domain/cronograma_cuotas.dart';
import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_adelanto_cuotas.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';

/// Fase 84 (C) — abono a capital y adelanto de cuotas.

class _AmistadQueAnota implements AmistadRepository {
  final avisos = <double>[];
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async => avisos.add(monto);
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

/// Falla en la llamada número [fallaEn] a `crear` (1 = la primera).
class _PagosQueFallan implements PagoDeudaRepository {
  _PagosQueFallan(this._real, this.fallaEn);
  final PagoDeudaRepository _real;
  final int fallaEn;
  var _llamadas = 0;
  @override
  Future<void> crear(PagoDeuda pago) {
    _llamadas++;
    if (_llamadas == fallaEn) throw StateError('sin conexión');
    return _real.crear(pago);
  }

  @override
  Future<void> eliminar(String id) => _real.eliminar(id);
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String c) =>
      _real.obtenerPorCuenta(c);
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String d) => _real.obtenerPorDeuda(d);
}

/// Crédito vehicular: S/ 10,000 en 36 cuotas mensuales de S/ 450, 12 ya
/// pagadas (5,400). Vinculado a un amigo para probar la notificación.
Deuda _credito({
  String id = 'auto',
  double montoTotal = 10000,
  DireccionDeuda direccion = DireccionDeuda.debo,
  EstructuraPago estructura = EstructuraPago.cuotasFijas,
  String? cuentaId,
}) => Deuda(
  id: id,
  nombreDeuda: 'Crédito auto',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: montoTotal,
  montoPagado: 5400,
  tieneInteres: true,
  estructuraPago: estructura,
  numeroCuotasTotal: 36,
  numeroCuotasPagadas: 12,
  montoCuota: 450,
  periodicidadCuotas: PeriodicidadCuota.mensual,
  fechaInicio: DateTime(2026, 1, 15),
  proximaFechaPago: DateTime(2027, 1, 15),
  enMora: false,
  estado: EstadoDeuda.activa,
  amigoUsuarioId: 'amigo-1',
  direccion: direccion,
  cuentaId: cuentaId,
);

void main() {
  late AppDatabase db;
  late DeudaRepositoryDrift deudas;
  late PagoDeudaRepositoryDrift pagos;
  late CuentaRepositoryDrift cuentas;
  late _AmistadQueAnota amistad;
  late RegistrarPagoDeuda registrar;

  RegistrarPagoDeuda registrarCon(PagoDeudaRepository repoPagos) =>
      RegistrarPagoDeuda(
        pagoDeudaRepository: repoPagos,
        deudaRepository: deudas,
        cuentaRepository: cuentas,
        amistadRepository: amistad,
      );

  Future<void> sembrar(Deuda deuda) async {
    await deudas.crear(deuda);
    for (var n = 1; n <= (deuda.numeroCuotasPagadas ?? 0); n++) {
      await pagos.crear(
        PagoDeuda(
          id: '${deuda.id}-c$n',
          deudaId: deuda.id,
          montoPagado: 450,
          fechaPago: sumarMeses(deuda.fechaInicio, n - 1),
          numeroCuota: n,
        ),
      );
    }
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deudas = DeudaRepositoryDrift(db);
    pagos = PagoDeudaRepositoryDrift(db);
    cuentas = CuentaRepositoryDrift(db);
    amistad = _AmistadQueAnota();
    registrar = registrarCon(pagos);
    await cuentas.crear(
      const Cuenta(
        id: 'bcp',
        nombre: 'Débito BCP',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 10000,
      ),
    );
  });
  tearDown(() => db.close());

  group('estimarAbonoCapital (puro)', () {
    test('caso verificado con un script independiente', () {
      // Script Python independiente (bisección propia con Decimal y búsqueda
      // del menor k por fuerza bruta, sin la fórmula de nper):
      //   i mensual 0.028818655066628278   TEA 0.4062611082390294
      //   capital pendiente (24 cuotas)    7718.890381861695
      //   capital tras abono de 3000       4718.890381861695
      //   cuotas restantes nuevas 13 → total 25
      //   PV(13) 4822.08853602341   PV(12) 4511.054642243811
      //   exceso 103.19815416171564 (< una cuota)
      //   sin tasa: ceil((450 × 24 − 3000) / 450) = 18
      // Fase 84b: la última de las 13 ya no es completa (ver
      // ultima_cuota_test.dart): F = 300.6941838124, saldo 5700.69.
      final e = estimarAbonoCapital(_credito(), 3000)!;
      expect(e.sinTasa, isFalse);
      expect(e.tasaPeriodica, closeTo(0.028818655066628278, 1e-9));
      expect(e.capitalAntes, closeTo(7718.890381861695, 1e-6));
      expect(e.cuotasRestantesAntes, 24);
      expect(e.cuotasRestantesDespues, 13);

      // Propiedad: el VP de las n' cuotas cubre el capital que queda y le
      // sobra menos de una cuota.
      final restante = e.capitalAntes - 3000;
      final vp = valorPresenteCuotas(cuota: 450, n: 13, i: e.tasaPeriodica);
      expect(vp, greaterThanOrEqualTo(restante));
      expect(vp - restante, lessThan(450));
      expect(vp - restante, closeTo(103.19815416171564, 1e-6));
    });

    test(
      'sin tasa (cuotas = capital, 0 %) → ceil((capital − abono)/cuota)',
      () {
        final e = estimarAbonoCapital(_credito(montoTotal: 450.0 * 36), 3000)!;
        expect(e.tasaPeriodica, 0);
        expect(e.cuotasRestantesDespues, 18);
      },
    );

    test('cuotas que suman menos que el capital → 0 % (costo_deuda)', () {
      final e = estimarAbonoCapital(_credito(montoTotal: 20000), 3000)!;
      expect(e.sinTasa, isFalse);
      expect(e.tasaPeriodica, 0);
      expect(e.cuotasRestantesDespues, 18);
    });

    test('cuotasParaCubrir: exacto no suma una cuota de más', () {
      expect(cuotasParaCubrir(capital: 900, cuota: 450, i: 0), 2);
      expect(cuotasParaCubrir(capital: 0, cuota: 450, i: 0.02), 0);
      final vp3 = valorPresenteCuotas(cuota: 450, n: 3, i: 0.02);
      expect(cuotasParaCubrir(capital: vp3, cuota: 450, i: 0.02), 3);
      expect(cuotasParaCubrir(capital: 1e6, cuota: 10, i: 0.02), isNull);
    });
  });

  group('RegistrarPagoDeuda — abono a capital', () {
    test('caso base: recorta cuotas, suma lo abonado, saldo coherente, '
        'cronograma intacto', () async {
      await sembrar(_credito());
      final teaAntes = tasaEfectivaAnual((await deudas.obtenerPorId('auto'))!);

      final pago = await registrar(
        deudaId: 'auto',
        cuentaId: 'bcp',
        montoPagado: 3000,
        tipo: TipoPagoDeuda.abonoCapital,
        fechaPago: DateTime(2026, 12, 20),
      );
      expect(pago.tipo, TipoPagoDeuda.abonoCapital);
      expect(pago.numeroCuota, isNull);

      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasPagadas, 12, reason: 'un abono no es una cuota');
      expect(d.numeroCuotasTotal, 25);
      expect(d.montoPagado, 8400);
      expect(d.montoAbonadoCapital, 3000);
      // Fase 84b: la última cuota baja a F (antes se contaba completa).
      const f = 300.6941838124;
      expect(d.montoUltimaCuota, closeTo(f, 1e-6));
      expect(totalAPagar(d), closeTo(450.0 * 24 + f + 3000, 1e-6));
      expect(saldoPendiente(d), closeTo(450.0 * 12 + f, 1e-6));
      expect(d.estado, EstadoDeuda.activa);
      expect(d.interesTotal, closeTo(450.0 * 24 + f + 3000 - 10000, 1e-6));

      // La TEA queda congelada: con n' = 25 ya no se puede despejar.
      expect(d.tasaInteres, closeTo(teaAntes! * 100, 1e-9));
      expect(tasaEfectivaAnual(d), closeTo(0.4062611082390294, 1e-9));
      // El plan ve el capital nuevo: VP de 12 cuotas + la última F, que es
      // exactamente el capital tras el abono (7718.89 − 3000).
      expect(capitalPendiente(d), closeTo(4718.890381861695, 1e-6));

      // Cronograma: 25 cuotas, 1–12 pagadas, la 13 es la siguiente.
      final crono = generarCronogramaCuotas(
        d,
        await pagos.obtenerPorDeuda('auto'),
      );
      expect(crono, hasLength(25));
      expect(crono.where((c) => c.pagada).map((c) => c.numero), [
        for (var n = 1; n <= 12; n++) n,
      ]);
      expect(d.proximaFechaPago, DateTime(2027, 1, 15));
      expect(d.fechaVencimientoFinal, DateTime(2028, 1, 15));

      expect((await cuentas.obtenerPorId('bcp'))!.saldoActual, 7000);
      expect(amistad.avisos, [3000]);
    });

    test(
      'tras el abono se puede pagar la cuota 13 (regla secuencial)',
      () async {
        await sembrar(_credito());
        await registrar(
          deudaId: 'auto',
          cuentaId: 'bcp',
          montoPagado: 3000,
          tipo: TipoPagoDeuda.abonoCapital,
        );
        await registrar(
          deudaId: 'auto',
          cuentaId: 'bcp',
          montoPagado: 450,
          numeroCuota: 13,
        );
        final d = (await deudas.obtenerPorId('auto'))!;
        expect(d.numeroCuotasPagadas, 13);
        expect(d.numeroCuotasTotal, 25);
        expect(saldoPendiente(d), closeTo(450.0 * 11 + 300.6941838124, 1e-6));
      },
    );

    test('un segundo abono usa la TEA congelada', () async {
      await sembrar(_credito());
      await registrar(
        deudaId: 'auto',
        montoPagado: 3000,
        tipo: TipoPagoDeuda.abonoCapital,
      );
      final tras1 = (await deudas.obtenerPorId('auto'))!;
      final esperado = estimarAbonoCapital(tras1, 1000)!;
      expect(esperado.tasaPeriodica, closeTo(0.028818655066628278, 1e-9));
      await registrar(
        deudaId: 'auto',
        montoPagado: 1000,
        tipo: TipoPagoDeuda.abonoCapital,
      );
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasTotal, 12 + esperado.cuotasRestantesDespues);
      expect(d.montoAbonadoCapital, 4000);
      expect(d.tasaInteres, closeTo(tras1.tasaInteres!, 1e-12));
    });

    test('un abono que cubre el capital salda la deuda', () async {
      await sembrar(_credito());
      final capital = estimarAbonoCapital(_credito(), 0)!.capitalAntes;
      await registrar(
        deudaId: 'auto',
        cuentaId: 'bcp',
        montoPagado: capital,
        tipo: TipoPagoDeuda.abonoCapital,
      );
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasTotal, 12);
      expect(saldoPendiente(d), closeTo(0, 1e-9));
      expect(d.estado, EstadoDeuda.pagada);
      expect(d.proximaFechaPago, isNull);
    });

    test('cuotasRestantesSegunBanco manda sobre la estimación', () async {
      await sembrar(_credito());
      await registrar(
        deudaId: 'auto',
        montoPagado: 3000,
        tipo: TipoPagoDeuda.abonoCapital,
        cuotasRestantesSegunBanco: 15,
      );
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasTotal, 27);
      // Fase 84b: el banco dio OTRO número de cuotas → no se adivina F.
      expect(d.montoUltimaCuota, isNull);
      expect(saldoPendiente(d), 450.0 * 15);
    });

    test('cuotasRestantesSegunBanco fuera de rango o en una cuota normal se '
        'rechaza', () async {
      await sembrar(_credito());
      await expectLater(
        registrar(
          deudaId: 'auto',
          montoPagado: 3000,
          tipo: TipoPagoDeuda.abonoCapital,
          cuotasRestantesSegunBanco: 25,
        ),
        throwsArgumentError,
      );
      await expectLater(
        registrar(
          deudaId: 'auto',
          montoPagado: 450,
          numeroCuota: 13,
          cuotasRestantesSegunBanco: 10,
        ),
        throwsArgumentError,
      );
      expect(await pagos.obtenerPorDeuda('auto'), hasLength(12));
    });

    test('abono sin tasa (0 %)', () async {
      await sembrar(_credito(montoTotal: 450.0 * 36));
      await registrar(
        deudaId: 'auto',
        montoPagado: 3000,
        tipo: TipoPagoDeuda.abonoCapital,
      );
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasTotal, 12 + 18);
      expect(d.tasaInteres, 0);
      expect(tasaEfectivaAnual(d), 0);
      // Fase 84b: 17 cuotas completas + una última de 150 (7800 − 17 ×
      // 450); antes se contaba completa y el saldo daba 8100.
      expect(d.montoUltimaCuota, closeTo(150, 1e-9));
      expect(saldoPendiente(d), closeTo(7800, 1e-9));
    });

    test('rechazos: me deben, pago libre, tarjeta, monto > saldo', () async {
      await sembrar(_credito(id: 'md', direccion: DireccionDeuda.meDeben));
      await sembrar(_credito(id: 'pl', estructura: EstructuraPago.pagoLibre));
      await sembrar(_credito(id: 'tj', cuentaId: 'visa'));
      await sembrar(_credito());
      Future<void> abonar(String id, double monto) => registrar(
        deudaId: id,
        montoPagado: monto,
        tipo: TipoPagoDeuda.abonoCapital,
      );
      await expectLater(abonar('md', 100), throwsStateError);
      await expectLater(abonar('pl', 100), throwsStateError);
      await expectLater(abonar('tj', 100), throwsStateError);
      await expectLater(abonar('auto', 450.0 * 24 + 1), throwsStateError);
      await expectLater(abonar('auto', 0), throwsArgumentError);
      for (final id in ['md', 'pl', 'tj', 'auto']) {
        final d = (await deudas.obtenerPorId(id))!;
        expect(d.montoAbonadoCapital, 0, reason: id);
        expect(d.numeroCuotasTotal, 36, reason: id);
      }
      expect(amistad.avisos, isEmpty);
    });
  });

  group('RegistrarAdelantoCuotas', () {
    RegistrarAdelantoCuotas adelanto([PagoDeudaRepository? repoPagos]) =>
        RegistrarAdelantoCuotas(
          deudaRepository: deudas,
          pagoDeudaRepository: pagos,
          cuentaRepository: cuentas,
          registrarPagoDeuda: registrarCon(repoPagos ?? pagos),
        );

    test('adelantar 3 cuotas = 3 pagos consecutivos (13, 14, 15)', () async {
      await sembrar(_credito());
      final hechos = await adelanto()(
        deudaId: 'auto',
        cantidad: 3,
        cuentaId: 'bcp',
      );
      expect(hechos.map((p) => p.numeroCuota), [13, 14, 15]);
      expect(hechos.every((p) => p.tipo == TipoPagoDeuda.cuota), isTrue);
      expect(hechos.every((p) => p.montoPagado == 450), isTrue);
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasPagadas, 15);
      expect(d.numeroCuotasTotal, 36);
      expect(d.montoPagado, 5400 + 1350);
      expect(d.proximaFechaPago, DateTime(2027, 4, 15));
      expect((await cuentas.obtenerPorId('bcp'))!.saldoActual, 10000 - 1350);
    });

    test('adelantar más cuotas de las que quedan se rechaza sin registrar '
        'nada', () async {
      await sembrar(_credito());
      await expectLater(
        adelanto()(deudaId: 'auto', cantidad: 25, cuentaId: 'bcp'),
        throwsArgumentError,
      );
      await expectLater(
        adelanto()(deudaId: 'auto', cantidad: 0),
        throwsArgumentError,
      );
      expect(await pagos.obtenerPorDeuda('auto'), hasLength(12));
      expect((await cuentas.obtenerPorId('bcp'))!.saldoActual, 10000);
    });

    test('si falla a la mitad informa cuántas se registraron', () async {
      await sembrar(_credito());
      final error = await adelanto(_PagosQueFallan(pagos, 3))(
        deudaId: 'auto',
        cantidad: 3,
        cuentaId: 'bcp',
      ).then<Object?>((_) => null, onError: (Object e) => e);
      expect(error, isA<AdelantoCuotasIncompleto>());
      final incompleto = error! as AdelantoCuotasIncompleto;
      expect(incompleto.registradas, 2);
      expect(incompleto.solicitadas, 3);
      expect(incompleto.mensaje, contains('Se registraron 2 de 3 cuotas'));
      final d = (await deudas.obtenerPorId('auto'))!;
      expect(d.numeroCuotasPagadas, 14);
      expect((await cuentas.obtenerPorId('bcp'))!.saldoActual, 10000 - 900);
    });

    test('rechaza deudas de pago libre y de tarjeta', () async {
      await sembrar(_credito(id: 'pl', estructura: EstructuraPago.pagoLibre));
      await sembrar(_credito(id: 'tj', cuentaId: 'visa'));
      await expectLater(
        adelanto()(deudaId: 'pl', cantidad: 1),
        throwsStateError,
      );
      await expectLater(
        adelanto()(deudaId: 'tj', cantidad: 1),
        throwsStateError,
      );
    });
  });

  test('saldoPendienteDe (filas "Te deben") suma lo abonado', () {
    expect(
      saldoPendienteDe(
        estructuraPago: EstructuraPago.cuotasFijas,
        montoTotal: 10000,
        montoPagado: 8400,
        montoCuota: 450,
        numeroCuotasTotal: 25,
        montoAbonadoCapital: 3000,
      ),
      5850,
    );
  });
}
