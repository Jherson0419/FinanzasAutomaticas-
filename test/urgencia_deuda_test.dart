import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/urgencia_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';

DeudaActivaResumen _deuda({
  required String id,
  bool enMora = false,
  DateTime? fechaVencimientoReal,
}) {
  return DeudaActivaResumen(
    id: id,
    nombreDeuda: 'Deuda $id',
    estructuraPago: EstructuraPago.cuotasFijas,
    proximaFechaPago: fechaVencimientoReal,
    enMora: enMora,
    diasMora: null,
    montoPagado: 0,
    montoTotal: 100,
    montoCuota: 50,
    moneda: Moneda.pen,
    fechaVencimientoReal: fechaVencimientoReal,
  );
}

void main() {
  final hoy = DateTime(2026, 3, 15);

  group('urgenciaDeuda', () {
    test('enMora siempre es vencida, sin importar fechaVencimientoReal', () {
      final deuda = _deuda(
        id: 'd1',
        enMora: true,
        fechaVencimientoReal: hoy.add(const Duration(days: 30)),
      );
      expect(urgenciaDeuda(deuda, hoy), UrgenciaDeuda.vencida);
    });

    test('sin fechaVencimientoReal (pagoLibre sin cuenta) es normal', () {
      final deuda = _deuda(id: 'd1');
      expect(urgenciaDeuda(deuda, hoy), UrgenciaDeuda.normal);
    });

    test('vence hoy (0 días) es porVencer', () {
      final deuda = _deuda(id: 'd1', fechaVencimientoReal: hoy);
      expect(urgenciaDeuda(deuda, hoy), UrgenciaDeuda.porVencer);
    });

    test('vence en exactamente 3 días es porVencer (umbral inclusivo)', () {
      final deuda = _deuda(
        id: 'd1',
        fechaVencimientoReal: hoy.add(const Duration(days: 3)),
      );
      expect(urgenciaDeuda(deuda, hoy), UrgenciaDeuda.porVencer);
    });

    test('vence en 4 días es normal (fuera del umbral)', () {
      final deuda = _deuda(
        id: 'd1',
        fechaVencimientoReal: hoy.add(const Duration(days: 4)),
      );
      expect(urgenciaDeuda(deuda, hoy), UrgenciaDeuda.normal);
    });
  });

  group('ordenarDeudasActivasPorVencimiento', () {
    test(
      'vencidas primero, luego por vencer, luego el resto en su orden original',
      () {
        final normal1 = _deuda(
          id: 'normal1',
          fechaVencimientoReal: hoy.add(const Duration(days: 30)),
        );
        final porVencer1 = _deuda(
          id: 'porVencer1',
          fechaVencimientoReal: hoy.add(const Duration(days: 2)),
        );
        final vencida1 = _deuda(id: 'vencida1', enMora: true);
        final normal2 = _deuda(id: 'normal2');
        final vencida2 = _deuda(id: 'vencida2', enMora: true);
        final porVencer2 = _deuda(
          id: 'porVencer2',
          fechaVencimientoReal: hoy.add(const Duration(days: 1)),
        );

        final ordenadas = ordenarDeudasActivasPorVencimiento(
          [normal1, porVencer1, vencida1, normal2, vencida2, porVencer2],
          hoy,
        );

        expect(ordenadas.map((d) => d.id).toList(), [
          'vencida1',
          'vencida2',
          'porVencer1',
          'porVencer2',
          'normal1',
          'normal2',
        ]);
      },
    );

    test('lista sin ninguna urgente mantiene el orden original intacto', () {
      final a = _deuda(id: 'a');
      final b = _deuda(id: 'b');
      final c = _deuda(id: 'c');

      final ordenadas = ordenarDeudasActivasPorVencimiento([a, b, c], hoy);

      expect(ordenadas.map((d) => d.id).toList(), ['a', 'b', 'c']);
    });
  });
}
