import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/movimientos.dart';

/// Fase 81 — dominio puro de Movimientos.
const _categorias = [
  Categoria(
    id: 'comida',
    nombre: 'Comida',
    tipo: TipoCategoria.gasto,
    iconName: 'restaurant',
  ),
  Categoria(
    id: 'transporte',
    nombre: 'Transporte',
    tipo: TipoCategoria.gasto,
    iconName: 'directions_bus',
  ),
  Categoria(
    id: 'servicios',
    nombre: 'Servicios',
    tipo: TipoCategoria.gasto,
    iconName: 'bolt',
  ),
  Categoria(
    id: 'salud',
    nombre: 'Salud',
    tipo: TipoCategoria.gasto,
    iconName: 'health_and_safety',
  ),
  Categoria(
    id: 'hogar',
    nombre: 'Hogar',
    tipo: TipoCategoria.gasto,
    iconName: 'home',
  ),
  Categoria(
    id: 'sueldo',
    nombre: 'Sueldo',
    tipo: TipoCategoria.ingreso,
    iconName: 'payments',
  ),
];

const _cuentas = [
  Cuenta(
    id: 'efectivo',
    nombre: 'Efectivo',
    tipo: TipoCuenta.efectivo,
    moneda: Moneda.pen,
    saldoActual: 0,
  ),
  Cuenta(
    id: 'bcp',
    nombre: 'Débito BCP',
    tipo: TipoCuenta.debito,
    moneda: Moneda.pen,
    saldoActual: 0,
  ),
  Cuenta(
    id: 'usd',
    nombre: 'Ahorros dólares',
    tipo: TipoCuenta.debito,
    moneda: Moneda.usd,
    saldoActual: 0,
  ),
];

var _n = 0;
Transaccion _tx({
  required String concepto,
  required double monto,
  required DateTime fecha,
  String categoria = 'comida',
  String cuenta = 'efectivo',
  TipoTransaccion tipo = TipoTransaccion.gasto,
  Moneda moneda = Moneda.pen,
}) => Transaccion(
  id: 'tx${_n++}',
  cuentaId: cuenta,
  categoriaId: categoria,
  monto: monto,
  moneda: moneda,
  tipo: tipo,
  concepto: concepto,
  metodoPago: MetodoPago.efectivo,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: fecha,
);

List<MovimientoDetallado> _detallar(List<Transaccion> txs) =>
    detallarMovimientos(txs, _categorias, _cuentas);

Iterable<String> _conceptos(List<MovimientoDetallado> l) =>
    l.map((m) => m.transaccion.concepto);

