import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/costo_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/presentation/screens/deuda_formulario.dart'
    show etiquetaCampoTasa;

/// Fase 82 (E) — costo por deuda.

/// Cálculo INDEPENDIENTE del de producción: suma una a una las cuotas
/// descontadas (sin la fórmula cerrada de la anualidad).
double _valorPresenteSumando(double cuota, int n, double i) {
  var total = 0.0;
  for (var k = 1; k <= n; k++) {
    total += cuota / math.pow(1 + i, k);
  }
  return total;
}

Deuda _cuotas({
  required double capital,
  required double cuota,
  required int n,
  PeriodicidadCuota? periodicidad = PeriodicidadCuota.mensual,
}) => Deuda(
  id: 'd',
  nombreDeuda: 'd',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: capital,
  montoPagado: 0,
  tieneInteres: cuota * n > capital,
  estructuraPago: EstructuraPago.cuotasFijas,
  numeroCuotasTotal: n,
  montoCuota: cuota,
  periodicidadCuotas: periodicidad,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

Deuda _libre({
  bool interes = false,
  double? tasa,
  String? cuentaId,
  DireccionDeuda direccion = DireccionDeuda.debo,
}) => Deuda(
  id: 'l',
  nombreDeuda: 'l',
  tipoDeuda: TipoDeuda.otro,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'x',
  moneda: Moneda.pen,
  montoTotal: 1000,
  montoPagado: 0,
  tieneInteres: interes,
  tasaInteres: tasa,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
  cuentaId: cuentaId,
  direccion: direccion,
);

void main() {
  group('cuotas fijas', () {
    test('caso conocido: 1 % mensual → TEA 12.68 %', () {
      // Cuota de un préstamo de 1,000 al 1 % mensual en 12 cuotas.
      final cuota = 1000 * 0.01 / (1 - math.pow(1.01, -12));
      final tea = tasaEfectivaAnual(
        _cuotas(capital: 1000, cuota: cuota, n: 12),
      )!;
      expect(tea, closeTo(math.pow(1.01, 12) - 1, 1e-6));
      expect(tea, closeTo(0.126825, 1e-6));
    });

    test('la tasa hallada devuelve el capital al descontar las cuotas '
        '(préstamo de ejemplo: 3,800 en 10 × 440)', () {
      final i = tasaPeriodicaDeCuotas(capital: 3800, cuota: 440, n: 10)!;
      expect(_valorPresenteSumando(440, 10, i), closeTo(3800, 0.01));
      final tea = tasaEfectivaAnual(_cuotas(capital: 3800, cuota: 440, n: 10))!;
      expect(tea, closeTo(math.pow(1 + i, 12) - 1, 1e-9));
      // ~2.75 % mensual ≈ 38.5 % anual: un orden de magnitud razonable.
      expect(tea, inInclusiveRange(0.35, 0.42));
    });

    test('laptop de ejemplo (2,000 en 12 × 210): valor presente = capital', () {
      final i = tasaPeriodicaDeCuotas(capital: 2000, cuota: 210, n: 12)!;
      expect(_valorPresenteSumando(210, 12, i), closeTo(2000, 0.01));
    });

    test('sin interés (cuotas suman el capital) → 0 %', () {
      expect(tasaEfectivaAnual(_cuotas(capital: 2520, cuota: 210, n: 12)), 0);
    });

    test('quincenal cuesta más al año que mensual con el mismo flujo', () {
      final mensual = tasaEfectivaAnual(
        _cuotas(capital: 1000, cuota: 90, n: 12),
      )!;
      final quincenal = tasaEfectivaAnual(
        _cuotas(
          capital: 1000,
          cuota: 90,
          n: 12,
          periodicidad: PeriodicidadCuota.quincenal,
        ),
      )!;
      expect(quincenal, greaterThan(mensual));
      // Misma tasa por período, anualizada con 365/15 períodos vs 12.
      final i = tasaPeriodicaDeCuotas(capital: 1000, cuota: 90, n: 12)!;
      expect(quincenal, closeTo(math.pow(1 + i, 365 / 15) - 1, 1e-9));
    });

    test('sin datos suficientes → null', () {
      expect(
        tasaEfectivaAnual(
          _cuotas(capital: 1000, cuota: 90, n: 12, periodicidad: null),
        ),
        isNull,
      );
      expect(tasaPeriodicaDeCuotas(capital: 0, cuota: 90, n: 12), isNull);
    });
  });

  test('Fase 83: la etiqueta del campo dice anual (TEA), como el cálculo', () {
    expect(etiquetaCampoTasa, 'Tasa efectiva anual (TEA %)');
    expect(etiquetaCampoTasa.toLowerCase(), isNot(contains('mensual')));
    // Lo que el usuario escribe en ese campo se usa tal cual como TEA.
    expect(tasaEfectivaAnual(_libre(interes: true, tasa: 48)), 0.48);
  });

  group('pago libre', () {
    test('con tasa: se toma como efectiva anual (24 → 0.24)', () {
      expect(tasaEfectivaAnual(_libre(interes: true, tasa: 24)), 0.24);
    });

    test('sin interés → 0; con interés pero sin tasa → null', () {
      expect(tasaEfectivaAnual(_libre()), 0);
      expect(tasaEfectivaAnual(_libre(interes: true)), isNull);
    });

    test(
      'deuda automática de tarjeta sin tasa → null (no hay TCEA guardada)',
      () {
        expect(tasaEfectivaAnual(_libre(cuentaId: 'visa')), isNull);
      },
    );

    test('"me deben" → 0 (sin interés en esta fase)', () {
      expect(
        tasaEfectivaAnual(
          _libre(interes: true, tasa: 30, direccion: DireccionDeuda.meDeben),
        ),
        0,
      );
    });
  });
}
