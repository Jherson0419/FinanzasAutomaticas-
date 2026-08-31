import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/obtener_resumen_dashboard.dart';

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
    DateTime desde,
    DateTime hasta,
  ) async => [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => [];
}

class _FakeCategoriaRepository implements CategoriaRepository {
  @override
  Future<Categoria?> obtenerPorId(String id) async => null;
  @override
  Future<List<Categoria>> obtenerTodas() async => [];
  @override
  Future<void> crear(Categoria categoria) async {}
  @override
  Future<void> actualizar(Categoria categoria) async {}
  @override
  Future<void> eliminar(String id) async {}
}

class _FakeDeudaRepository implements DeudaRepository {
  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];
  @override
  Future<void> actualizar(Deuda deuda) async {}
  @override
  Future<void> crear(Deuda deuda) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Deuda?> obtenerPorId(String id) async => null;
  @override
  Future<List<Deuda>> obtenerTodas() async => [];
  @override
  Future<List<Deuda>> obtenerActivas() async => [];
}

void main() {
  test(
    'Fase 62: "Saldo total" excluye cuentas de crédito, aunque su saldo '
    'esté en positivo',
    () async {
      final cuentas = [
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
        const Cuenta(
          id: 'c2',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 200,
        ),
        const Cuenta(
          id: 'c3',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          // Si esto se sumara, el total daría 2200 en vez de 1200 — el bug
          // exacto que reportó el usuario (Saldo total inflado/distorsionado
          // por una tarjeta).
          saldoActual: 1000,
          lineaCredito: 2000,
        ),
      ];

      final obtenerResumen = ObtenerResumenDashboard(
        cuentaRepository: _FakeCuentaRepository(cuentas),
        transaccionRepository: _FakeTransaccionRepository(),
        categoriaRepository: _FakeCategoriaRepository(),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resumen = await obtenerResumen();

      expect(resumen.saldoTotalPorMoneda[Moneda.pen], 1200);
    },
  );

  test(
    'Fase 62: una tarjeta con saldo negativo (usada) tampoco resta del '
    'Saldo total — sigue completamente excluida',
    () async {
      final cuentas = [
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1000,
        ),
        const Cuenta(
          id: 'c3',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -800,
          lineaCredito: 2000,
        ),
      ];

      final obtenerResumen = ObtenerResumenDashboard(
        cuentaRepository: _FakeCuentaRepository(cuentas),
        transaccionRepository: _FakeTransaccionRepository(),
        categoriaRepository: _FakeCategoriaRepository(),
        deudaRepository: _FakeDeudaRepository(),
      );

      final resumen = await obtenerResumen();

      expect(resumen.saldoTotalPorMoneda[Moneda.pen], 1000);
    },
  );

  group('Fase 68 — fechaVencimientoReal, amigoUsuarioId y orden por vencimiento', () {
    Deuda deudaCuotasFijas({
      required String id,
      DateTime? proximaFechaPago,
      bool enMora = false,
    }) => Deuda(
      id: id,
      nombreDeuda: 'Préstamo $id',
      tipoDeuda: TipoDeuda.prestamoPersonal,
      tipoAcreedor: TipoAcreedor.entidadFinanciera,
      nombreAcreedor: 'BCP',
      moneda: Moneda.pen,
      montoTotal: 1000,
      montoPagado: 200,
      tieneInteres: false,
      estructuraPago: EstructuraPago.cuotasFijas,
      proximaFechaPago: proximaFechaPago,
      fechaInicio: DateTime(2026, 1, 1),
      enMora: enMora,
      estado: enMora ? EstadoDeuda.enMora : EstadoDeuda.activa,
    );

    test(
      'cuotasFijas: fechaVencimientoReal es proximaFechaPago tal cual',
      () async {
        final proximaFechaPago = DateTime(2026, 4, 1);
        final obtenerResumen = ObtenerResumenDashboard(
          cuentaRepository: _FakeCuentaRepository([]),
          transaccionRepository: _FakeTransaccionRepository(),
          categoriaRepository: _FakeCategoriaRepository(),
          deudaRepository: _FakeDeudaRepositoryConDatos([
            deudaCuotasFijas(id: 'd1', proximaFechaPago: proximaFechaPago),
          ]),
        );

        final resumen = await obtenerResumen();

        expect(resumen.deudasActivas.single.fechaVencimientoReal, proximaFechaPago);
      },
    );

    test(
      'deuda automática de tarjeta (cuentaId != null, pagoLibre): '
      'fechaVencimientoReal se resuelve desde Cuenta.fechaPago, no de '
      'Deuda.proximaFechaPago (que siempre es null en este caso)',
      () async {
        final fechaPagoCuenta = DateTime.now().add(const Duration(days: 20));
        final cuenta = Cuenta(
          id: 'cta-1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -300,
          lineaCredito: 2000,
          fechaCorte: DateTime.now(),
          fechaPago: fechaPagoCuenta,
        );
        final deudaTarjeta = Deuda(
          id: 'd1',
          nombreDeuda: 'Visa BCP',
          tipoDeuda: TipoDeuda.tarjetaCredito,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: 'Visa BCP',
          moneda: Moneda.pen,
          montoTotal: 2000,
          montoPagado: 1700,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
          cuentaId: 'cta-1',
        );

        final obtenerResumen = ObtenerResumenDashboard(
          cuentaRepository: _FakeCuentaRepository([cuenta]),
          transaccionRepository: _FakeTransaccionRepository(),
          categoriaRepository: _FakeCategoriaRepository(),
          deudaRepository: _FakeDeudaRepositoryConDatos([deudaTarjeta]),
        );

        final resumen = await obtenerResumen();

        final resultado = resumen.deudasActivas.single;
        expect(resultado.proximaFechaPago, isNull);
        expect(
          resultado.fechaVencimientoReal,
          DateTime(
            fechaPagoCuenta.year,
            fechaPagoCuenta.month,
            fechaPagoCuenta.day,
          ),
        );
      },
    );

    test(
      'pagoLibre sin cuenta vinculada: fechaVencimientoReal queda null',
      () async {
        final deuda = Deuda(
          id: 'd1',
          nombreDeuda: 'Deuda informal',
          tipoDeuda: TipoDeuda.deudaInformal,
          tipoAcreedor: TipoAcreedor.personaNatural,
          nombreAcreedor: 'Un amigo',
          moneda: Moneda.pen,
          montoTotal: 100,
          montoPagado: 0,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
        );

        final obtenerResumen = ObtenerResumenDashboard(
          cuentaRepository: _FakeCuentaRepository([]),
          transaccionRepository: _FakeTransaccionRepository(),
          categoriaRepository: _FakeCategoriaRepository(),
          deudaRepository: _FakeDeudaRepositoryConDatos([deuda]),
        );

        final resumen = await obtenerResumen();

        expect(resumen.deudasActivas.single.fechaVencimientoReal, isNull);
      },
    );

    test('amigoUsuarioId pasa tal cual a DeudaActivaResumen', () async {
      final deuda = Deuda(
        id: 'd1',
        nombreDeuda: 'Préstamo de un amigo',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'jherson23',
        moneda: Moneda.pen,
        montoTotal: 100,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
        amigoUsuarioId: 'user-amigo',
      );

      final obtenerResumen = ObtenerResumenDashboard(
        cuentaRepository: _FakeCuentaRepository([]),
        transaccionRepository: _FakeTransaccionRepository(),
        categoriaRepository: _FakeCategoriaRepository(),
        deudaRepository: _FakeDeudaRepositoryConDatos([deuda]),
      );

      final resumen = await obtenerResumen();

      expect(resumen.deudasActivas.single.amigoUsuarioId, 'user-amigo');
    });

    test(
      'deudasActivas queda ordenada: vencidas primero, luego por vencer, '
      'luego el resto',
      () async {
        final hoy = DateTime.now();
        final normal = deudaCuotasFijas(
          id: 'normal',
          proximaFechaPago: hoy.add(const Duration(days: 30)),
        );
        final porVencer = deudaCuotasFijas(
          id: 'porVencer',
          proximaFechaPago: hoy.add(const Duration(days: 1)),
        );
        final vencida = deudaCuotasFijas(id: 'vencida', enMora: true);

        final obtenerResumen = ObtenerResumenDashboard(
          cuentaRepository: _FakeCuentaRepository([]),
          transaccionRepository: _FakeTransaccionRepository(),
          categoriaRepository: _FakeCategoriaRepository(),
          deudaRepository: _FakeDeudaRepositoryConDatos([
            normal,
            porVencer,
            vencida,
          ]),
        );

        final resumen = await obtenerResumen();

        expect(resumen.deudasActivas.map((d) => d.id).toList(), [
          'vencida',
          'porVencer',
          'normal',
        ]);
      },
    );
  });
}

/// Variante de `_FakeDeudaRepository` que sí devuelve datos en
/// `obtenerActivas` (la de arriba siempre devuelve `[]`, suficiente para
/// los tests de "Saldo total" que no miran `deudasActivas`).
class _FakeDeudaRepositoryConDatos implements DeudaRepository {
  final List<Deuda> deudas;
  _FakeDeudaRepositoryConDatos(this.deudas);

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];
  @override
  Future<void> actualizar(Deuda deuda) async {}
  @override
  Future<void> crear(Deuda deuda) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Deuda?> obtenerPorId(String id) async => null;
  @override
  Future<List<Deuda>> obtenerActivas() async => deudas;
  @override
  Future<List<Deuda>> obtenerTodas() async => deudas;
}
