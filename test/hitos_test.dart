import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/hitos.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_hitos_repository_shared_prefs.dart';

/// Fase 87 (D) — hitos.
final _ahora = DateTime(2026, 11, 17, 9);

Deuda _libre(
  String id, {
  double total = 1000,
  double pagado = 0,
  EstadoDeuda estado = EstadoDeuda.activa,
  DireccionDeuda direccion = DireccionDeuda.debo,
  String? cuentaId,
}) => Deuda(
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.deudaInformal,
  tipoAcreedor: TipoAcreedor.personaNatural,
  nombreAcreedor: 'Ana',
  moneda: Moneda.pen,
  montoTotal: total,
  montoPagado: pagado,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: estado,
  direccion: direccion,
  cuentaId: cuentaId,
);

var _n = 0;
PagoDeuda _pago(
  String deudaId,
  DateTime fecha,
  double monto, {
  TipoPagoDeuda tipo = TipoPagoDeuda.cuota,
}) => PagoDeuda(
  id: 'p${_n++}',
  deudaId: deudaId,
  montoPagado: monto,
  fechaPago: fecha,
  tipo: tipo,
);

Cuenta _tarjeta(double saldo) => Cuenta(
  id: 'visa',
  nombre: 'Visa',
  tipo: TipoCuenta.credito,
  moneda: Moneda.pen,
  saldoActual: saldo,
  lineaCredito: 1000,
);

Transaccion _compra() => Transaccion(
  id: 'c${_n++}',
  cuentaId: 'visa',
  categoriaId: 'cat',
  monto: 10,
  moneda: Moneda.pen,
  tipo: TipoTransaccion.gasto,
  concepto: '',
  metodoPago: MetodoPago.tarjeta,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: DateTime(2026, 10, 1),
);

Map<Hito, DateTime> _cumplidos({
  List<Deuda> deudas = const [],
  Map<String, List<PagoDeuda>> pagos = const {},
  List<Cuenta> cuentas = const [],
  List<Transaccion> transacciones = const [],
}) => hitosCumplidos(
  ContextoHitos(
    ahora: _ahora,
    deudas: deudas,
    pagosPorDeuda: pagos,
    cuentas: cuentas,
    transacciones: transacciones,
  ),
);

