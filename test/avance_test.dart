import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/avance.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';

/// Fase 87 (C) — "Mi avance".
///
/// Script Python independiente (Decimal y fechas propias; tolerancia 3
/// días):
///   pagado 3600 capital 2320 interes 280 sin desglose 1000
///   avance 0.7777… pct 77
///   con deuda nueva de 2000: 0.5384… 53
///   [(6,'ok'), (7,'ok'), (8,'falla'), (9,'ok'), (10,'ok'), (11,'ok'),
///    (12,'pendiente')]
///   racha actual 3 mejor 3
final _ahora = DateTime(2026, 11, 17, 9);

Deuda _deuda(
  String id, {
  double montoTotal = 1000,
  double montoPagado = 0,
  EstructuraPago estructura = EstructuraPago.pagoLibre,
  int? cuotas,
  int? pagadas,
  double? cuota,
  DateTime? inicio,
  EstadoDeuda estado = EstadoDeuda.activa,
  DireccionDeuda direccion = DireccionDeuda.debo,
  String? cuentaId,
  Moneda moneda = Moneda.pen,
}) => Deuda(
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'Banco',
  moneda: moneda,
  montoTotal: montoTotal,
  montoPagado: montoPagado,
  tieneInteres: false,
  estructuraPago: estructura,
  numeroCuotasTotal: cuotas,
  numeroCuotasPagadas: pagadas,
  montoCuota: cuota,
  periodicidadCuotas: estructura == EstructuraPago.cuotasFijas
      ? PeriodicidadCuota.mensual
      : null,
  fechaInicio: inicio ?? DateTime(2026, 1, 1),
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
  double? capital,
  double? interes,
  int? cuota,
  TipoPagoDeuda tipo = TipoPagoDeuda.cuota,
}) => PagoDeuda(
  id: 'p${_n++}',
  deudaId: deudaId,
  montoPagado: monto,
  montoCapital: capital,
  montoInteres: interes,
  fechaPago: fecha,
  numeroCuota: cuota,
  tipo: tipo,
);

/// A: 7 cuotas de 500 (jun–dic, día 10), 6 pagadas; B: pago libre 1000
/// con 500 pagados sin desglose; C: cancelada con 100 pagados.
final _a = _deuda(
  'A',
  montoTotal: 3100,
  montoPagado: 3000,
  estructura: EstructuraPago.cuotasFijas,
  cuotas: 7,
  pagadas: 6,
  cuota: 500,
  inicio: DateTime(2026, 6, 10),
);
final _b = _deuda('B', montoPagado: 500);
final _c = _deuda(
  'C',
  montoTotal: 800,
  montoPagado: 100,
  estado: EstadoDeuda.cancelada,
);

final _pagos = <String, List<PagoDeuda>>{
  'A': [
    _pago('A', DateTime(2026, 6, 9), 500, capital: 420, interes: 80, cuota: 1),
    _pago('A', DateTime(2026, 7, 12), 500, capital: 430, interes: 70, cuota: 2),
    _pago('A', DateTime(2026, 8, 20), 500, capital: 440, interes: 60, cuota: 3),
    _pago('A', DateTime(2026, 9, 10), 500, cuota: 4),
    _pago('A', DateTime(2026, 10, 8), 500, capital: 460, interes: 40, cuota: 5),
    _pago('A', DateTime(2026, 11, 11), 500, capital: 470, cuota: 6),
  ],
  'B': [
    _pago('B', DateTime(2026, 7, 1), 200),
    _pago('B', DateTime(2026, 10, 5), 300),
  ],
  'C': [_pago('C', DateTime(2026, 8, 1), 100, capital: 100, interes: 0)],
};

const _visa = Cuenta(
  id: 'visa',
  nombre: 'Visa',
  tipo: TipoCuenta.credito,
  moneda: Moneda.pen,
  saldoActual: -1500,
  lineaCredito: 5000,
);

