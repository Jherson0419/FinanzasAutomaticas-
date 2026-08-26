import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
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

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas = [];

  @override
  Future<void> actualizar(Deuda deuda) async {
    final indice = deudas.indexWhere((d) => d.id == deuda.id);
    if (indice != -1) deudas[indice] = deuda;
  }

  @override
  Future<void> crear(Deuda deuda) async => deudas.add(deuda);

  @override
  Future<void> eliminar(String id) async =>
      deudas.removeWhere((d) => d.id == id);

  @override
  Future<Deuda?> obtenerPorId(String id) async {
    for (final d in deudas) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas;

  @override
  Future<List<Deuda>> obtenerActivas() async =>
      deudas.where((d) => d.estado == EstadoDeuda.activa).toList();
}

void main() {
  group('RegistrarCuenta — validación de campos de crédito', () {
    late _FakeCuentaRepository fake;
    late RegistrarCuenta registrarCuenta;

    setUp(() {
      fake = _FakeCuentaRepository();
      registrarCuenta = RegistrarCuenta(
        cuentaRepository: fake,
        deudaRepository: _FakeDeudaRepository(),
      );
    });

    test('exige lineaCredito/fechaCorte/fechaPago cuando tipo es credito', () {
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
          fechaCorte: DateTime(2026, 1, 10),
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
        fechaCorte: DateTime(2026, 1, 10),
        fechaPago: DateTime(2026, 1, 20),
      );

      expect(cuenta.lineaCredito, 5000);
      expect(cuenta.fechaCorte, DateTime(2026, 1, 10));
      expect(cuenta.fechaPago, DateTime(2026, 1, 20));
      expect(fake.cuentas[cuenta.id]!.fechaPago, DateTime(2026, 1, 20));
    });

    test('rechaza lineaCredito/fechaCorte/fechaPago si el tipo no es credito', () {
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
      expect(cuenta.fechaCorte, isNull);
      expect(cuenta.fechaPago, isNull);
    });

    test(
      'Fase 62: crea también una Deuda vinculada (cuentaId) con los montos '
      'correctos a partir del saldo utilizado',
      () async {
        final fakeDeudas = _FakeDeudaRepository();
        final registrar = RegistrarCuenta(
          cuentaRepository: fake,
          deudaRepository: fakeDeudas,
        );

        final cuenta = await registrar(
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoInicial: -800,
          lineaCredito: 2000,
          fechaCorte: DateTime(2026, 1, 10),
          fechaPago: DateTime(2026, 1, 20),
        );

        expect(fakeDeudas.deudas, hasLength(1));
        final deuda = fakeDeudas.deudas.single;
        expect(deuda.cuentaId, cuenta.id);
        expect(deuda.nombreDeuda, 'Visa BCP');
        expect(deuda.tipoDeuda, TipoDeuda.tarjetaCredito);
        expect(deuda.estructuraPago, EstructuraPago.pagoLibre);
        expect(deuda.moneda, Moneda.pen);
        expect(deuda.montoTotal, 2000);
        // Crédito disponible (lineaTotal - montoUsado) = 2000 - 800 = 1200.
        expect(deuda.montoPagado, 1200);
        expect(deuda.montoTotal - deuda.montoPagado, 800);
        expect(deuda.estado, EstadoDeuda.activa);
      },
    );

    test(
      'Fase 62: una cuenta no-crédito no crea ninguna Deuda vinculada',
      () async {
        final fakeDeudas = _FakeDeudaRepository();
        final registrar = RegistrarCuenta(
          cuentaRepository: fake,
          deudaRepository: fakeDeudas,
        );

        await registrar(
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
        );

        expect(fakeDeudas.deudas, isEmpty);
      },
    );
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
        deudaRepository: _FakeDeudaRepository(),
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
      'al cambiar de credito a otro tipo, anula lineaCredito/fechaCorte/fechaPago',
      () async {
        fake.cuentas['c1'] = const Cuenta(
          id: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -100,
          lineaCredito: 5000,
          fechaCorte: null,
          fechaPago: null,
        );

        final actualizada = await editarCuenta(
          cuentaId: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
        );

        expect(actualizada.lineaCredito, isNull);
        expect(actualizada.fechaCorte, isNull);
        expect(actualizada.fechaPago, isNull);
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
      );

      final actualizada = await editarCuenta(
        cuentaId: 'c1',
        nombre: 'Visa BCP',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        lineaCredito: 8000,
        fechaCorte: DateTime(2026, 1, 5),
        fechaPago: DateTime(2026, 1, 25),
      );

      expect(actualizada.lineaCredito, 8000);
      expect(actualizada.fechaCorte, DateTime(2026, 1, 5));
      expect(actualizada.fechaPago, DateTime(2026, 1, 25));
    });

    test(
      'Fase 62: al cambiar la línea de crédito, sincroniza montoTotal de la '
      'Deuda vinculada sin tocar el monto usado',
      () async {
        final fakeDeudas = _FakeDeudaRepository()
          ..deudas.add(
            Deuda(
              id: 'd1',
              nombreDeuda: 'Visa BCP',
              tipoDeuda: TipoDeuda.tarjetaCredito,
              tipoAcreedor: TipoAcreedor.entidadFinanciera,
              nombreAcreedor: 'Visa BCP',
              moneda: Moneda.pen,
              montoTotal: 5000,
              // Usado = 5000 - 4200 = 800.
              montoPagado: 4200,
              tieneInteres: false,
              estructuraPago: EstructuraPago.pagoLibre,
              fechaInicio: DateTime(2026, 1, 1),
              enMora: false,
              estado: EstadoDeuda.activa,
              cuentaId: 'c1',
            ),
          );
        fake.cuentas['c1'] = const Cuenta(
          id: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -800,
          lineaCredito: 5000,
        );
        final editar = EditarCuenta(
          cuentaRepository: fake,
          transaccionRepository: _FakeTransaccionRepository(),
          pagoDeudaRepository: _FakePagoDeudaRepository(),
          deudaRepository: fakeDeudas,
        );

        await editar(
          cuentaId: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          lineaCredito: 8000,
          fechaCorte: DateTime(2026, 1, 10),
          fechaPago: DateTime(2026, 1, 20),
        );

        final deuda = fakeDeudas.deudas.single;
        expect(deuda.montoTotal, 8000);
        // Usado sigue siendo 800 (derivado del mismo saldoActual, no
        // tocado por EditarCuenta): 8000 - 7200 = 800.
        expect(deuda.montoPagado, 7200);
        expect(deuda.montoTotal - deuda.montoPagado, 800);
      },
    );

    test(
      'Fase 62: al cambiar el nombre de la cuenta, sincroniza nombreDeuda',
      () async {
        final fakeDeudas = _FakeDeudaRepository()
          ..deudas.add(
            Deuda(
              id: 'd1',
              nombreDeuda: 'Visa BCP',
              tipoDeuda: TipoDeuda.tarjetaCredito,
              tipoAcreedor: TipoAcreedor.entidadFinanciera,
              nombreAcreedor: 'Visa BCP',
              moneda: Moneda.pen,
              montoTotal: 5000,
              montoPagado: 5000,
              tieneInteres: false,
              estructuraPago: EstructuraPago.pagoLibre,
              fechaInicio: DateTime(2026, 1, 1),
              enMora: false,
              estado: EstadoDeuda.activa,
              cuentaId: 'c1',
            ),
          );
        fake.cuentas['c1'] = const Cuenta(
          id: 'c1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: 0,
          lineaCredito: 5000,
        );
        final editar = EditarCuenta(
          cuentaRepository: fake,
          transaccionRepository: _FakeTransaccionRepository(),
          pagoDeudaRepository: _FakePagoDeudaRepository(),
          deudaRepository: fakeDeudas,
        );

        await editar(
          cuentaId: 'c1',
          nombre: 'Visa BCP Oro',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          lineaCredito: 5000,
          fechaCorte: DateTime(2026, 1, 10),
          fechaPago: DateTime(2026, 1, 20),
        );

        expect(fakeDeudas.deudas.single.nombreDeuda, 'Visa BCP Oro');
      },
    );
  });
}
