import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/proximos_pagos.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';

/// Fase 81 — orden de "Próximos pagos" / hub y progreso de "Tus deudas".
DeudaActivaResumen _d(
  String id, {
  DateTime? fecha,
  bool enMora = false,
  double pagado = 0,
  double total = 100,
  Moneda moneda = Moneda.pen,
  String? cuentaId,
}) => DeudaActivaResumen(
  id: id,
  nombreDeuda: id,
  estructuraPago: EstructuraPago.cuotasFijas,
  proximaFechaPago: fecha,
  enMora: enMora,
  diasMora: enMora ? 3 : null,
  montoPagado: pagado,
  montoTotal: total,
  totalAPagar: total,
  montoCuota: 10,
  moneda: moneda,
  fechaVencimientoReal: fecha,
  cuentaId: cuentaId,
);

void main() {
  final ahora = DateTime(2026, 11, 16, 10);

  test('vencidas → por vencer → resto por fecha, sin fecha al final', () {
    final orden = ordenarPorUrgenciaYFecha([
      _d('sin fecha'),
      _d('lejos', fecha: DateTime(2026, 12, 20)),
      _d('en 5 días', fecha: DateTime(2026, 11, 21)),
      _d('mañana', fecha: DateTime(2026, 11, 17)),
      _d('en mora', enMora: true),
      _d('hoy', fecha: DateTime(2026, 11, 16)),
    ], ahora).map((d) => d.id);
    expect(orden, [
      'en mora',
      'hoy',
      'mañana',
      'en 5 días',
      'lejos',
      'sin fecha',
    ]);
  });

  test('es estable a igual urgencia y fecha', () {
    final f = DateTime(2026, 12, 1);
    expect(
      ordenarPorUrgenciaYFecha([
        _d('a', fecha: f),
        _d('b', fecha: f),
        _d('c', fecha: f),
      ], ahora).map((d) => d.id),
      ['a', 'b', 'c'],
    );
  });

  test('proximosPagos devuelve las 3 más urgentes', () {
    final tres = proximosPagos([
      _d('lejos', fecha: DateTime(2026, 12, 20)),
      _d('mañana', fecha: DateTime(2026, 11, 17)),
      _d('sin fecha'),
      _d('en mora', enMora: true),
    ], ahora);
    expect(tres.map((d) => d.id), ['en mora', 'mañana', 'lejos']);
  });

  group('progresoDeudas', () {
    test('suma pagado / totalAPagar (datos de ejemplo → 59%)', () {
      final p = progresoDeudas([
        _d('préstamo', pagado: 3520, total: 4400),
        _d('laptop', pagado: 630, total: 2520),
        _d('informal', pagado: 100, total: 250),
      ], Moneda.pen);
      expect(p.pagado, 4250);
      expect(p.totalAPagar, 7170);
      expect(p.porcentaje, 59);
    });

    test('excluye la deuda automática de tarjeta y otras monedas', () {
      final p = progresoDeudas([
        _d('a', pagado: 50, total: 100),
        _d('tarjeta', pagado: 1900, total: 2000, cuentaId: 'visa'),
        _d('usd', pagado: 0, total: 999, moneda: Moneda.usd),
      ], Moneda.pen);
      expect(p.porcentaje, 50);
    });

    test('nunca muestra 100% mientras quede algo y 0 sin deudas', () {
      expect(
        progresoDeudas([
          _d('a', pagado: 99.6, total: 100),
        ], Moneda.pen).porcentaje,
        99,
      );
      expect(progresoDeudas(const [], Moneda.pen).fraccion, 0);
    });
  });
}
