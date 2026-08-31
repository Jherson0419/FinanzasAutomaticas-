import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/actualizar_estado_mora.dart';

class _FakeDeudaRepository implements DeudaRepository {
  final Map<String, Deuda> deudas;
  int actualizaciones = 0;
  _FakeDeudaRepository(this.deudas);

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async {
    actualizaciones++;
    deudas[deuda.id] = deuda;
  }

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);

  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values
      .where(
        (d) => d.estado == EstadoDeuda.activa || d.estado == EstadoDeuda.enMora,
      )
      .toList();

  @override
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  final Map<String, List<PagoDeuda>> pagosPorDeuda;
  _FakePagoDeudaRepository(this.pagosPorDeuda);

  @override
  Future<void> crear(PagoDeuda pago) async {
    (pagosPorDeuda[pago.deudaId] ??= []).add(pago);
  }

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => [];

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async =>
      pagosPorDeuda[deudaId] ?? [];

  @override
  Future<void> eliminar(String id) async {
    for (final pagos in pagosPorDeuda.values) {
      pagos.removeWhere((p) => p.id == id);
    }
  }
}

DateTime get _hoy {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

/// Deuda `cuotasFijas` sin pagos registrados: la primera cuota (y por lo
/// tanto `proximaFechaPago` vía cronograma) vence en [fechaInicio].
Deuda _deudaCuotasFijas({
  required String id,
  required DateTime fechaInicio,
  bool enMora = false,
  int? diasMora,
  EstadoDeuda estado = EstadoDeuda.activa,
}) {
  return Deuda(
    id: id,
    nombreDeuda: 'Préstamo $id',
    tipoDeuda: TipoDeuda.prestamoPersonal,
    tipoAcreedor: TipoAcreedor.entidadFinanciera,
    nombreAcreedor: 'BCP',
    moneda: Moneda.pen,
    montoTotal: 3000,
    montoPagado: 0,
    tieneInteres: false,
    estructuraPago: EstructuraPago.cuotasFijas,
    numeroCuotasTotal: 10,
    numeroCuotasPagadas: 0,
    montoCuota: 300,
    periodicidadCuotas: PeriodicidadCuota.mensual,
    fechaInicio: fechaInicio,
    enMora: enMora,
    diasMora: diasMora,
    estado: estado,
  );
}

Deuda _deudaPagoLibre({required String id}) {
  return Deuda(
    id: id,
    nombreDeuda: 'Tarjeta $id',
    tipoDeuda: TipoDeuda.tarjetaCredito,
    tipoAcreedor: TipoAcreedor.entidadFinanciera,
    nombreAcreedor: 'BBVA',
    moneda: Moneda.pen,
    montoTotal: 1000,
    montoPagado: 0,
    tieneInteres: false,
    estructuraPago: EstructuraPago.pagoLibre,
    fechaInicio: DateTime(2026, 1, 1),
    enMora: false,
    estado: EstadoDeuda.activa,
  );
}

void main() {
  test(
    'una deuda con proximaFechaPago (cronograma) vencida pasa a enMora',
    () async {
      final vencida = _hoy.subtract(const Duration(days: 5));
      final deuda = _deudaCuotasFijas(id: 'd1', fechaInicio: vencida);
      final fake = _FakeDeudaRepository({'d1': deuda});
      final fakePagos = _FakePagoDeudaRepository({});

      await ActualizarEstadoMora(
        deudaRepository: fake,
        pagoDeudaRepository: fakePagos,
      )();

      final actualizada = fake.deudas['d1']!;
      expect(actualizada.enMora, isTrue);
      expect(actualizada.estado, EstadoDeuda.enMora);
      expect(actualizada.diasMora, 5);
    },
  );

  test(
    'una deuda en mora cuya proximaFechaPago (cronograma) ya es futura vuelve a activa',
    () async {
      final futura = _hoy.add(const Duration(days: 10));
      final deuda = _deudaCuotasFijas(
        id: 'd2',
        fechaInicio: futura,
        enMora: true,
        diasMora: 20,
        estado: EstadoDeuda.enMora,
      );
      final fake = _FakeDeudaRepository({'d2': deuda});
      final fakePagos = _FakePagoDeudaRepository({});

      await ActualizarEstadoMora(
        deudaRepository: fake,
        pagoDeudaRepository: fakePagos,
      )();

      final actualizada = fake.deudas['d2']!;
      expect(actualizada.enMora, isFalse);
      expect(actualizada.estado, EstadoDeuda.activa);
      expect(actualizada.diasMora, 0);
    },
  );

  test('una deuda pagoLibre nunca cambia de estado por esta lógica', () async {
    final deuda = _deudaPagoLibre(id: 'd3');
    final fake = _FakeDeudaRepository({'d3': deuda});
    final fakePagos = _FakePagoDeudaRepository({});

    await ActualizarEstadoMora(
      deudaRepository: fake,
      pagoDeudaRepository: fakePagos,
    )();

    expect(identical(fake.deudas['d3'], deuda), isTrue);
    expect(fake.actualizaciones, 0);
  });

  test(
    'no reescribe una deuda cuyo estado de mora no cambió (misma fecha de cálculo)',
    () async {
      final vencida = _hoy.subtract(const Duration(days: 3));
      final deuda = _deudaCuotasFijas(
        id: 'd4',
        fechaInicio: vencida,
        enMora: true,
        diasMora: 3,
        estado: EstadoDeuda.enMora,
      );
      final fake = _FakeDeudaRepository({'d4': deuda});
      final fakePagos = _FakePagoDeudaRepository({});

      await ActualizarEstadoMora(
        deudaRepository: fake,
        pagoDeudaRepository: fakePagos,
      )();

      expect(fake.actualizaciones, 0);
      expect(identical(fake.deudas['d4'], deuda), isTrue);
    },
  );

  test(
    'una deuda con todas sus cuotas pagadas ya no tiene proximaFechaPago y no entra en mora',
    () async {
      final inicio = _hoy.subtract(const Duration(days: 400));
      final deuda = _deudaCuotasFijas(id: 'd5', fechaInicio: inicio);
      final pagos = [
        for (var numero = 1; numero <= 10; numero++)
          PagoDeuda(
            id: 'pago-$numero',
            deudaId: 'd5',
            cuentaId: 'cta-1',
            montoPagado: 300,
            fechaPago: inicio,
            numeroCuota: numero,
          ),
      ];
      final fake = _FakeDeudaRepository({'d5': deuda});
      final fakePagos = _FakePagoDeudaRepository({'d5': pagos});

      await ActualizarEstadoMora(
        deudaRepository: fake,
        pagoDeudaRepository: fakePagos,
      )();

      expect(fake.actualizaciones, 0);
      expect(fake.deudas['d5']!.enMora, isFalse);
    },
  );
}
