import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/armar_resumen_para_consejos.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];
  @override
  Future<void> actualizar(Deuda deuda) async {}
  @override
  Future<void> crear(Deuda deuda) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<List<Deuda>> obtenerActivas() async => deudas;
  @override
  Future<Deuda?> obtenerPorId(String id) async => null;
  @override
  Future<List<Deuda>> obtenerTodas() async => deudas;
}

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  _FakeTransaccionRepository(this.transacciones);

  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      const [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => transacciones
      .where((t) => !t.fecha.isBefore(desde) && !t.fecha.isAfter(hasta))
      .toList();
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];
  @override
  Future<List<Transaccion>> obtenerTodas() async => transacciones;
}

class _FakeCategoriaRepository implements CategoriaRepository {
  final List<Categoria> categorias;
  _FakeCategoriaRepository(this.categorias);

  @override
  Future<Categoria?> obtenerPorId(String id) async {
    for (final c in categorias) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<Categoria>> obtenerTodas() async => categorias;

  @override
  Future<void> crear(Categoria categoria) async {}

  @override
  Future<void> actualizar(Categoria categoria) async {}

  @override
  Future<void> eliminar(String id) async {}
}

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
  Future<Cuenta?> obtenerPorId(String id) async => null;
  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas;
}

void main() {
  test('el resumen para el primer mensaje del chat es agregado y no contiene '
      'nombreDeuda/nombreAcreedor/nombres de cuenta', () async {
    final ahora = DateTime.now();
    final deuda = Deuda(
      id: 'd1',
      nombreDeuda: 'DEUDA_SECRETA_123',
      tipoDeuda: TipoDeuda.prestamoPersonal,
      tipoAcreedor: TipoAcreedor.personaNatural,
      nombreAcreedor: 'ACREEDOR_SECRETO_456',
      moneda: Moneda.pen,
      montoTotal: 1000,
      montoPagado: 400,
      tieneInteres: false,
      interesTotal: 100,
      estructuraPago: EstructuraPago.pagoLibre,
      fechaInicio: DateTime(2026, 1, 1),
      enMora: false,
      estado: EstadoDeuda.activa,
    );
    final cuenta = const Cuenta(
      id: 'cta-1',
      nombre: 'CUENTA_SECRETA_789',
      tipo: TipoCuenta.efectivo,
      moneda: Moneda.pen,
      saldoActual: 500,
    );
    final categoriaComida = const Categoria(
      id: 'cat-comida',
      nombre: 'Comida',
      tipo: TipoCategoria.gasto,
      iconName: 'restaurant',
    );
    final categoriaSueldo = const Categoria(
      id: 'cat-sueldo',
      nombre: 'Sueldo',
      tipo: TipoCategoria.ingreso,
      iconName: 'payments',
    );
    final gasto = Transaccion(
      id: 't1',
      cuentaId: 'cta-1',
      categoriaId: 'cat-comida',
      monto: 80,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.gasto,
      concepto: 'Supermercado',
      metodoPago: MetodoPago.efectivo,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime(ahora.year, ahora.month, 5),
    );
    final ingreso = Transaccion(
      id: 't2',
      cuentaId: 'cta-1',
      categoriaId: 'cat-sueldo',
      monto: 2000,
      moneda: Moneda.pen,
      tipo: TipoTransaccion.ingreso,
      concepto: 'Sueldo mensual',
      metodoPago: MetodoPago.transferencia,
      esRecurrente: true,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: DateTime(ahora.year, ahora.month, 1),
    );

    final armarResumen = ArmarResumenParaConsejos(
      deudaRepository: _FakeDeudaRepository([deuda]),
      transaccionRepository: _FakeTransaccionRepository([gasto, ingreso]),
      categoriaRepository: _FakeCategoriaRepository([
        categoriaComida,
        categoriaSueldo,
      ]),
      cuentaRepository: _FakeCuentaRepository([cuenta]),
    );

    final resumen = await armarResumen();

    // Correctitud de la agregación.
    expect(resumen.deudasActivas, hasLength(1));
    final deudaResumen = resumen.deudasActivas.single;
    expect(deudaResumen.tipoDeuda, TipoDeuda.prestamoPersonal);
    expect(deudaResumen.montoTotal, 1000);
    expect(deudaResumen.montoPagado, 400);
    expect(deudaResumen.interesTotal, 100);
    expect(deudaResumen.moneda, Moneda.pen);

    expect(resumen.gastosPorCategoriaMes, hasLength(1));
    expect(resumen.gastosPorCategoriaMes.single.categoriaNombre, 'Comida');
    expect(resumen.gastosPorCategoriaMes.single.monto, 80);
    expect(resumen.ingresosPorCategoriaMes, hasLength(1));
    expect(resumen.ingresosPorCategoriaMes.single.categoriaNombre, 'Sueldo');
    expect(resumen.ingresosPorCategoriaMes.single.monto, 2000);
    expect(resumen.saldoTotalPorMoneda[Moneda.pen], 500);

    // Verificación explícita de anonimización: ninguno de los campos
    // disponibles en el resumen (los únicos que existen en el DTO, y por
    // lo tanto lo único con lo que la Edge Function podría armar el
    // primer mensaje del chat) debe contener los identificadores del
    // acreedor, la deuda o la cuenta.
    final volcado = <String>[
      for (final d in resumen.deudasActivas)
        '${d.tipoDeuda}|${d.montoTotal}|${d.montoPagado}|${d.interesTotal}|${d.moneda}',
      for (final c in resumen.ingresosPorCategoriaMes)
        '${c.categoriaNombre}|${c.monto}|${c.moneda}',
      for (final c in resumen.gastosPorCategoriaMes)
        '${c.categoriaNombre}|${c.monto}|${c.moneda}',
      resumen.saldoTotalPorMoneda.toString(),
    ].join('\n');

    expect(volcado.contains('DEUDA_SECRETA_123'), isFalse);
    expect(volcado.contains('ACREEDOR_SECRETO_456'), isFalse);
    expect(volcado.contains('CUENTA_SECRETA_789'), isFalse);
  });

  group('Fase 60 — tarjetas de crédito no cuentan como fondos disponibles', () {
    test(
      'una tarjeta de crédito con saldo negativo (usado) NO se suma a '
      'saldoTotalPorMoneda, y se reporta aparte como obligación pendiente',
      () async {
        final debito = const Cuenta(
          id: 'cta-debito',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 500,
        );
        final tarjeta = Cuenta(
          id: 'cta-credito',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -800,
          lineaCredito: 2000,
          fechaCorte: DateTime(2026, 1, 10),
          fechaPago: DateTime(2026, 1, 20),
        );

        final armarResumen = ArmarResumenParaConsejos(
          deudaRepository: _FakeDeudaRepository([]),
          transaccionRepository: _FakeTransaccionRepository([]),
          categoriaRepository: _FakeCategoriaRepository([]),
          cuentaRepository: _FakeCuentaRepository([debito, tarjeta]),
        );

        final resumen = await armarResumen();

        // El saldo de la tarjeta (-800) NUNCA se resta ni se suma acá: el
        // total solo refleja las cuentas de débito/efectivo/billetera.
        expect(resumen.saldoTotalPorMoneda[Moneda.pen], 500);

        expect(resumen.tarjetasCredito, hasLength(1));
        final tarjetaResumen = resumen.tarjetasCredito.single;
        expect(tarjetaResumen.montoUsado, 800);
        expect(tarjetaResumen.lineaTotal, 2000);
        expect(tarjetaResumen.creditoDisponible, 1200);
        expect(tarjetaResumen.moneda, Moneda.pen);
      },
    );

    test(
      'una tarjeta sin uso (saldoActual >= 0) reporta montoUsado en 0 y '
      'todo el crédito como disponible',
      () async {
        final tarjeta = Cuenta(
          id: 'cta-credito',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: 0,
          lineaCredito: 2000,
          fechaCorte: DateTime(2026, 1, 10),
          fechaPago: DateTime(2026, 1, 20),
        );

        final armarResumen = ArmarResumenParaConsejos(
          deudaRepository: _FakeDeudaRepository([]),
          transaccionRepository: _FakeTransaccionRepository([]),
          categoriaRepository: _FakeCategoriaRepository([]),
          cuentaRepository: _FakeCuentaRepository([tarjeta]),
        );

        final resumen = await armarResumen();

        expect(resumen.saldoTotalPorMoneda, isEmpty);
        final tarjetaResumen = resumen.tarjetasCredito.single;
        expect(tarjetaResumen.montoUsado, 0);
        expect(tarjetaResumen.creditoDisponible, 2000);
      },
    );

    test('sin ninguna tarjeta de crédito, tarjetasCredito queda vacío', () async {
      final debito = const Cuenta(
        id: 'cta-debito',
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        saldoActual: 500,
      );

      final armarResumen = ArmarResumenParaConsejos(
        deudaRepository: _FakeDeudaRepository([]),
        transaccionRepository: _FakeTransaccionRepository([]),
        categoriaRepository: _FakeCategoriaRepository([]),
        cuentaRepository: _FakeCuentaRepository([debito]),
      );

      final resumen = await armarResumen();

      expect(resumen.tarjetasCredito, isEmpty);
      expect(resumen.saldoTotalPorMoneda[Moneda.pen], 500);
    });
  });
}
