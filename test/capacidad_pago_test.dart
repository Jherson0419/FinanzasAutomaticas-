import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/capacidad_pago.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';

/// Fase 86 (B) — capacidad de pago. Fase 87 (A): la estimación segura es
/// el MÍNIMO, entre los meses, de (ingreso − gasto − colchón de ese mes),
/// menos los mínimos (antes mezclaba el peor ingreso con el mayor gasto de
/// meses distintos).
///
/// Script Python independiente (Decimal + statistics.median, sin el código
/// de la app):
///   caso colchón 10 %: márgenes [1400.00, 150.00, 820.00]
///     → segura −500.00, típica 570.00
///   caso colchón 0 %:  márgenes [1800, 400, 1200] → segura −250, típica 950
///   caso colchón 20 %: márgenes [1000.00, −100.00, 440.00]
///     → segura −750.00, típica 190.00
///   demo: ingresos [3600, 3200, 3800], gastos [1900, 1750, 1850],
///         mínimos 770 → márgenes [1340.00, 1130.00, 1570.00]
///     → segura 360.00, típica 620.00
var _n = 0;
Transaccion _t(
  DateTime fecha,
  TipoTransaccion tipo,
  double monto, {
  Moneda moneda = Moneda.pen,
  String cuentaId = 'c1',
}) => Transaccion(
  id: 't${_n++}',
  cuentaId: cuentaId,
  categoriaId: tipo.esTransferencia ? null : 'cat',
  monto: monto,
  moneda: moneda,
  tipo: tipo,
  concepto: '',
  metodoPago: MetodoPago.efectivo,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: fecha,
  transferenciaId: tipo.esTransferencia ? 'tr' : null,
);

/// Un mes (año 2026, [mes]) con un ingreso y un gasto.
List<Transaccion> _mes(int mes, double ingreso, double gasto) => [
  _t(DateTime(2026, mes, 1, 9), TipoTransaccion.ingreso, ingreso),
  _t(DateTime(2026, mes, 15), TipoTransaccion.gasto, gasto),
];

