import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/actualizar_estado_mora.dart';
import 'package:finanzas_automaticas/domain/usecases/armar_resumen_para_consejos.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/domain/usecases/generar_notificaciones_vencimiento.dart';
import 'package:finanzas_automaticas/domain/usecases/obtener_resumen_dashboard.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/notificacion_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_repository_shared_prefs.dart';

/// Fase 82 (C) — reglas de negocio por dirección de la deuda.
class _AmistadEspia implements AmistadRepository {
  final notificados = <String>[];

  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async => notificados.add(amigoUsuarioId);

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

Deuda _deuda(
  String id, {
  DireccionDeuda direccion = DireccionDeuda.debo,
  double total = 100,
  double pagado = 0,
  Moneda moneda = Moneda.pen,
  EstructuraPago estructura = EstructuraPago.pagoLibre,
  String? amigo,
  DateTime? inicio,
}) => Deuda(
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.deudaInformal,
  tipoAcreedor: TipoAcreedor.personaNatural,
  nombreAcreedor: 'Lucía',
  moneda: moneda,
  montoTotal: total,
  montoPagado: pagado,
  tieneInteres: false,
  estructuraPago: estructura,
  numeroCuotasTotal: estructura == EstructuraPago.cuotasFijas ? 4 : null,
  numeroCuotasPagadas: estructura == EstructuraPago.cuotasFijas ? 0 : null,
  montoCuota: estructura == EstructuraPago.cuotasFijas ? total / 4 : null,
  periodicidadCuotas: estructura == EstructuraPago.cuotasFijas
      ? PeriodicidadCuota.mensual
      : null,
  fechaInicio: inicio ?? DateTime(2026, 11, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
  amigoUsuarioId: amigo,
  direccion: direccion,
);

void main() {
  late AppDatabase db;
  late DeudaRepositoryDrift deudas;
  late CuentaRepositoryDrift cuentas;
  late PagoDeudaRepositoryDrift pagos;
  late _AmistadEspia amistad;
  late RegistrarPagoDeuda registrarPago;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deudas = DeudaRepositoryDrift(db);
    cuentas = CuentaRepositoryDrift(db);
    pagos = PagoDeudaRepositoryDrift(db);
    amistad = _AmistadEspia();
    registrarPago = RegistrarPagoDeuda(
      pagoDeudaRepository: pagos,
      deudaRepository: deudas,
      cuentaRepository: cuentas,
      amistadRepository: amistad,
    );
  });
  tearDown(() => db.close());

  Future<void> crearCuenta(String id, double saldo, {Moneda m = Moneda.pen}) =>
      cuentas.crear(
        Cuenta(
          id: id,
          nombre: id,
          tipo: TipoCuenta.debito,
          moneda: m,
          saldoActual: saldo,
        ),
      );

  group('totales por dirección', () {
    test('saldoPendientePorMoneda nunca mezcla debo con me deben', () {
      final lista = [
        _deuda('a', total: 100, pagado: 20),
        _deuda('b', total: 50, moneda: Moneda.usd),
        _deuda('c', total: 380, direccion: DireccionDeuda.meDeben),
      ];
      expect(saldoPendientePorMoneda(lista, DireccionDeuda.debo), {
        Moneda.pen: 80,
        Moneda.usd: 50,
      });
      expect(saldoPendientePorMoneda(lista, DireccionDeuda.meDeben), {
        Moneda.pen: 380,
      });
    });

    test('ObtenerResumenDashboard separa listas y totales', () async {
      await deudas.crear(_deuda('debo', total: 300, pagado: 100));
      await deudas.crear(
        _deuda('meDeben', total: 380, direccion: DireccionDeuda.meDeben),
      );
      final resumen = await ObtenerResumenDashboard(
        cuentaRepository: cuentas,
        transaccionRepository: TransaccionRepositoryDrift(db),
        categoriaRepository: CategoriaRepositoryDrift(db),
        deudaRepository: deudas,
      ).call();

      expect(resumen.deudasActivas.map((d) => d.id), ['debo']);
      expect(resumen.deudasMeDebenActivas.map((d) => d.id), ['meDeben']);
      expect(
        resumen.deudasMeDebenActivas.single.direccion,
        DireccionDeuda.meDeben,
      );
      expect(resumen.totalAdeudadoPorMoneda, {Moneda.pen: 200});
      expect(resumen.totalTeDebenPorMoneda, {Moneda.pen: 380});
      expect(resumen.estaVacio, isFalse);
    });

    test('solo un "me deben" no deja el dashboard vacío', () async {
      await deudas.crear(_deuda('x', direccion: DireccionDeuda.meDeben));
      final resumen = await ObtenerResumenDashboard(
        cuentaRepository: cuentas,
        transaccionRepository: TransaccionRepositoryDrift(db),
        categoriaRepository: CategoriaRepositoryDrift(db),
        deudaRepository: deudas,
      ).call();
      expect(resumen.deudasActivas, isEmpty);
      expect(resumen.estaVacio, isFalse);
    });
  });

