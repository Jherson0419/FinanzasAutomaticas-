import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/deuda_repository_supabase.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/enum_mapeo_supabase.dart';

import 'helpers/deuda_campos.dart';
import 'helpers/esquema_drift.dart';
import 'helpers/supabase_cliente.dart';

/// Fase 82 (B) — modelo de dirección de la deuda.
Map<String, dynamic> _filaSupabase({String? direccion}) => {
  'id': 'd1',
  'nombre_deuda': 'Préstamo a Lucía',
  'tipo_deuda': 'deuda_informal',
  'tipo_acreedor': 'persona_natural',
  'nombre_acreedor': 'Lucía',
  'moneda': 'PEN',
  'monto_total': 380,
  'monto_pagado': 0,
  'tiene_interes': false,
  'estructura_pago': 'pago_libre',
  'fecha_inicio': '2026-11-01T00:00:00.000',
  'en_mora': false,
  'estado': 'activa',
  // `direccion` solo se agrega si se pasa: simula producción antes del SQL.
  'direccion': ?direccion,
};

void main() {
  test('Deuda: dirección por defecto = debo; copyWith la conserva', () {
    final d = deudaConTodosLosCampos();
    expect(d.direccion, DireccionDeuda.debo);
    expect(d.meDeben, isFalse);
    final m = d.copyWith(direccion: DireccionDeuda.meDeben);
    expect(m.meDeben, isTrue);
    expect(m.copyWith(notas: 'x').direccion, DireccionDeuda.meDeben);
  });

  group('Drift', () {
    test('ida y vuelta de una deuda "me deben"', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = DeudaRepositoryDrift(db);
      await repo.crear(
        deudaConTodosLosCampos(direccion: DireccionDeuda.meDeben),
      );
      final leida = (await repo.obtenerPorId('d1'))!;
      expect(leida.direccion, DireccionDeuda.meDeben);
      expect(
        camposDeuda(leida),
        camposDeuda(deudaConTodosLosCampos(direccion: DireccionDeuda.meDeben)),
      );
    });

    test('migración 10 → 11: agrega la columna, deja "debo" y conserva los '
        'datos', () async {
      // 1) Esquema real de la versión 11, menos la columna nueva = v10.
      final sqlV10 = await esquemaDriftEnVersion(10);
      expect(
        sqlV10.where((s) => s.contains('direccion')),
        isEmpty,
        reason: 'el esquema v10 simulado no debe tener la columna',
      );

      // 2) Base v10 con una deuda existente.
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            for (final sql in sqlV10) {
              raw.execute(sql);
            }
            raw.execute(
              'INSERT INTO deudas (id, nombre_deuda, tipo_deuda, '
              'tipo_acreedor, nombre_acreedor, moneda, monto_total, '
              'monto_pagado, tiene_interes, estructura_pago, fecha_inicio, '
              'estado, amigo_usuario_id, notas) VALUES (?, ?, ?, ?, ?, ?, ?, '
              '?, ?, ?, ?, ?, ?, ?)',
              [
                'vieja',
                'Préstamo BCP',
                'prestamoPersonal',
                'entidadFinanciera',
                'BCP',
                'pen',
                1000.0,
                250.0,
                0,
                'pagoLibre',
                DateTime(2026, 1, 15).millisecondsSinceEpoch ~/ 1000,
                'activa',
                'amigo-x',
                'nota vieja',
              ],
            );
            raw.userVersion = 10;
          },
        ),
      );
      addTearDown(db.close);

      // 3) Abrir con la app actual dispara onUpgrade(10 → 11).
      final deuda = (await DeudaRepositoryDrift(db).obtenerPorId('vieja'))!;
      expect(deuda.direccion, DireccionDeuda.debo);
      expect(deuda.nombreDeuda, 'Préstamo BCP');
      expect(deuda.montoTotal, 1000);
      expect(deuda.montoPagado, 250);
      expect(deuda.amigoUsuarioId, 'amigo-x');
      expect(deuda.notas, 'nota vieja');
      expect(deuda.fechaInicio, DateTime(2026, 1, 15));
      final version = await db.customSelect('PRAGMA user_version').getSingle();
      // Abrir con la app actual migra hasta la última versión (13 desde la
      // Fase 84); lo que importa aquí es que pasó por 10 → 11.
      expect(version.read<int>('user_version'), 15);
    });
  });

  group('Supabase', () {
    final repo = DeudaRepositorySupabase(clienteSupabaseFalso());

    test(
      'una fila SIN la columna (producción antes del SQL) se lee como debo',
      () {
        expect(repo.aDominio(_filaSupabase()).direccion, DireccionDeuda.debo);
      },
    );

    test("'me_deben' ↔ meDeben", () {
      expect(
        repo.aDominio(_filaSupabase(direccion: 'me_deben')).direccion,
        DireccionDeuda.meDeben,
      );
      expect(direccionDeudaAFila(DireccionDeuda.meDeben), 'me_deben');
      expect(direccionDeudaAFila(DireccionDeuda.debo), 'debo');
      expect(direccionDeudaDeFila('debo'), DireccionDeuda.debo);
      expect(() => direccionDeudaDeFila('otra'), throwsFormatException);
    });

    test(
      'aFila: "debo" no envía la columna (compatibilidad); "me deben" sí',
      () async {
        final autenticado = DeudaRepositorySupabase(
          await clienteSupabaseAutenticado('user-1'),
        );
        expect(
          autenticado.aFila(deudaConTodosLosCampos()).containsKey('direccion'),
          isFalse,
        );
        expect(
          autenticado.aFila(
            deudaConTodosLosCampos(direccion: DireccionDeuda.meDeben),
          )['direccion'],
          'me_deben',
        );
      },
    );

    test('DeudaDeAmigo invierte la etiqueta según la dirección original', () {
      final base = {
        'id': 'd1',
        'user_id': 'dueño',
        'nombre_deuda': 'Almuerzo',
        'monto_total': 100,
        'monto_pagado': 20,
        'moneda': 'PEN',
        'estructura_pago': 'pago_libre',
      };
      final duenoDebe = repo.aDominioDeudaDeAmigo(base);
      expect(duenoDebe.direccion, DireccionDeuda.debo);
      expect(duenoDebe.yoDebo, isFalse, reason: '"{dueño} te debe"');
      expect(duenoDebe.montoAdeudado, 80);

      final duenoCobra = repo.aDominioDeudaDeAmigo({
        ...base,
        'direccion': 'me_deben',
      });
      expect(duenoCobra.yoDebo, isTrue, reason: '"Debes a {dueño}"');
    });
  });

  test('EditarDeuda conserva la dirección (no se edita)', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final deudas = DeudaRepositoryDrift(db);
    final original = deudaConTodosLosCampos(
      cuentaId: null,
      direccion: DireccionDeuda.meDeben,
    );
    await deudas.crear(original);

    await EditarDeuda(
      deudaRepository: deudas,
      pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
    ).call(
      deudaId: original.id,
      nombreDeuda: 'Otro nombre',
      tipoDeuda: original.tipoDeuda,
      tipoAcreedor: original.tipoAcreedor,
      nombreAcreedor: original.nombreAcreedor,
      moneda: Moneda.pen,
      montoTotal: original.montoTotal,
      estructuraPago: original.estructuraPago,
      fechaInicio: original.fechaInicio,
    );
    expect(
      (await deudas.obtenerPorId(original.id))!.direccion,
      DireccionDeuda.meDeben,
    );
  });
}