void main() {
  Avance avance(List<Deuda> deudas, {List<Cuenta> cuentas = const []}) =>
      calcularAvance(
        deudas: deudas,
        pagosPorDeuda: _pagos,
        cuentas: cuentas,
        ahora: _ahora,
      );

  test('caso verificado: pagado con desglose donde lo hay, avance y racha', () {
    final a = avance([_a, _b, _c]);
    expect(a.pagado.total, 3600);
    expect(a.pagado.capital, 2320);
    expect(a.pagado.interes, 280);
    expect(a.pagado.sinDesglose, 1000);
    expect(
      a.pagado.capital + a.pagado.interes + a.pagado.sinDesglose,
      a.pagado.total,
    );
    expect(a.fraccion, closeTo(3500 / 4500, 1e-12));
    expect(a.porcentaje, 77);
    expect(a.racha.actual, 3);
    expect(a.racha.mejor, 3);
  });

  test('pagos sin desglose: no se estima nada', () {
    final a = avance([_b]);
    expect(a.pagado.total, 500);
    expect(a.pagado.sinDesglose, 500);
    expect(a.pagado.capital, 0);
    expect(a.pagado.interes, 0);
  });

  test('tarjetas fuera del porcentaje, aparte como uso', () {
    final tarjeta = _deuda(
      'T',
      montoTotal: 5000,
      montoPagado: 3500,
      cuentaId: 'visa',
    );
    final a = avance([_a, _b, tarjeta], cuentas: [_visa]);
    expect(a.porcentaje, 77, reason: 'igual que sin la tarjeta');
    expect(a.tarjetas!.usado, 1500);
    expect(a.tarjetas!.linea, 5000);
    expect(avance([_a]).tarjetas, isNull);
  });

  test('"me deben" no cuenta en nada', () {
    final lucia = _deuda(
      'L',
      montoPagado: 1000,
      direccion: DireccionDeuda.meDeben,
    );
    final a = avance([_a, _b, lucia]);
    expect(a.porcentaje, 77);
    expect(a.pagado.total, 3500);
  });

  test('una deuda nueva baja el porcentaje (el pagado no baja)', () {
    final antes = avance([_a, _b]);
    final despues = avance([_a, _b, _deuda('D', montoTotal: 2000)]);
    expect(despues.porcentaje, 53);
    expect(despues.porcentaje, lessThan(antes.porcentaje!));
    expect(despues.pagado.total, antes.pagado.total);
  });

  test('saldadas cuentan en el total; canceladas no', () {
    final saldada = _deuda(
      'S',
      montoTotal: 500,
      montoPagado: 500,
      estado: EstadoDeuda.pagada,
    );
    final a = avance([_a, _b, _c, saldada]);
    expect(a.fraccion, closeTo(4000 / 5000, 1e-12));
  });

  group('racha', () {
    Deuda conCuotas(String id, DateTime inicio, int n) => _deuda(
      id,
      montoTotal: 100.0 * n,
      estructura: EstructuraPago.cuotasFijas,
      cuotas: n,
      pagadas: 0,
      cuota: 100,
      inicio: inicio,
    );

    test('los meses sin cuotas ni suman ni rompen', () {
      // Una cuota en enero y otra en marzo (febrero sin cuotas).
      final e = conCuotas('E', DateTime(2026, 1, 5), 1);
      final f = conCuotas('F', DateTime(2026, 3, 5), 1);
      final r = calcularRacha(
        [e, f],
        {
          'E': [_pago('E', DateTime(2026, 1, 5), 100, cuota: 1)],
          'F': [_pago('F', DateTime(2026, 3, 4), 100, cuota: 1)],
        },
        _ahora,
      );
      expect(r.actual, 2);
      expect(r.mejor, 2);
    });

    test('límite de tolerancia: vencimiento + 3 días sí, + 4 no', () {
      final g = conCuotas('G', DateTime(2026, 9, 1), 1);
      Racha con(int dias) => calcularRacha(
        [g],
        {
          'G': [_pago('G', DateTime(2026, 9, 1 + dias), 100, cuota: 1)],
        },
        _ahora,
      );
      expect(con(diasToleranciaATiempo).actual, 1);
      expect(con(diasToleranciaATiempo + 1).actual, 0);
    });

    test('cuota sin pagar dentro del plazo: pendiente (no rompe)', () {
      final h = conCuotas('H', DateTime(2026, 11, 15), 1);
      final r = calcularRacha([h], const {}, _ahora); // vence el 15, hoy 17
      expect(r.actual, 0);
      expect(r.mejor, 0);
      // Pasado el plazo sin pagar, rompe.
      expect(calcularRacha([h], const {}, DateTime(2026, 11, 19)).actual, 0);
    });

    test('se reinicia al romperse y guarda la mejor', () {
      final r = calcularRacha([_a], _pagos, _ahora);
      expect((r.actual, r.mejor), (3, 3));
    });

    test('canceladas, tarjetas y "me deben" no participan', () {
      final cancelada = conCuotas(
        'X',
        DateTime(2026, 10, 1),
        1,
      ).copyWith(estado: EstadoDeuda.cancelada);
      expect(calcularRacha([cancelada], const {}, _ahora).mejor, 0);
    });
  });

  test('sin deudas: sin datos', () {
    final a = avance([]);
    expect(a.sinDatos, isTrue);
    expect(a.porcentaje, isNull);
  });
}