void main() {
  test('primer pago: con la fecha del pago más antiguo; sin pagos no', () {
    final r = _cumplidos(
      deudas: [_libre('A', pagado: 300)],
      pagos: {
        'A': [
          _pago('A', DateTime(2026, 9, 5), 200),
          _pago('A', DateTime(2026, 8, 2), 100),
        ],
      },
    );
    expect(r[Hito.primerPago], DateTime(2026, 8, 2));
    expect(_cumplidos(deudas: [_libre('A')]), isNot(contains(Hito.primerPago)));
  });

  test('"me deben" no cuenta para ningún hito', () {
    final r = _cumplidos(
      deudas: [
        _libre(
          'L',
          pagado: 1000,
          estado: EstadoDeuda.pagada,
          direccion: DireccionDeuda.meDeben,
        ),
      ],
      pagos: {
        'L': [_pago('L', DateTime(2026, 9, 1), 1000)],
      },
    );
    expect(r, isEmpty);
  });

  group('25 / 50 / 75 %', () {
    Map<Hito, DateTime> con(double pagado) =>
        _cumplidos(deudas: [_libre('A', total: 1000, pagado: pagado)]);
    test('al cruzar el límite: 24.99 % no, 25 % exacto sí', () {
      expect(con(249.9), isNot(contains(Hito.avance25)));
      expect(con(250), contains(Hito.avance25));
      expect(con(250)[Hito.avance25], _ahora, reason: 'fecha de detección');
      expect(con(499.9), isNot(contains(Hito.avance50)));
      expect(con(500), containsPair(Hito.avance50, _ahora));
      expect(
        con(750).keys,
        containsAll([Hito.avance25, Hito.avance50, Hito.avance75]),
      );
    });
  });

  test('primera deuda saldada y libre de deudas (con sus fechas)', () {
    final pagos = {
      'A': [_pago('A', DateTime(2026, 6, 1), 1000)],
      'B': [_pago('B', DateTime(2026, 9, 1), 500)],
    };
    final una = _cumplidos(
      deudas: [
        _libre('A', pagado: 1000, estado: EstadoDeuda.pagada),
        _libre('B', total: 800, pagado: 500),
      ],
      pagos: pagos,
    );
    expect(una[Hito.primeraDeudaSaldada], DateTime(2026, 6, 1));
    expect(una, isNot(contains(Hito.libreDeDeudas)));

    final todas = _cumplidos(
      deudas: [
        _libre('A', pagado: 1000, estado: EstadoDeuda.pagada),
        _libre('B', total: 500, pagado: 500, estado: EstadoDeuda.pagada),
        // La tarjeta no impide "libre de deudas" (no es una deuda propia).
        _libre('T', cuentaId: 'visa'),
      ],
      pagos: pagos,
    );
    expect(todas[Hito.libreDeDeudas], DateTime(2026, 9, 1));
    // Sin ninguna deuda propia no hay "libre de deudas".
    expect(_cumplidos(deudas: [_libre('T', cuentaId: 'visa')]), isEmpty);
    // Las canceladas no cuentan.
    expect(
      _cumplidos(deudas: [_libre('C', estado: EstadoDeuda.cancelada)]),
      isNot(contains(Hito.libreDeDeudas)),
    );
  });

  test('primer abono a capital', () {
    final r = _cumplidos(
      deudas: [_libre('A', pagado: 300)],
      pagos: {
        'A': [
          _pago('A', DateTime(2026, 5, 1), 100),
          _pago(
            'A',
            DateTime(2026, 7, 9),
            200,
            tipo: TipoPagoDeuda.abonoCapital,
          ),
        ],
      },
    );
    expect(r[Hito.primerAbono], DateTime(2026, 7, 9));
    expect(
      _cumplidos(
        deudas: [_libre('A')],
        pagos: {
          'A': [_pago('A', DateTime(2026, 5, 1), 100)],
        },
      ),
      isNot(contains(Hito.primerAbono)),
    );
  });

  test('tarjeta bajo el 30 %: límite estricto y solo si se usó', () {
    expect(
      _cumplidos(cuentas: [_tarjeta(-299)], transacciones: [_compra()]),
      contains(Hito.tarjetaBajo30),
    );
    expect(
      _cumplidos(cuentas: [_tarjeta(-300)], transacciones: [_compra()]),
      isNot(contains(Hito.tarjetaBajo30)),
    );
    expect(
      _cumplidos(cuentas: [_tarjeta(0)]),
      isNot(contains(Hito.tarjetaBajo30)),
      reason: 'nunca usada',
    );
  });

  test('racha de 3 meses (y 2 no)', () {
    Deuda cuotas(int n) => Deuda(
      id: 'Q',
      nombreDeuda: 'Q',
      tipoDeuda: TipoDeuda.prestamoPersonal,
      tipoAcreedor: TipoAcreedor.entidadFinanciera,
      nombreAcreedor: 'Banco',
      moneda: Moneda.pen,
      montoTotal: 100.0 * n,
      montoPagado: 100.0 * n,
      tieneInteres: false,
      estructuraPago: EstructuraPago.cuotasFijas,
      numeroCuotasTotal: n,
      numeroCuotasPagadas: n,
      montoCuota: 100,
      periodicidadCuotas: PeriodicidadCuota.mensual,
      fechaInicio: DateTime(2026, 7, 5),
      enMora: false,
      estado: EstadoDeuda.activa,
    );
    Map<String, List<PagoDeuda>> pagos(int n) => {
      'Q': [
        for (var k = 0; k < n; k++)
          PagoDeuda(
            id: 'q$k',
            deudaId: 'Q',
            montoPagado: 100,
            fechaPago: DateTime(2026, 7 + k, 5),
            numeroCuota: k + 1,
          ),
      ],
    };
    expect(
      _cumplidos(deudas: [cuotas(3)], pagos: pagos(3)),
      contains(Hito.racha3),
    );
    expect(
      _cumplidos(deudas: [cuotas(2)], pagos: pagos(2)),
      isNot(contains(Hito.racha3)),
    );
  });

  group('guardado', () {
    test('nuevos: solo los no guardados (idempotente)', () {
      final ctx = ContextoHitos(
        ahora: _ahora,
        deudas: [_libre('A', pagado: 300)],
        pagosPorDeuda: {
          'A': [_pago('A', DateTime(2026, 8, 2), 300)],
        },
        cuentas: const [],
      );
      final primeros = hitosNuevos(ctx, const {});
      expect(primeros.map((h) => h.hito), [Hito.primerPago, Hito.avance25]);
      final guardados = {for (final h in primeros) h.hito: h};
      expect(hitosNuevos(ctx, guardados), isEmpty);
    });

    test('no se pierde si el % baja después (deuda nueva)', () {
      final guardados = {
        Hito.avance25: HitoLogrado(
          hito: Hito.avance25,
          fecha: DateTime(2026, 10, 1),
          celebrado: true,
        ),
      };
      final ctx = ContextoHitos(
        ahora: _ahora,
        deudas: [_libre('A', pagado: 300), _libre('B', total: 5000)],
        pagosPorDeuda: const {},
        cuentas: const [],
      );
      expect(hitosCumplidos(ctx), isNot(contains(Hito.avance25)));
      expect(hitosNuevos(ctx, guardados), isEmpty);
      expect(guardados[Hito.avance25]!.fecha, DateTime(2026, 10, 1));
    });

    test('celebración: uno a la vez, el más antiguo, y nunca se repite', () {
      final guardados = {
        Hito.avance25: HitoLogrado(
          hito: Hito.avance25,
          fecha: DateTime(2026, 11, 1),
        ),
        Hito.primerPago: HitoLogrado(
          hito: Hito.primerPago,
          fecha: DateTime(2026, 8, 2),
        ),
      };
      expect(siguienteACelebrar(guardados)!.hito, Hito.primerPago);
      guardados[Hito.primerPago] = guardados[Hito.primerPago]!.comoCelebrado();
      expect(siguienteACelebrar(guardados)!.hito, Hito.avance25);
      guardados[Hito.avance25] = guardados[Hito.avance25]!.comoCelebrado();
      expect(siguienteACelebrar(guardados), isNull);
    });

    test('SharedPreferences: ida y vuelta; ilegible se ignora', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasHitosRepositorySharedPrefs(prefs);
      await repo.guardar([
        HitoLogrado(hito: Hito.primerPago, fecha: DateTime(2026, 8, 2)),
      ]);
      await repo.guardar([
        HitoLogrado(hito: Hito.avance25, fecha: _ahora, celebrado: true),
      ]);
      final leido = repo.leer();
      expect(leido.keys, unorderedEquals([Hito.primerPago, Hito.avance25]));
      expect(leido[Hito.primerPago]!.fecha, DateTime(2026, 8, 2));
      expect(leido[Hito.primerPago]!.celebrado, isFalse);
      expect(leido[Hito.avance25]!.celebrado, isTrue);
      await prefs.setString(
        PreferenciasHitosRepositorySharedPrefs.clave,
        '{roto',
      );
      expect(repo.leer(), isEmpty);
    });
  });
}