  group('RegistrarPagoDeuda', () {
    test(
      'un cobro ("me deben") SUMA a la cuenta y no avisa al amigo',
      () async {
        await crearCuenta('yape', 70);
        await deudas.crear(
          _deuda(
            'lucia',
            total: 380,
            direccion: DireccionDeuda.meDeben,
            amigo: 'amigo-lucia',
          ),
        );

        await registrarPago(
          deudaId: 'lucia',
          cuentaId: 'yape',
          montoPagado: 100,
        );

        expect((await cuentas.obtenerPorId('yape'))!.saldoActual, 170);
        final deuda = (await deudas.obtenerPorId('lucia'))!;
        expect(deuda.montoPagado, 100);
        expect(saldoPendiente(deuda), 280);
        expect(deuda.direccion, DireccionDeuda.meDeben);
        expect(amistad.notificados, isEmpty);
      },
    );

    test(
      'un pago normal ("debo") sigue RESTANDO y avisando al amigo',
      () async {
        await crearCuenta('bcp', 500);
        await deudas.crear(_deuda('marco', amigo: 'amigo-marco'));

        await registrarPago(deudaId: 'marco', cuentaId: 'bcp', montoPagado: 40);

        expect((await cuentas.obtenerPorId('bcp'))!.saldoActual, 460);
        expect(amistad.notificados, ['amigo-marco']);
      },
    );

    test('cobro sin cuenta (retroactivo) no mueve saldos', () async {
      await crearCuenta('yape', 70);
      await deudas.crear(_deuda('l', direccion: DireccionDeuda.meDeben));
      await registrarPago(deudaId: 'l', montoPagado: 30);
      expect((await cuentas.obtenerPorId('yape'))!.saldoActual, 70);
      expect((await deudas.obtenerPorId('l'))!.montoPagado, 30);
    });

    test('cobro con cuenta en otra moneda falla igual que un pago', () async {
      await crearCuenta('usd', 10, m: Moneda.usd);
      await deudas.crear(_deuda('l', direccion: DireccionDeuda.meDeben));
      await expectLater(
        registrarPago(deudaId: 'l', cuentaId: 'usd', montoPagado: 5),
        throwsStateError,
      );
    });

    test(
      'Fase 83: un cobro no se puede recibir en una tarjeta de crédito',
      () async {
        await cuentas.crear(
          const Cuenta(
            id: 'visa',
            nombre: 'Visa',
            tipo: TipoCuenta.credito,
            moneda: Moneda.pen,
            saldoActual: -100,
            lineaCredito: 2000,
          ),
        );
        await deudas.crear(_deuda('l', direccion: DireccionDeuda.meDeben));
        await expectLater(
          registrarPago(deudaId: 'l', cuentaId: 'visa', montoPagado: 50),
          throwsStateError,
        );
        expect((await cuentas.obtenerPorId('visa'))!.saldoActual, -100);
      },
    );

    test('cobrar todo deja la deuda "me deben" como pagada', () async {
      await deudas.crear(
        _deuda('l', total: 50, direccion: DireccionDeuda.meDeben),
      );
      await registrarPago(deudaId: 'l', montoPagado: 50);
      expect((await deudas.obtenerPorId('l'))!.estado, EstadoDeuda.pagada);
    });
  });

  test('ActualizarEstadoMora no pone en mora un "me deben" vencido', () async {
    final hace40 = DateTime.now().subtract(const Duration(days: 40));
    final inicio = DateTime(hace40.year, hace40.month, hace40.day);
    await deudas.crear(
      _deuda(
        'cobro',
        estructura: EstructuraPago.cuotasFijas,
        direccion: DireccionDeuda.meDeben,
        inicio: inicio,
      ),
    );
    await deudas.crear(
      _deuda('mia', estructura: EstructuraPago.cuotasFijas, inicio: inicio),
    );

    await ActualizarEstadoMora(
      deudaRepository: deudas,
      pagoDeudaRepository: pagos,
    ).call();

    expect((await deudas.obtenerPorId('cobro'))!.enMora, isFalse);
    expect((await deudas.obtenerPorId('mia'))!.enMora, isTrue);
  });

