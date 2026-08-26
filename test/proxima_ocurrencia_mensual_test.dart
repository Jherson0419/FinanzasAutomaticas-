import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/proxima_ocurrencia_mensual.dart';

void main() {
  test('si la ancla ya es >= desde, la próxima ocurrencia es la ancla misma', () {
    final ancla = DateTime(2026, 8, 15);
    expect(proximaOcurrenciaMensual(ancla, DateTime(2026, 8, 10)), ancla);
    expect(proximaOcurrenciaMensual(ancla, DateTime(2026, 8, 15)), ancla);
  });

  test('si la ancla ya pasó, avanza un mes exacto', () {
    final ancla = DateTime(2026, 8, 15);
    expect(
      proximaOcurrenciaMensual(ancla, DateTime(2026, 8, 20)),
      DateTime(2026, 9, 15),
    );
  });

  test('avanza varios meses de una sola vez si hace falta', () {
    final ancla = DateTime(2025, 1, 10);
    expect(
      proximaOcurrenciaMensual(ancla, DateTime(2026, 8, 20)),
      DateTime(2026, 9, 10),
    );
  });

  test('respeta fin de mes: una ancla el 31 de enero cae el 28/29 de febrero', () {
    final ancla = DateTime(2026, 1, 31);
    expect(
      proximaOcurrenciaMensual(ancla, DateTime(2026, 2, 1)),
      DateTime(2026, 2, 28),
    );
  });

  test('cruza de año sin problema', () {
    final ancla = DateTime(2026, 12, 20);
    expect(
      proximaOcurrenciaMensual(ancla, DateTime(2027, 1, 5)),
      DateTime(2027, 1, 20),
    );
  });

  test(
    'Fase 62: corte y pago avanzan de forma independiente desde su propia '
    'ancla — el pago el 27 de un mes y el corte el 7 del mes siguiente '
    'mantienen esa relación aunque 7 < 27',
    () {
      final anclaCorte = DateTime(2026, 1, 7);
      final anclaPago = DateTime(2026, 1, 27);
      // Antes del 7: en agosto ninguna de las 2 ocurrencias pasó todavía,
      // así que ambas caen dentro del mismo mes (si "hoy" fuera, por
      // ejemplo, el 10, el corte de agosto ya habría pasado y su próxima
      // ocurrencia saltaría sola a septiembre — comportamiento correcto,
      // pero no es lo que este test puntual quiere ilustrar).
      final hoy = DateTime(2026, 8, 1);

      final proximoCorte = proximaOcurrenciaMensual(anclaCorte, hoy);
      final proximoPago = proximaOcurrenciaMensual(anclaPago, hoy);

      expect(proximoCorte, DateTime(2026, 8, 7));
      expect(proximoPago, DateTime(2026, 8, 27));
      // El corte cae ANTES del pago dentro del mismo mes, tal como en la
      // ancla original — nunca se invierten por comparar solo el día.
      expect(proximoCorte.isBefore(proximoPago), isTrue);
    },
  );

  test('una ancla en el futuro lejano no se toca hasta que llegue su mes', () {
    final ancla = DateTime(2030, 3, 5);
    expect(proximaOcurrenciaMensual(ancla, DateTime(2026, 8, 10)), ancla);
  });
}
