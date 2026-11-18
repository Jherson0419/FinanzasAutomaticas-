import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/deuda_repository_supabase.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/pago_deuda_repository_supabase.dart';

import 'helpers/deuda_campos.dart';
import 'helpers/esquema_drift.dart';
import 'helpers/supabase_cliente.dart';

/// Fase 84 (B) — modelo de abonos a capital: `PagoDeuda.tipo` y
/// `Deuda.montoAbonadoCapital`.
int _segundos(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

PagoDeuda _pago({
  String id = 'p1',
  TipoPagoDeuda tipo = TipoPagoDeuda.cuota,
  int? numeroCuota = 1,
}) => PagoDeuda(
  id: id,
  deudaId: 'd1',
  cuentaId: 'c1',
  montoPagado: 300,
  fechaPago: DateTime(2026, 11, 3),
  numeroCuota: numeroCuota,
  tipo: tipo,
);

void main() {
  test('por defecto un pago es cuota y una deuda no tiene abonos', () {
    expect(_pago().tipo, TipoPagoDeuda.cuota);
    expect(_pago().esAbonoCapital, isFalse);
    expect(deudaConTodosLosCampos().montoAbonadoCapital, 0);
    expect(
      deudaConTodosLosCampos()
          .copyWith(montoAbonadoCapital: 500)
          .montoAbonadoCapital,
      500,
    );
  });

  group('Drift', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('ida y vuelta de montoAbonadoCapital (todos los campos)', () async {
      final repo = DeudaRepositoryDrift(db);
      final original = deudaConTodosLosCampos(montoAbonadoCapital: 1234.5);
      await repo.crear(original);
      expect(
        camposDeuda((await repo.obtenerPorId('d1'))!),
        camposDeuda(original),
      );
    });

    test('ida y vuelta del tipo de pago', () async {
      await DeudaRepositoryDrift(db).crear(deudaConTodosLosCampos());
      final repo = PagoDeudaRepositoryDrift(db);
      await repo.crear(_pago());
      await repo.crear(
        _pago(id: 'p2', tipo: TipoPagoDeuda.abonoCapital, numeroCuota: null),
      );
      final porId = {for (final p in await repo.obtenerPorDeuda('d1')) p.id: p};
      expect(porId['p1']!.tipo, TipoPagoDeuda.cuota);
      expect(porId['p2']!.tipo, TipoPagoDeuda.abonoCapital);
      expect(porId['p2']!.numeroCuota, isNull);
    });
  });

  test('migración 12 → 13: agrega las columnas con sus DEFAULT y conserva '
      'deudas y pagos', () async {
    final sqlV12 = await esquemaDriftEnVersion(12);
    expect(sqlV12.where((s) => s.contains('monto_abonado_capital')), isEmpty);

    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in sqlV12) {
            raw.execute(sql);
          }
          raw.execute(
            'INSERT INTO deudas (id, nombre_deuda, tipo_deuda, tipo_acreedor, '
            'nombre_acreedor, moneda, monto_total, monto_pagado, '
            'tiene_interes, estructura_pago, numero_cuotas_total, '
            'numero_cuotas_pagadas, monto_cuota, periodicidad_cuotas, '
            'fecha_inicio, estado, direccion) VALUES (?, ?, ?, ?, ?, ?, ?, ?, '
            '?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [
              'auto',
              'Crédito auto',
              'prestamoPersonal',
              'entidadFinanciera',
              'BCP',
              'pen',
              10000.0,
              900.0,
              1,
              'cuotasFijas',
              36,
              2,
              450.0,
              'mensual',
              _segundos(DateTime(2026, 1, 15)),
              'activa',
              'debo',
            ],
          );
          for (var n = 1; n <= 2; n++) {
            raw.execute(
              'INSERT INTO pagos_deuda (id, deuda_id, monto_pagado, '
              'fecha_pago, numero_cuota) VALUES (?, ?, ?, ?, ?)',
              ['p$n', 'auto', 450.0, _segundos(DateTime(2026, n + 1, 15)), n],
            );
          }
          raw.userVersion = 12;
        },
      ),
    );
    addTearDown(db.close);

    final deuda = (await DeudaRepositoryDrift(db).obtenerPorId('auto'))!;
    expect(deuda.montoAbonadoCapital, 0);
    expect(deuda.nombreDeuda, 'Crédito auto');
    expect(deuda.montoPagado, 900);
    expect(deuda.numeroCuotasTotal, 36);
    expect(deuda.numeroCuotasPagadas, 2);
    expect(deuda.montoCuota, 450);
    final pagos = await PagoDeudaRepositoryDrift(db).obtenerPorDeuda('auto');
    expect(pagos, hasLength(2));
    expect(pagos.every((p) => p.tipo == TipoPagoDeuda.cuota), isTrue);
    expect(pagos.map((p) => p.numeroCuota).toSet(), {1, 2});
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.read<int>('user_version'), 15);
  });

  group('Supabase: mapeo tolerante', () {
    final filaPago = {
      'id': 'p1',
      'deuda_id': 'd1',
      'cuenta_id': null,
      'monto_pagado': 300,
      'fecha_pago': '2026-11-03T00:00:00.000',
      'numero_cuota': 1,
    };

    test('pago sin la columna tipo (producción antes del SQL) → cuota', () {
      final repo = PagoDeudaRepositorySupabase(clienteSupabaseFalso());
      expect(repo.aDominio(filaPago).tipo, TipoPagoDeuda.cuota);
      expect(
        repo.aDominio({...filaPago, 'tipo': 'abono_capital'}).tipo,
        TipoPagoDeuda.abonoCapital,
      );
      expect(
        repo.aDominio({...filaPago, 'tipo': 'cuota'}).tipo,
        TipoPagoDeuda.cuota,
      );
    });

    test('aFila del pago solo envía tipo en un abono', () async {
      final repo = PagoDeudaRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      expect(repo.aFila(_pago()).containsKey('tipo'), isFalse);
      expect(
        repo.aFila(
          _pago(tipo: TipoPagoDeuda.abonoCapital, numeroCuota: null),
        )['tipo'],
        'abono_capital',
      );
    });

    test('deuda: columna ausente → 0; presente → su valor; aFila solo la '
        'envía si ≠ 0', () async {
      final repo = DeudaRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      final fila = repo.aFila(deudaConTodosLosCampos());
      expect(fila.containsKey('monto_abonado_capital'), isFalse);
      expect(repo.aDominio(fila).montoAbonadoCapital, 0);

      final conAbono = repo.aFila(
        deudaConTodosLosCampos(montoAbonadoCapital: 800),
      );
      expect(conAbono['monto_abonado_capital'], 800);
      expect(repo.aDominio(conAbono).montoAbonadoCapital, 800);
    });
  });
}
