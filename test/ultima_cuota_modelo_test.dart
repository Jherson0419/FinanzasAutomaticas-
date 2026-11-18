import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/deuda_repository_supabase.dart';

import 'helpers/deuda_campos.dart';
import 'helpers/esquema_drift.dart';
import 'helpers/supabase_cliente.dart';

/// Fase 84b (A) — modelo de la última cuota parcial:
/// `Deuda.montoUltimaCuota`.
int _segundos(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

void main() {
  test('copyWith: conserva, cambia y puede volver a null', () {
    final d = deudaConTodosLosCampos(montoUltimaCuota: 300.5);
    expect(d.copyWith(notas: 'x').montoUltimaCuota, 300.5);
    expect(d.copyWith(montoUltimaCuota: 12).montoUltimaCuota, 12);
    expect(d.copyWith(sinMontoUltimaCuota: true).montoUltimaCuota, isNull);
    expect(deudaConTodosLosCampos().montoUltimaCuota, isNull);
  });

  test('totalAPagar = cuota × (n − 1) + F + abonado cuando hay F; si no, '
      'la fórmula de siempre', () {
    final base = deudaConTodosLosCampos(
      estructuraPago: EstructuraPago.cuotasFijas,
      montoCuota: 450,
      numeroCuotasTotal: 25,
      montoAbonadoCapital: 3000,
      montoPagado: 0,
    );
    expect(totalAPagar(base), 450 * 25 + 3000);
    expect(
      totalAPagar(base.copyWith(montoUltimaCuota: 300.69)),
      closeTo(450 * 24 + 300.69 + 3000, 1e-9),
    );
  });

  group('Drift', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('ida y vuelta (todos los campos), con y sin F', () async {
      final repo = DeudaRepositoryDrift(db);
      final conF = deudaConTodosLosCampos(
        montoAbonadoCapital: 3000,
        montoUltimaCuota: 300.69,
      );
      await repo.crear(conF);
      expect(camposDeuda((await repo.obtenerPorId('d1'))!), camposDeuda(conF));

      // Volver a la última cuota normal se persiste como NULL.
      await repo.actualizar(conF.copyWith(sinMontoUltimaCuota: true));
      expect((await repo.obtenerPorId('d1'))!.montoUltimaCuota, isNull);
    });

    test('EditarDeuda conserva F (y la incluye en interesTotal)', () async {
      final deudas = DeudaRepositoryDrift(db);
      final antes = deudaConTodosLosCampos(
        cuentaId: null,
        estructuraPago: EstructuraPago.cuotasFijas,
        montoTotal: 10000,
        montoCuota: 450,
        numeroCuotasTotal: 25,
        numeroCuotasPagadas: 12,
        montoPagado: 450.0 * 12 + 3000,
        montoAbonadoCapital: 3000,
        montoUltimaCuota: 300.69,
      );
      await deudas.crear(antes);
      final editada = await EditarDeuda(
        deudaRepository: deudas,
        pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
      ).call(
        deudaId: antes.id,
        nombreDeuda: 'Nombre nuevo',
        tipoDeuda: antes.tipoDeuda,
        tipoAcreedor: antes.tipoAcreedor,
        nombreAcreedor: antes.nombreAcreedor,
        moneda: antes.moneda,
        montoTotal: antes.montoTotal,
        estructuraPago: antes.estructuraPago,
        tieneInteres: antes.tieneInteres,
        tasaInteres: antes.tasaInteres,
        tipoTasa: antes.tipoTasa,
        pagoMinimo: antes.pagoMinimo,
        numeroCuotasTotal: antes.numeroCuotasTotal,
        montoCuota: antes.montoCuota,
        periodicidadCuotas: antes.periodicidadCuotas,
        fechaInicio: antes.fechaInicio,
        diaPago: antes.diaPago,
        notas: antes.notas,
        amigoUsuarioId: antes.amigoUsuarioId,
      );
      expect(editada.montoUltimaCuota, 300.69);
      expect((await deudas.obtenerPorId(antes.id))!.montoUltimaCuota, 300.69);
      expect(
        editada.interesTotal,
        closeTo(450 * 24 + 300.69 + 3000 - 10000, 1e-6),
      );
      expect(saldoPendiente(editada), closeTo(450 * 12 + 300.69, 1e-6));
    });
  });

  test('migración 13 → 14: agrega monto_ultima_cuota NULL y conserva la '
      'deuda con abonos', () async {
    final sqlV13 = await esquemaDriftEnVersion(13);
    expect(sqlV13.where((s) => s.contains('monto_ultima_cuota')), isEmpty);
    expect(
      sqlV13.where((s) => s.contains('monto_abonado_capital')),
      isNotEmpty,
    );

    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in sqlV13) {
            raw.execute(sql);
          }
          raw.execute(
            'INSERT INTO deudas (id, nombre_deuda, tipo_deuda, tipo_acreedor, '
            'nombre_acreedor, moneda, monto_total, monto_pagado, '
            'tiene_interes, tasa_interes, estructura_pago, '
            'numero_cuotas_total, numero_cuotas_pagadas, monto_cuota, '
            'periodicidad_cuotas, fecha_inicio, estado, direccion, '
            'monto_abonado_capital) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, '
            '?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'auto',
              'Crédito auto',
              'prestamoPersonal',
              'entidadFinanciera',
              'BCP',
              'pen',
              10000.0,
              8400.0,
              1,
              40.63,
              'cuotasFijas',
              25,
              12,
              450.0,
              'mensual',
              _segundos(DateTime(2026, 1, 15)),
              'activa',
              'debo',
              3000.0,
            ],
          );
          raw.execute(
            'INSERT INTO pagos_deuda (id, deuda_id, monto_pagado, fecha_pago, '
            "tipo) VALUES ('a1', 'auto', 3000.0, ?, 'abonoCapital')",
            [_segundos(DateTime(2026, 12, 20))],
          );
          raw.userVersion = 13;
        },
      ),
    );
    addTearDown(db.close);

    final deuda = (await DeudaRepositoryDrift(db).obtenerPorId('auto'))!;
    expect(deuda.montoUltimaCuota, isNull);
    expect(deuda.montoAbonadoCapital, 3000);
    expect(deuda.numeroCuotasTotal, 25);
    expect(deuda.tasaInteres, 40.63);
    // Sin F, el saldo sigue siendo el de la Fase 84 (última cuota entera).
    expect(saldoPendiente(deuda), 450.0 * 13);
    final pagos = await PagoDeudaRepositoryDrift(db).obtenerPorDeuda('auto');
    expect(pagos.single.esAbonoCapital, isTrue);
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 15);
  });

  group('Supabase: mapeo tolerante', () {
    test('columna ausente o NULL → null; presente → su valor', () async {
      final repo = DeudaRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      final fila = repo.aFila(deudaConTodosLosCampos());
      expect(fila.containsKey('monto_ultima_cuota'), isFalse);
      expect(repo.aDominio(fila).montoUltimaCuota, isNull);
      expect(
        repo.aDominio({...fila, 'monto_ultima_cuota': null}).montoUltimaCuota,
        isNull,
      );
      expect(
        repo
            .aDominio({...fila, 'monto_ultima_cuota': 300.69})
            .montoUltimaCuota,
        300.69,
      );
    });

    test('aFila: sin abonos no la envía; con abonos la envía aunque sea '
        'null (para poder limpiarla)', () async {
      final repo = DeudaRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      final conAbonoSinF = repo.aFila(
        deudaConTodosLosCampos(montoAbonadoCapital: 800),
      );
      expect(conAbonoSinF.containsKey('monto_ultima_cuota'), isTrue);
      expect(conAbonoSinF['monto_ultima_cuota'], isNull);
      final conF = repo.aFila(
        deudaConTodosLosCampos(montoAbonadoCapital: 800, montoUltimaCuota: 55.5),
      );
      expect(conF['monto_ultima_cuota'], 55.5);
    });

    test('"Te deben" (filas reducidas): el saldo usa F', () async {
      final repo = DeudaRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      final amigo = repo.aDominioDeudaDeAmigo({
        'id': 'd1',
        'user_id': 'u2',
        'nombre_deuda': 'Préstamo',
        'estructura_pago': 'cuotas_fijas',
        'monto_total': 10000,
        'monto_pagado': 450 * 12 + 3000,
        'monto_cuota': 450,
        'numero_cuotas_total': 25,
        'monto_abonado_capital': 3000,
        'monto_ultima_cuota': 300.69,
        'moneda': 'PEN',
        'direccion': null,
      });
      expect(amigo.montoAdeudado, closeTo(450 * 12 + 300.69, 1e-6));
    });
  });
}
