import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_cuenta.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas = {};

  @override
  Future<void> actualizar(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> crear(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> eliminar(String id) async => cuentas.remove(id);

  @override
  Future<Cuenta?> obtenerPorId(String id) async => cuentas[id];

  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas.values.toList();
}

class _FakeTransaccionRepository implements TransaccionRepository {
  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerTodas() async => [];
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async => [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime inicio,
    DateTime fin,
  ) async => [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => [];
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  @override
  Future<void> crear(PagoDeuda pago) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => [];
}

void main() {
  group('RegistrarCuenta — validación de campos de crédito', () {
    late _FakeCuentaRepository fake;
    late RegistrarCuenta registrarCuenta;

    setUp(() {
      fake = _FakeCuentaRepository();
      registrarCuenta = RegistrarCuenta(cuentaRepository: fake);
    });

    test('exige lineaCredito/diaCorte/diaPago cuando tipo es credito', () {
      expect(
        () => registrarCuenta(
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
        ),
        throwsArgumentError,
      );
    });

    test('rechaza faltar solo uno de los 3 campos', () {
      expect(
        () => registrarCuenta(
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          lineaCredito: 5000,
          diaCorte: 10,
        ),
        throwsArgumentError,
      );
    });

    test('crea la cuenta de crédito cuando vienen los 3 campos', () async {
      final cuenta = await registrarCuenta(
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        lineaCredito: 5000,
        diaCorte: 10,
        diaPago: 20,
      );

      expect(cuenta.lineaCredito, 5000);
      expect(cuenta.diaCorte, 10);
      expect(cuenta.diaPago, 20);
      expect(fake.cuentas[cuenta.id]!.diaPago, 20);
    });

    test('rechaza diaCorte/diaPago fuera de 1-31', () {
      expect(
        () => registrarCuenta(
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          lineaCredito: 5000,
          diaCorte: 32,
          diaPago: 20,
        ),
        throwsArgumentError,
      );
    });

    test('rechaza lineaCredito/diaCorte/diaPago si el tipo no es credito', () {
      expect(
        () => registrarCuenta(
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          lineaCredito: 5000,
        ),
        throwsArgumentError,
      );
    });

    test('crea sin problema una cuenta no-crédito sin esos 3 campos', () async {
      final cuenta = await registrarCuenta(
        nombre: 'Efectivo',
        tipo: TipoCuenta.efectivo,
        moneda: Moneda.pen,
      );
      expect(cuenta.lineaCredito, isNull);
      expect(cuenta.diaCorte, isNull);
      expect(cuenta.diaPago, isNull);
    });
  });

  group('EditarCuenta — validación de campos de crédito', () {
    late _FakeCuentaRepository fake;
    late EditarCuenta editarCuenta;

    setUp(() {
      fake = _FakeCuentaRepository();
      editarCuenta = EditarCuenta(
        cuentaRepository: fake,
        transaccionRepository: _FakeTransaccionRepository(),
        pagoDeudaRepository: _FakePagoDeudaRepository(),
      );
    });

    test('exige los 3 campos al editar hacia tipo credito', () async {
      fake.cuentas['c1'] = const Cuenta(
        id: 'c1',
        nombre: 'Cuenta',
        tipo: TipoCuenta.efectivo,
        moneda: Moneda.pen,
        saldoActual: 0,
      );

      await expectLater(
        editarCuenta(
          cuentaId: 'c1',
          nombre: 'Cuenta',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
        ),
        throwsArgumentError,
      );
    });

    test(
      'al cambiar de credito a otro tipo, anula lineaCredito/diaCorte/diaPago',
      () async {
        fake.cuentas['c1'] = const Cuenta(
          id: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -100,
          lineaCredito: 5000,
          diaCorte: 10,
          diaPago: 20,
        );

        final actualizada = await editarCuenta(
          cuentaId: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
        );

        expect(actualizada.lineaCredito, isNull);
        expect(actualizada.diaCorte, isNull);
        expect(actualizada.diaPago, isNull);
        // El saldo histórico no se toca al editar.
        expect(actualizada.saldoActual, -100);
      },
    );

    test('permite actualizar los 3 campos de una cuenta de crédito', () async {
      fake.cuentas['c1'] = const Cuenta(
        id: 'c1',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: -100,
        lineaCredito: 5000,
        diaCorte: 10,
        diaPago: 20,
      );

      final actualizada = await editarCuenta(
        cuentaId: 'c1',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        lineaCredito: 8000,
        diaCorte: 5,
        diaPago: 25,
      );

      expect(actualizada.lineaCredito, 8000);
      expect(actualizada.diaCorte, 5);
      expect(actualizada.diaPago, 25);
    });
  });
}