Deuda _deuda(
  String id,
  double minimo, {
  Moneda moneda = Moneda.pen,
  String? cuentaId,
}) => Deuda(
  cuentaId: cuentaId,
  id: id,
  nombreDeuda: id,
  tipoDeuda: TipoDeuda.deudaInformal,
  tipoAcreedor: TipoAcreedor.personaNatural,
  nombreAcreedor: 'Ana',
  moneda: moneda,
  montoTotal: 5000,
  montoPagado: 0,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  pagoMinimo: minimo,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

void main() {
  // "Hoy" a mitad de mayo: abril, marzo y febrero son los meses completos.
  final ahora = DateTime(2026, 5, 14);
  final deudas = [_deuda('a', 400), _deuda('b', 250)]; // mínimos 650

  CapacidadCalculada calcular(
    List<Transaccion> txs, {
    double colchon = colchonPorDefecto,
    List<Deuda>? conDeudas,
  }) =>
      calcularCapacidadPago(
            transacciones: txs,
            deudas: conDeudas ?? deudas,
            ahora: ahora,
            colchon: colchon,
          )
          as CapacidadCalculada;

  final variable = [
    ..._mes(2, 4000, 2200),
    ..._mes(3, 2500, 2100), // mes bajo de ingresos
    ..._mes(4, 3800, 2600),
  ];

  test('caso verificado: ingreso variable → seguro < típico; el seguro '
      'manda y aquí no alcanza', () {
    final c = calcular(variable);
    expect(c.meses, hasLength(3));
    // El mes más ajustado es marzo (2500 − 2100 − 250 = 150).
    expect(c.mesMasAjustado.mes, DateTime(2026, 3));
    expect(c.colchonSeguro, closeTo(250, 1e-9));
    expect(c.ingresoMediano, 3800);
    expect(c.gastoMediano, 2200);
    expect(c.minimos, 650);
    expect(c.seguro, closeTo(-500, 1e-9));
    expect(c.tipico, closeTo(570, 1e-9));
    expect(c.seguro, lessThan(c.tipico));
    expect(c.noAlcanza, isTrue);
    expect(c.faltante, closeTo(500, 1e-9));
    expect(c.recomendado, 0, reason: 'nunca un extra negativo');
    // Fase 87: la típica sí alcanza → mensaje y opción "arriesgada".
    expect(c.soloAlcanzaEnMesTipico, isTrue);
    expect(c.tipicoRedondeado, 570);
  });

  test('caso de la demo: seguro 360, típico 620, recomienda 360', () {
    final c = calcular(
      [..._mes(2, 3600, 1900), ..._mes(3, 3200, 1750), ..._mes(4, 3800, 1850)],
      conDeudas: [_deuda('a', 440), _deuda('b', 210), _deuda('c', 120)],
    );
    expect(c.seguro, closeTo(360, 1e-9));
    expect(c.tipico, closeTo(620, 1e-9));
    expect(c.noAlcanza, isFalse);
    expect(c.soloAlcanzaEnMesTipico, isFalse);
    expect(c.recomendado, 360);
  });

  test('segura exactamente 0: no alcanza (≤ 0) y no recomienda nada', () {
    // 3000 − 2000 − 300 = 700 en ambos meses; mínimos 700 → segura 0.
    final c = calcular(
      [..._mes(3, 3000, 2000), ..._mes(4, 3000, 2000)],
      conDeudas: [_deuda('a', 700)],
    );
    expect(c.seguro, closeTo(0, 1e-9));
    expect(c.noAlcanza, isTrue);
    expect(c.recomendado, 0);
    expect(c.soloAlcanzaEnMesTipico, isFalse, reason: 'la típica es 0');
  });

  test('ni la típica alcanza: sin opción arriesgada', () {
    final c = calcular([..._mes(3, 1000, 900), ..._mes(4, 1000, 900)]);
    expect(c.tipico, lessThan(0));
    expect(c.soloAlcanzaEnMesTipico, isFalse);
    expect(c.tipicoRedondeado, 0);
  });

  group('Fase 87: mínimos de tarjeta', () {
    // Ingreso 3000 y gasto total 1000 por mes; la tarjeta (mínimo 120)
    // vive en la cuenta "visa".
    List<Transaccion> conCompras(double porMes) => [
      for (final mes in [2, 3, 4]) ...[
        _t(DateTime(2026, mes, 1), TipoTransaccion.ingreso, 3000),
        _t(DateTime(2026, mes, 5), TipoTransaccion.gasto, 1000 - porMes),
        if (porMes > 0)
          _t(
            DateTime(2026, mes, 6),
            TipoTransaccion.gasto,
            porMes,
            cuentaId: 'visa',
          ),
      ],
    ];
    final conTarjeta = [
      _deuda('a', 400),
      _deuda('Visa', 120, cuentaId: 'visa'),
    ];

    test('compras promedio ≥ mínimo → el mínimo no se resta', () {
      final c = calcular(conCompras(150), conDeudas: conTarjeta);
      expect(c.minimos, 400);
      expect(c.tarjetasExcluidas.single.nombre, 'Visa');
      expect(c.tarjetasExcluidas.single.gastoPromedio, closeTo(150, 1e-9));
    });

    test('límite: compras promedio = mínimo → se excluye', () {
      final c = calcular(conCompras(120), conDeudas: conTarjeta);
      expect(c.minimos, 400);
      expect(c.tarjetasExcluidas, hasLength(1));
    });

    test('compras promedio < mínimo → el mínimo sí se resta', () {
      final c = calcular(conCompras(119.99), conDeudas: conTarjeta);
      expect(c.minimos, 520);
      expect(c.tarjetasExcluidas, isEmpty);
      expect(calcular(conCompras(0), conDeudas: conTarjeta).minimos, 520);
    });

    test('una deuda que no es tarjeta nunca se excluye', () {
      final c = calcular(conCompras(900), conDeudas: [_deuda('a', 400)]);
      expect(c.minimos, 400);
      expect(c.tarjetasExcluidas, isEmpty);
    });

    test('compras fuera de la ventana no cuentan', () {
      final txs = [
        ...conCompras(0),
        _t(
          DateTime(2026, 5, 2), // mes en curso
          TipoTransaccion.gasto,
          5000,
          cuentaId: 'visa',
        ),
      ];
      expect(calcular(txs, conDeudas: conTarjeta).minimos, 520);
    });
  });

  test('el colchón se puede cambiar', () {
    expect(calcular(variable, colchon: 0).seguro, closeTo(-250, 1e-9));
    expect(calcular(variable, colchon: 0).tipico, closeTo(950, 1e-9));
    expect(calcular(variable, colchon: 0.2).seguro, closeTo(-750, 1e-9));
    expect(calcular(variable, colchon: 0.2).tipico, closeTo(190, 1e-9));
    expect(
      () => calcularCapacidadPago(
        transacciones: variable,
        deudas: deudas,
        ahora: ahora,
        colchon: 1,
      ),
      throwsArgumentError,
    );
  });

  test('excluye el mes en curso y los meses de más de 6 atrás', () {
    final c = calcular([
      ...variable,
      ..._mes(5, 100, 9000), // mes en curso
      ..._mes(1, 1, 1), // enero: dentro de la ventana de 6
      _t(DateTime(2025, 10, 5), TipoTransaccion.ingreso, 1), // 7 meses
    ]);
    expect(c.meses.map((m) => m.mes.month), [1, 2, 3, 4]);
  });

  test('las transferencias nunca cuentan', () {
    final conTransferencias = [
      ...variable,
      _t(DateTime(2026, 3, 10), TipoTransaccion.transferenciaEntrada, 9000),
      _t(DateTime(2026, 3, 10), TipoTransaccion.transferenciaSalida, 9000),
    ];
    final a = calcular(variable);
    final b = calcular(conTransferencias);
    expect(b.seguro, a.seguro);
    expect(b.tipico, a.tipico);
    // Un mes con SOLO transferencias no es un mes con datos.
    final sinDatos = calcularCapacidadPago(
      transacciones: [
        ..._mes(4, 3000, 1000),
        _t(DateTime(2026, 3, 2), TipoTransaccion.transferenciaSalida, 50),
      ],
      deudas: deudas,
      ahora: ahora,
    );
    expect(sinDatos, isA<CapacidadSinDatos>());
  });

  test('datos insuficientes: menos de 2 meses completos → sin datos', () {
    final r = calcularCapacidadPago(
      transacciones: [..._mes(4, 3000, 1000), ..._mes(5, 3000, 1000)],
      deudas: deudas,
      ahora: ahora,
    );
    expect(r, isA<CapacidadSinDatos>());
    expect((r as CapacidadSinDatos).mesesConDatos, 1);
    expect(
      calcularCapacidadPago(transacciones: [], deudas: deudas, ahora: ahora),
      isA<CapacidadSinDatos>(),
    );
    // Justo 2 meses: ya se calcula (umbral).
    expect(
      calcularCapacidadPago(
        transacciones: [..._mes(3, 3000, 1000), ..._mes(4, 3000, 1000)],
        deudas: deudas,
        ahora: ahora,
      ),
      isA<CapacidadCalculada>(),
    );
  });

  test('multimoneda: no se mezcla; se avisa de las otras monedas', () {
    final c = calcular(
      [
        ...variable,
        ..._mes(
          3,
          99999,
          1,
        ).map((t) => _t(t.fecha, t.tipo, t.monto, moneda: Moneda.usd)),
      ],
      conDeudas: [
        ...deudas,
        _deuda('usd', 300, moneda: Moneda.usd),
      ],
    );
    expect(c.moneda, Moneda.pen);
    expect(c.otrasMonedas, [Moneda.usd]);
    expect(c.seguro, closeTo(-500, 1e-9));
    expect(c.minimos, 650, reason: 'el mínimo en dólares no se suma');
  });

  test('mínimos: solo lo que debo y activo; "me deben" y pagadas no', () {
    final c = calcular(
      variable,
      conDeudas: [
        ...deudas,
        Deuda(
          id: 'lucia',
          nombreDeuda: 'Lucía',
          tipoDeuda: TipoDeuda.deudaInformal,
          tipoAcreedor: TipoAcreedor.personaNatural,
          nombreAcreedor: 'Lucía',
          moneda: Moneda.pen,
          montoTotal: 380,
          montoPagado: 0,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          pagoMinimo: 100,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
          direccion: DireccionDeuda.meDeben,
        ),
      ],
    );
    expect(c.minimos, 650);
  });

  test('mediana con número par de meses = promedio de los centrales', () {
    expect(mediana([1, 4, 2, 3]), 2.5);
    expect(mediana([5]), 5);
  });
}
