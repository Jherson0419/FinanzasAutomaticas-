import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/proxima_fecha_dia_mes.dart';
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

/// Día del mes que cae exactamente [diasDesdeHoy] días a partir de hoy —
/// útil para armar cuentas de prueba sin depender de qué día es "hoy" al
/// correr el test.
int _diaEnNDias(int diasDesdeHoy) {
  final fecha = DateTime.now().add(Duration(days: diasDesdeHoy));
  return fecha.day;
}

Cuenta _tarjeta({
  required String id,
  int? diaCorte,
  int? diaPago,
  double saldoActual = 0,
}) {
  return Cuenta(
    id: id,
    nombre: 'Tarjeta $id',
    tipo: TipoCuenta.credito,
    moneda: Moneda.pen,
    saldoActual: saldoActual,
    lineaCredito: 5000,
    diaCorte: diaCorte,
    diaPago: diaPago,
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
    final diaCorte = _diaEnNDias(3);
    final repo = _FakeCuentaRepository([
      _tarjeta(id: 't1', diaCorte: diaCorte),
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
      final diaCorte = _diaEnNDias(4);
      final repo = _FakeCuentaRepository([
        _tarjeta(id: 't1', diaCorte: diaCorte),
      ]);

      final alertas = await ObtenerAlertasTarjetasCredito(
        cuentaRepository: repo,
      )();

      expect(alertas, isEmpty);
    },
  );

  test('alerta de pago cuando el día de pago es hoy (0 días)', () async {
    final hoy = DateTime.now();
    final repo = _FakeCuentaRepository([_tarjeta(id: 't1', diaPago: hoy.day)]);

    final alertas = await ObtenerAlertasTarjetasCredito(
      cuentaRepository: repo,
    )();

    expect(alertas, hasLength(1));
    expect(alertas.first.tipo, TipoAlertaTarjeta.pago);
    expect(alertas.first.diasRestantes, 0);
  });

  test('una tarjeta con corte y pago próximos genera 2 alertas', () async {
    final diaCorte = _diaEnNDias(1);
    final diaPago = _diaEnNDias(2);
    final repo = _FakeCuentaRepository([
      _tarjeta(id: 't1', diaCorte: diaCorte, diaPago: diaPago),
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
    'la fecha de la alerta coincide con proximaFecha(diaCorte, hoy)',
    () async {
      final hoy = DateTime.now();
      final diaCorte = _diaEnNDias(2);
      final repo = _FakeCuentaRepository([
        _tarjeta(id: 't1', diaCorte: diaCorte),
      ]);

      final alertas = await ObtenerAlertasTarjetasCredito(
        cuentaRepository: repo,
      )();

      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      expect(alertas.single.fecha, proximaFecha(diaCorte, hoySinHora));
    },
  );

  test(
    'Fase 57: un diaCorte que ya pasó este mes avanza solo a la próxima '
    'ocurrencia (mes siguiente) sin que nadie reescriba la cuenta — misma '
    '`diaCorte` guardada, resultado distinto según pase el tiempo',
    () async {
      final hoy = DateTime.now();
      // Si hoy es el día 1, no hay ningún día "ya pasado" distinto de hoy
      // mismo dentro de este mes — se cae al caso "vence hoy" (0 días),
      // ya cubierto por el test de "pago cuando el día es hoy" de arriba.
      final diaCorteQueYaPaso = hoy.day > 1 ? hoy.day - 1 : hoy.day;
      final repo = _FakeCuentaRepository([
        _tarjeta(id: 't1', diaCorte: diaCorteQueYaPaso),
      ]);

      final alertas = await ObtenerAlertasTarjetasCredito(
        cuentaRepository: repo,
      )();

      final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
      final proxima = proximaFecha(diaCorteQueYaPaso, hoySinHora);

      if (hoy.day > 1) {
        // El día ya pasó este mes: `proximaFecha` lo movió sola al mes
        // siguiente (fuera del umbral de 3 días) — nadie tocó `diaCorte`.
        expect(proxima.month == hoySinHora.month, isFalse);
        expect(alertas, isEmpty);
      } else {
        expect(alertas.single.diasRestantes, 0);
      }
    },
  );
}
