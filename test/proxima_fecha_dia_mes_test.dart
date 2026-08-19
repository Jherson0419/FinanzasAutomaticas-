import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/proxima_fecha_dia_mes.dart';

void main() {
  test('si el día todavía no pasó este mes, la próxima fecha es este mes', () {
    final desde = DateTime(2026, 8, 10);
    expect(proximaFecha(15, desde), DateTime(2026, 8, 15));
  });

  test('si el día es exactamente hoy, la próxima fecha es hoy mismo', () {
    final desde = DateTime(2026, 8, 15);
    expect(proximaFecha(15, desde), DateTime(2026, 8, 15));
  });

  test('si el día ya pasó este mes, cae en el mes siguiente', () {
    final desde = DateTime(2026, 8, 20);
    expect(proximaFecha(15, desde), DateTime(2026, 9, 15));
  });

  test('respeta fin de mes: día 31 en un mes de 30 días se recorta', () {
    final desde = DateTime(2026, 4, 5);
    expect(proximaFecha(31, desde), DateTime(2026, 4, 30));
  });

  test('respeta fin de mes cruzando a febrero (no bisiesto)', () {
    final desde = DateTime(2027, 2, 1);
    expect(proximaFecha(31, desde), DateTime(2027, 2, 28));
  });

  test('diciembre a enero cruza de año', () {
    final desde = DateTime(2026, 12, 20);
    expect(proximaFecha(5, desde), DateTime(2027, 1, 5));
  });
}