  test('GenerarNotificacionesVencimiento ignora los "me deben"', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final notificaciones = NotificacionRepositoryLocal(prefs);
    final ayer = DateTime.now().subtract(const Duration(days: 1));
    DeudaActivaResumen resumen(String id, DireccionDeuda d) =>
        DeudaActivaResumen(
          id: id,
          nombreDeuda: id,
          estructuraPago: EstructuraPago.cuotasFijas,
          proximaFechaPago: ayer,
          enMora: false,
          diasMora: null,
          montoPagado: 0,
          montoTotal: 100,
          montoCuota: 25,
          moneda: Moneda.pen,
          fechaVencimientoReal: ayer,
          direccion: d,
        );

    await GenerarNotificacionesVencimiento(
      notificacionRepository: notificaciones,
      preferenciasRepository: PreferenciasRepositorySharedPrefs(prefs),
    ).call([
      resumen('mia', DireccionDeuda.debo),
      resumen('cobro', DireccionDeuda.meDeben),
    ]);

    final todas = await notificaciones.obtenerTodas();
    expect(todas.map((n) => n.data!['deuda_id']), ['mia']);
  });

  test('ArmarResumenParaConsejos solo incluye lo que debo', () async {
    await deudas.crear(_deuda('mia', total: 300));
    await deudas.crear(
      _deuda('cobro', total: 380, direccion: DireccionDeuda.meDeben),
    );
    final resumen = await ArmarResumenParaConsejos(
      deudaRepository: deudas,
      transaccionRepository: TransaccionRepositoryDrift(db),
      categoriaRepository: CategoriaRepositoryDrift(db),
      cuentaRepository: cuentas,
    ).call();
    expect(resumen.deudasActivas, hasLength(1));
    expect(resumen.deudasActivas.single.montoTotal, 300);
  });

  group('RegistrarDeuda "me deben"', () {
    test('fuerza persona natural, deuda informal y sin interés; no mueve '
        'cuentas', () async {
      await crearCuenta('bcp', 500);
      final deuda = await RegistrarDeuda(deudaRepository: deudas).call(
        nombreDeuda: 'Préstamo a Lucía',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'Lucía',
        moneda: Moneda.pen,
        montoTotal: 380,
        estructuraPago: EstructuraPago.pagoLibre,
        tieneInteres: true,
        tasaInteres: 12,
        tipoTasa: TipoTasa.fija,
        pagoMinimo: 20,
        fechaInicio: DateTime(2026, 11, 1),
        direccion: DireccionDeuda.meDeben,
      );
      expect(deuda.direccion, DireccionDeuda.meDeben);
      expect(deuda.tipoAcreedor, TipoAcreedor.personaNatural);
      expect(deuda.tipoDeuda, TipoDeuda.deudaInformal);
      expect(deuda.tieneInteres, isFalse);
      expect(deuda.tasaInteres, isNull);
      expect(deuda.tipoTasa, isNull);
      expect(deuda.pagoMinimo, isNull);
      expect(deuda.enMora, isFalse);
      expect((await cuentas.obtenerPorId('bcp'))!.saldoActual, 500);
      expect(
        (await deudas.obtenerPorId(deuda.id))!.direccion,
        DireccionDeuda.meDeben,
      );
    });

    test('en cuotas, las cuotas deben sumar el monto (sin interés)', () async {
      final registrar = RegistrarDeuda(deudaRepository: deudas);
      Future<Deuda> crear(double cuota) => registrar.call(
        nombreDeuda: 'x',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'Diego',
        moneda: Moneda.pen,
        montoTotal: 400,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 4,
        montoCuota: cuota,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 11, 1),
        direccion: DireccionDeuda.meDeben,
      );
      expect((await crear(100)).interesTotal, 0);
      await expectLater(crear(110), throwsStateError);
    });

    test('"debo" se comporta igual que antes (no fuerza nada)', () async {
      final deuda = await RegistrarDeuda(deudaRepository: deudas).call(
        nombreDeuda: 'BCP',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        estructuraPago: EstructuraPago.pagoLibre,
        tieneInteres: true,
        tasaInteres: 20,
        tipoTasa: TipoTasa.fija,
        fechaInicio: DateTime(2026, 11, 1),
      );
      expect(deuda.direccion, DireccionDeuda.debo);
      expect(deuda.tipoAcreedor, TipoAcreedor.entidadFinanciera);
      expect(deuda.tasaInteres, 20);
    });
  });
}