void main() {
  group('normalizarTexto', () {
    test('minúsculas, sin tildes ni eñes, espacios colapsados', () {
      expect(normalizarTexto('  Café   con LECHE '), 'cafe con leche');
      expect(normalizarTexto('Ñandú Pingüino ÁÉÍÓÚ'), 'nandu pinguino aeiou');
    });
  });

  group('filtrarMovimientos', () {
    final nov = DateTime(2026, 11, 10, 12);
    final movimientos = _detallar([
      _tx(concepto: 'Café de la mañana', monto: 8, fecha: nov),
      _tx(
        concepto: 'Taxi al trabajo',
        monto: 14.5,
        fecha: nov,
        categoria: 'transporte',
        cuenta: 'bcp',
      ),
      _tx(
        concepto: 'Sueldo noviembre',
        monto: 3200,
        fecha: nov,
        categoria: 'sueldo',
        cuenta: 'bcp',
        tipo: TipoTransaccion.ingreso,
      ),
      _tx(
        concepto: 'Recibo',
        monto: 160,
        fecha: nov,
        categoria: 'servicios',
        cuenta: 'bcp',
      ),
    ]);

    test('"cafe" encuentra "Café" (tildes y mayúsculas)', () {
      expect(_conceptos(filtrarMovimientos(movimientos, texto: 'cafe')), [
        'Café de la mañana',
      ]);
      expect(_conceptos(filtrarMovimientos(movimientos, texto: 'MANANA')), [
        'Café de la mañana',
      ]);
    });

    test('busca también en el nombre de la categoría y de la cuenta', () {
      expect(_conceptos(filtrarMovimientos(movimientos, texto: 'servicios')), [
        'Recibo',
      ]);
      expect(
        _conceptos(
          filtrarMovimientos(movimientos, texto: 'debito bcp'),
        ).toSet(),
        {'Taxi al trabajo', 'Sueldo noviembre', 'Recibo'},
      );
    });

    test('combina texto + tipo + cuenta + categoría', () {
      expect(
        _conceptos(
          filtrarMovimientos(
            movimientos,
            texto: 'bcp',
            tipo: TipoTransaccion.gasto,
          ),
        ).toSet(),
        {'Taxi al trabajo', 'Recibo'},
      );
      expect(
        _conceptos(
          filtrarMovimientos(
            movimientos,
            tipo: TipoTransaccion.ingreso,
            cuentaId: 'bcp',
          ),
        ),
        ['Sueldo noviembre'],
      );
      expect(
        _conceptos(
          filtrarMovimientos(
            movimientos,
            cuentaId: 'bcp',
            categoriaId: 'transporte',
          ),
        ),
        ['Taxi al trabajo'],
      );
      expect(
        filtrarMovimientos(movimientos, texto: 'cafe', cuentaId: 'bcp'),
        isEmpty,
      );
    });

    test('texto vacío o solo espacios no filtra', () {
      expect(filtrarMovimientos(movimientos, texto: '   '), hasLength(4));
    });

    test(
      'límites del mes: incluye el 1.º 00:00 y el último 23:59, excluye el 1.º del siguiente',
      () {
        final lista = _detallar([
          _tx(
            concepto: 'fin octubre',
            monto: 1,
            fecha: DateTime(2026, 10, 31, 23, 59, 59),
          ),
          _tx(
            concepto: 'inicio noviembre',
            monto: 1,
            fecha: DateTime(2026, 11, 1),
          ),
          _tx(
            concepto: 'fin noviembre',
            monto: 1,
            fecha: DateTime(2026, 11, 30, 23, 59, 59),
          ),
          _tx(
            concepto: 'inicio diciembre',
            monto: 1,
            fecha: DateTime(2026, 12, 1),
          ),
        ]);
        final (desde, hasta) = rangoDelMes(DateTime(2026, 11, 16));
        expect(desde, DateTime(2026, 11, 1));
        expect(hasta, DateTime(2026, 12, 1));
        expect(
          _conceptos(
            filtrarMovimientos(lista, desde: desde, hasta: hasta),
          ).toSet(),
          {'inicio noviembre', 'fin noviembre'},
        );
      },
    );

    test('rangoDelMes cruza el año en diciembre', () {
      final (desde, hasta) = rangoDelMes(DateTime(2026, 12, 5));
      expect(desde, DateTime(2026, 12, 1));
      expect(hasta, DateTime(2027, 1, 1));
    });
  });

  group('agruparPorDia', () {
    final ahora = DateTime(2026, 11, 16, 18);

    test(
      'grupos Hoy / Ayer / fecha, del más reciente al más antiguo, con subtotal neto',
      () {
        final grupos = agruparPorDia(
          _detallar([
            _tx(
              concepto: 'Almuerzo',
              monto: 18,
              fecha: DateTime(2026, 11, 16, 13),
            ),
            _tx(
              concepto: 'Sueldo',
              monto: 3200,
              fecha: DateTime(2026, 11, 15, 9),
              categoria: 'sueldo',
              tipo: TipoTransaccion.ingreso,
            ),
            _tx(
              concepto: 'Taxi',
              monto: 14.5,
              fecha: DateTime(2026, 11, 15, 8),
              categoria: 'transporte',
            ),
            _tx(concepto: 'Cine', monto: 30, fecha: DateTime(2026, 11, 12, 20)),
          ]),
          ahora: ahora,
        );
        expect(grupos.map((g) => g.tipoDia), [
          TipoDia.hoy,
          TipoDia.ayer,
          TipoDia.otro,
        ]);
        expect(grupos.map((g) => g.dia), [
          DateTime(2026, 11, 16),
          DateTime(2026, 11, 15),
          DateTime(2026, 11, 12),
        ]);
        expect(grupos[0].subtotalNeto, {Moneda.pen: -18});
        expect(grupos[1].subtotalNeto, {Moneda.pen: 3185.5});
        expect(_conceptos(grupos[1].movimientos), ['Sueldo', 'Taxi']);
      },
    );

    test(
      'un día sin movimientos no genera grupo; lista vacía → sin grupos',
      () {
        final grupos = agruparPorDia(
          _detallar([
            _tx(concepto: 'a', monto: 1, fecha: DateTime(2026, 11, 16)),
            _tx(concepto: 'b', monto: 1, fecha: DateTime(2026, 11, 13)),
          ]),
          ahora: ahora,
        );
        expect(grupos.map((g) => g.dia.day), [16, 13]);
        expect(agruparPorDia(const [], ahora: ahora), isEmpty);
      },
    );

    test('subtotal por moneda sin convertir', () {
      final grupos = agruparPorDia(
        _detallar([
          _tx(concepto: 'soles', monto: 20, fecha: DateTime(2026, 11, 16)),
          _tx(
            concepto: 'dólares',
            monto: 5,
            fecha: DateTime(2026, 11, 16),
            cuenta: 'usd',
            moneda: Moneda.usd,
          ),
        ]),
        ahora: ahora,
      );
      expect(grupos.single.subtotalNeto, {Moneda.pen: -20, Moneda.usd: -5});
    });
  });

  group('resumenGastoPorCategoria', () {
    final f = DateTime(2026, 11, 10);

    test('top 3 + "Otros", con porcentajes que suman 100', () {
      final resumen = resumenGastoPorCategoria(
        _detallar([
          _tx(concepto: 'c', monto: 1075, fecha: f),
          _tx(concepto: 't', monto: 666, fecha: f, categoria: 'transporte'),
          _tx(concepto: 's', monto: 461, fecha: f, categoria: 'servicios'),
          _tx(concepto: 'h', monto: 200, fecha: f, categoria: 'hogar'),
          _tx(concepto: 'x', monto: 158, fecha: f, categoria: 'salud'),
          _tx(
            concepto: 'ingreso ignorado',
            monto: 9999,
            fecha: f,
            categoria: 'sueldo',
            tipo: TipoTransaccion.ingreso,
          ),
        ]),
      ).single;

      expect(resumen.moneda, Moneda.pen);
      expect(resumen.total, 2560);
      expect(resumen.porciones.map((p) => p.nombre), [
        'Comida',
        'Transporte',
        'Servicios',
        'Otros',
      ]);
      expect(resumen.porciones.last.esOtros, isTrue);
      expect(resumen.porciones.last.monto, 358);
      expect(
        resumen.porciones.fold(0.0, (s, p) => s + p.porcentaje),
        closeTo(100, 1e-9),
      );
      expect(resumen.porciones.fold(0, (s, p) => s + p.porcentajeEntero), 100);
      expect(resumen.porciones.map((p) => p.porcentajeEntero), [
        42,
        26,
        18,
        14,
      ]);
    });

    test('los enteros suman 100 aun cuando el redondeo simple no', () {
      // Tres partes iguales: 33.33… cada una → 34 + 33 + 33.
      final resumen = resumenGastoPorCategoria(
        _detallar([
          _tx(concepto: 'a', monto: 10, fecha: f),
          _tx(concepto: 'b', monto: 10, fecha: f, categoria: 'transporte'),
          _tx(concepto: 'c', monto: 10, fecha: f, categoria: 'servicios'),
        ]),
      ).single;
      expect(
        resumen.porciones,
        hasLength(3),
        reason: 'sin "Otros" si no sobra nada',
      );
      expect(resumen.porciones.fold(0, (s, p) => s + p.porcentajeEntero), 100);
    });

    test('monedas mezcladas: un resumen por moneda, sin convertir', () {
      final resumenes = resumenGastoPorCategoria(
        _detallar([
          _tx(
            concepto: 'usd',
            monto: 50,
            fecha: f,
            cuenta: 'usd',
            moneda: Moneda.usd,
          ),
          _tx(concepto: 'pen', monto: 100, fecha: f),
          _tx(concepto: 'pen2', monto: 300, fecha: f, categoria: 'transporte'),
        ]),
      );
      expect(resumenes.map((r) => r.moneda), [Moneda.pen, Moneda.usd]);
      expect(resumenes[0].total, 400);
      expect(resumenes[1].total, 50);
      expect(resumenes[1].porciones.single.porcentajeEntero, 100);
    });

    test('sin gastos → lista vacía', () {
      expect(
        resumenGastoPorCategoria(
          _detallar([
            _tx(
              concepto: 'i',
              monto: 1,
              fecha: f,
              categoria: 'sueldo',
              tipo: TipoTransaccion.ingreso,
            ),
          ]),
        ),
        isEmpty,
      );
    });
  });

  test(
    'detallarMovimientos ordena por fecha desc y tolera ids desconocidos',
    () {
      final lista = detallarMovimientos(
        [
          _tx(concepto: 'viejo', monto: 1, fecha: DateTime(2026, 1, 1)),
          _tx(
            concepto: 'nuevo',
            monto: 1,
            fecha: DateTime(2026, 2, 1),
            categoria: 'no-existe',
            cuenta: 'no-existe',
          ),
        ],
        _categorias,
        _cuentas,
      );
      expect(_conceptos(lista), ['nuevo', 'viejo']);
      expect(lista.first.categoriaNombre, 'Sin categoría');
      expect(lista.first.cuentaNombre, '');
    },
  );
}
