import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/proxima_ocurrencia_mensual.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/alerta_tarjeta_credito.dart';
import 'package:finanzas_automaticas/domain/usecases/obtener_alertas_tarjetas_credito.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final List<Cuenta> cuentas;
  _FakeCuentaRepository(this.cuentas);

  @override
  Future<void> actualizar(Cuenta cuenta) async {}
  @override
  Future<void> crear(Cuenta cuenta) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Cuenta?> obtenerPorId(String id) async {
    for (final cuenta in cuentas) {
      if (cuenta.id == id) return cuenta;
    }
    return null;
  }

  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas;
}

/// Fecha completa exactamente [diasDesdeHoy] días a partir de hoy — sirve
/// como ancla de `fechaCorte`/`fechaPago` (Fase 62) sin depender de qué
/// fecha es "hoy" al correr el test.
DateTime _fechaEnNDias(int diasDesdeHoy) =>
    DateTime.now().add(Duration(days: diasDesdeHoy));

Cuenta _tarjeta({
  required String id,
  DateTime? fechaCorte,
  DateTime? fechaPago,
  double saldoActual = 0,
}) {
  return Cuenta(
    id: id,
    nombre: 'Tarjeta $id',
    tipo: TipoCuenta.credito,
    moneda: Moneda.pen,
    saldoActual: saldoActual,
    lineaCredito: 5000,
    fechaCorte: fechaCorte,
    fechaPago: fechaPago,
  );
}

void main() {
  test('no genera alertas si no hay cuentas de crédito', () async {
    final repo = _FakeCuentaRepository([
      const Cuenta(
        id: 'c1',
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 100,
      ),
    ]);

    final alertas = await ObtenerAlertasTarjetasCredito(
      cuentaRepository: repo,
    )();

    expect(alertas, isEmpty);
  });

  test('alerta de corte cuando faltan exactamente 3 días', () async {
    final repo = _FakeCuentaRepository([
      _tarjeta(id: 't1', fechaCorte: _fechaEnNDias(3)),
    ]);

    final alertas = await ObtenerAlertasTarjetasCredito(
      cuentaRepository: repo,
    )();

    expect(alertas, hasLength(1));
    expect(alertas.first.tipo, TipoAlertaTarjeta.corte);
    expect(alertas.first.diasRestantes, 3);
  });

  test(
    'NO alerta cuando faltan 4 días (todavía no entra en el umbral)',
    () async {
      final repo = _FakeCuentaRepository([
        _tarjeta(id: 't1', fechaCorte: _fechaEnNDias(4)),
      ]);

      final alertas = await ObtenerAlertasTarjetasCredito(
        cuentaRepository: repo,
      )();

      expect(alertas, isEmpty);
    },
  );

  test('alerta de pago cuando la fecha de pago es hoy (0 días)', () async {
    final repo = _FakeCuentaRepository([
      _tarjeta(id: 't1', fechaPago: _fechaEnNDias(0)),
    ]);

    final alertas = await ObtenerAlertasTarjetasCredito(
      cuentaRepository: repo,
    )();

    expect(alertas, hasLength(1));
    expect(alertas.first.tipo, TipoAlertaTarjeta.pago);
    expect(alertas.first.diasRestantes, 0);
  });

  test('una tarjeta con corte y pago próximos genera 2 alertas', () async {
    final repo = _FakeCuentaRepository([
      _tarjeta(
        id: 't1',
        fechaCorte: _fechaEnNDias(1),
        fechaPago: _fechaEnNDias(2),
      ),
    ]);

    final alertas = await ObtenerAlertasTarjetasCredito(
      cuentaRepository: repo,
    )();

    expect(alertas, hasLength(2));
    expect(
      alertas.map((a) => a.tipo),
      containsAll([TipoAlertaTarjeta.corte, TipoAlertaTarjeta.pago]),
    );
  });

  test(
    'la fecha de la alerta coincide con proximaOcurrenciaMensual(fechaCorte, hoy)',
    () async {
      final hoy = DateTime.now();
      final fechaCorte = _fechaEnNDias(2);
      final repo = _FakeCuentaRepository([
        _tarjeta(id: 't1', fechaCorte: fechaCorte),
      ]);

      final alertas = await ObtenerAlertasTarjetasCredito(
        cuentaRepository: repo,
      )();

      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      expect(
        alertas.single.fecha,
        proximaOcurrenciaMensual(fechaCorte, hoySinHora),
      );
    },
  );

  test(
    'Fase 62: una fecha ancla en el pasado avanza sola, mes a mes, hasta la '
    'próxima ocurrencia futura — misma ancla guardada, nadie la reescribe',
    () async {
      final hoy = DateTime.now();
      final anclaPasada = DateTime(hoy.year - 1, 6, 15);
      final repo = _FakeCuentaRepository([
        _tarjeta(id: 't1', fechaCorte: anclaPasada),
      ]);

      final alertas = await ObtenerAlertasTarjetasCredito(
        cuentaRepository: repo,
      )();

      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      final proxima = proximaOcurrenciaMensual(anclaPasada, hoySinHora);

      // La próxima ocurrencia calculada cae en el futuro (nunca en el
      // pasado): prueba de que "avanza" en vez de quedarse fija en la
      // fecha ancla original.
      expect(proxima.isBefore(hoySinHora), isFalse);
      if (proxima.difference(hoySinHora).inDays > 3) {
        expect(alertas, isEmpty);
      } else {
        expect(alertas.single.fecha, proxima);
      }
    },
  );
}
