import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_transferencia.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';

import 'helpers/esquema_drift.dart';

/// Fase 84 (G) — migración encadenada en UNA sola apertura: una base vieja
/// con datos reales (cuentas, deudas, pagos) pasa por todos los pasos de
/// `onUpgrade` hasta la versión actual sin perder nada.
///
/// - v10: la última versión publicada antes del rediseño (HEAD de git).
/// - v5: la más vieja que llegó a producción que se puede identificar en
///   git (commit e5066a3, "listo para revisión de Apple"). Drift se usa en
///   producción sin sesión iniciada y para migrar datos locales a la nube,
///   así que esa base puede existir en un teléfono.
class _SinAmigos implements AmistadRepository {
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}
  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;
  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {}
  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      const [];
  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => const [];
  @override
  Future<void> aceptarSolicitud(String solicitudId) async {}
  @override
  Future<void> rechazarSolicitud(String solicitudId) async {}
}

int _s(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

/// Inserta una fila con solo las columnas dadas (las que existían en esa
/// versión).
/// [ejecutar] es `raw.execute` del `setup` de `NativeDatabase`.
typedef _Ejecutar = void Function(String sql, [List<Object?> parametros]);

void _insertar(_Ejecutar raw, String tabla, Map<String, Object?> fila) {
  final columnas = fila.keys.join(', ');
  final marcas = List.filled(fila.length, '?').join(', ');
  raw('INSERT INTO $tabla ($columnas) VALUES ($marcas)', fila.values.toList());
}

/// Deuda en cuotas con columnas existentes desde la v5.
Map<String, Object?> _filaPrestamo() => {
  'id': 'prestamo',
  'nombre_deuda': 'Préstamo BCP',
  'tipo_deuda': 'prestamoPersonal',
  'tipo_acreedor': 'entidadFinanciera',
  'nombre_acreedor': 'BCP',
  'moneda': 'pen',
  'monto_total': 10000.0,
  'monto_pagado': 900.0,
  'tiene_interes': 1,
  'estructura_pago': 'cuotasFijas',
  'numero_cuotas_total': 36,
  'numero_cuotas_pagadas': 2,
  'monto_cuota': 450.0,
  'periodicidad_cuotas': 'mensual',
  'interes_total': 6200.0,
  'fecha_inicio': _s(DateTime(2026, 1, 15)),
  'proxima_fecha_pago': _s(DateTime(2026, 3, 15)),
  'en_mora': 0,
  'estado': 'activa',
  'notas': 'del banco',
};

void _pagosDelPrestamo(_Ejecutar raw) {
  _insertar(raw, 'pagos_deuda', {
    'id': 'p1',
    'deuda_id': 'prestamo',
    'cuenta_id': 'debito',
    'monto_pagado': 450.0,
    'fecha_pago': _s(DateTime(2026, 1, 15)),
    'numero_cuota': 1,
  });
  // Pago retroactivo (sin cuenta): la columna es nullable desde la v3.
  _insertar(raw, 'pagos_deuda', {
    'id': 'p2',
    'deuda_id': 'prestamo',
    'cuenta_id': null,
    'monto_pagado': 450.0,
    'monto_capital': 300.0,
    'monto_interes': 150.0,
    'fecha_pago': _s(DateTime(2026, 2, 15)),
    'numero_cuota': 2,
  });
}

/// Fase 85: un gasto existente (con categoría) — debe sobrevivir a la
/// recreación de `transacciones` de la v15.
void _movimiento(_Ejecutar raw) {
  _insertar(raw, 'transacciones', {
    'id': 't1',
    'cuenta_id': 'debito',
    'categoria_id': 'cat-comida',
    'monto': 80.0,
    'moneda': 'pen',
    'tipo': 'gasto',
    'concepto': 'Almuerzo',
    'metodo_pago': 'efectivo',
    'es_recurrente': 0,
    'fuente_captura': 'manual',
    'fecha': _s(DateTime(2026, 3, 1)),
  });
}

Future<void> _verificarComun(AppDatabase db) async {
  final version = await db.customSelect('PRAGMA user_version').getSingle();
  expect(version.read<int>('user_version'), db.schemaVersion);
  expect(db.schemaVersion, 15);

  // Fase 85: el movimiento existente queda igual, sin transferencia.
  final t1 = (await TransaccionRepositoryDrift(db).obtenerPorId('t1'))!;
  expect(t1.categoriaId, 'cat-comida');
  expect(t1.tipo, TipoTransaccion.gasto);
  expect(t1.monto, 80);
  expect(t1.concepto, 'Almuerzo');
  expect(t1.fecha, DateTime(2026, 3, 1));
  expect(t1.transferenciaId, isNull);

  final debito = (await CuentaRepositoryDrift(db).obtenerPorId('debito'))!;
  expect(debito.nombre, 'Débito BCP');
  expect(debito.tipo, TipoCuenta.debito);
  expect(debito.saldoActual, 2500);
  expect(debito.tcea, isNull);

  final prestamo = (await DeudaRepositoryDrift(db).obtenerPorId('prestamo'))!;
  expect(prestamo.nombreDeuda, 'Préstamo BCP');
  expect(prestamo.montoTotal, 10000);
  expect(prestamo.montoPagado, 900);
  expect(prestamo.numeroCuotasTotal, 36);
  expect(prestamo.numeroCuotasPagadas, 2);
  expect(prestamo.montoCuota, 450);
  expect(prestamo.periodicidadCuotas, PeriodicidadCuota.mensual);
  expect(prestamo.interesTotal, 6200);
  expect(prestamo.fechaInicio, DateTime(2026, 1, 15));
  expect(prestamo.proximaFechaPago, DateTime(2026, 3, 15));
  expect(prestamo.notas, 'del banco');
  // Columnas nuevas con su valor por defecto.
  expect(prestamo.direccion, DireccionDeuda.debo);
  expect(prestamo.montoAbonadoCapital, 0);
  expect(prestamo.montoUltimaCuota, isNull);
  expect(saldoPendiente(prestamo), 450.0 * 34);

  final pagos = {
    for (final p in await PagoDeudaRepositoryDrift(
      db,
    ).obtenerPorDeuda('prestamo'))
      p.id: p,
  };
  expect(pagos.keys, unorderedEquals(['p1', 'p2']));
  expect(pagos['p1']!.cuentaId, 'debito');
  expect(pagos['p1']!.numeroCuota, 1);
  expect(pagos['p2']!.cuentaId, isNull);
  expect(pagos['p2']!.montoCapital, 300);
  expect(pagos['p2']!.montoInteres, 150);
  expect(pagos.values.every((p) => p.tipo == TipoPagoDeuda.cuota), isTrue);

  // La base migrada funciona con la Fase 84: se puede abonar a capital.
  await RegistrarPagoDeuda(
    pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
    deudaRepository: DeudaRepositoryDrift(db),
    cuentaRepository: CuentaRepositoryDrift(db),
    amistadRepository: _SinAmigos(),
  ).call(
    deudaId: 'prestamo',
    cuentaId: 'debito',
    montoPagado: 1000,
    tipo: TipoPagoDeuda.abonoCapital,
  );
  final tras = (await DeudaRepositoryDrift(db).obtenerPorId('prestamo'))!;
  expect(tras.montoAbonadoCapital, 1000);
  expect(tras.numeroCuotasTotal, lessThan(36));
  // Fase 84b: el abono deja una última cuota parcial (0 < F < cuota).
  expect(tras.montoUltimaCuota, allOf(greaterThan(0), lessThan(450)));
  expect(
    (await CuentaRepositoryDrift(db).obtenerPorId('debito'))!.saldoActual,
    1500,
  );

  // Fase 85: la base migrada admite transferencias (categoría NULL).
  await CuentaRepositoryDrift(db).crear(
    const Cuenta(
      id: 'ahorro',
      nombre: 'Ahorros',
      tipo: TipoCuenta.debito,
      moneda: Moneda.pen,
      saldoActual: 0,
    ),
  );
  await RegistrarTransferencia(
    cuentaRepository: CuentaRepositoryDrift(db),
    transaccionRepository: TransaccionRepositoryDrift(db),
    deudaRepository: DeudaRepositoryDrift(db),
  ).call(origenId: 'debito', destinoId: 'ahorro', monto: 200);
  expect(
    (await CuentaRepositoryDrift(db).obtenerPorId('debito'))!.saldoActual,
    1300,
  );
  expect(
    (await CuentaRepositoryDrift(db).obtenerPorId('ahorro'))!.saldoActual,
    200,
  );
  final caras = (await TransaccionRepositoryDrift(db).obtenerTodas())
      .where((t) => t.esTransferencia)
      .toList();
  expect(caras, hasLength(2));
  expect(caras.every((t) => t.categoriaId == null), isTrue);
}

void main() {
  test(
    'v10 → v15 en una sola apertura conserva cuentas, deudas y pagos',
    () async {
      final sqlV10 = await esquemaDriftEnVersion(10);
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            for (final sql in sqlV10) {
              raw.execute(sql);
            }
            _insertar(raw.execute, 'cuentas', {
              'id': 'debito',
              'nombre': 'Débito BCP',
              'tipo': 'debito',
              'moneda': 'pen',
              'saldo_actual': 2500.0,
              'ultimos_digitos': '1234',
            });
            _insertar(raw.execute, 'cuentas', {
              'id': 'visa',
              'nombre': 'Visa BCP',
              'tipo': 'credito',
              'moneda': 'pen',
              'saldo_actual': -1200.0,
              'linea_credito': 5000.0,
              'fecha_corte': _s(DateTime(2026, 10, 10)),
              'fecha_pago': _s(DateTime(2026, 10, 28)),
              'pago_minimo': 120.0,
            });
            _insertar(raw.execute, 'deudas', {
              ..._filaPrestamo(),
              'amigo_usuario_id': 'amigo-x',
            });
            // Deuda automática de la tarjeta (cuenta_id, v8).
            _insertar(raw.execute, 'deudas', {
              ..._filaPrestamo(),
              'id': 'deuda-visa',
              'nombre_deuda': 'Visa BCP',
              'tipo_deuda': 'tarjetaCredito',
              'estructura_pago': 'pagoLibre',
              'monto_total': 5000.0,
              'monto_pagado': 3800.0,
              'numero_cuotas_total': null,
              'numero_cuotas_pagadas': null,
              'monto_cuota': null,
              'periodicidad_cuotas': null,
              'interes_total': null,
              'cuenta_id': 'visa',
            });
            _pagosDelPrestamo(raw.execute);
            _movimiento(raw.execute);
            raw.userVersion = 10;
          },
        ),
      );
      addTearDown(db.close);

      final visa = (await CuentaRepositoryDrift(db).obtenerPorId('visa'))!;
      expect(visa.lineaCredito, 5000);
      expect(visa.fechaCorte, DateTime(2026, 10, 10));
      expect(visa.fechaPago, DateTime(2026, 10, 28));
      expect(visa.pagoMinimo, 120);
      expect(visa.tcea, isNull);
      expect(
        (await CuentaRepositoryDrift(
          db,
        ).obtenerPorId('debito'))!.ultimosDigitos,
        '1234',
      );
      final deudaVisa = (await DeudaRepositoryDrift(
        db,
      ).obtenerPorId('deuda-visa'))!;
      expect(deudaVisa.cuentaId, 'visa');
      expect(deudaVisa.montoPagado, 3800);
      expect(
        (await DeudaRepositoryDrift(
          db,
        ).obtenerPorId('prestamo'))!.amigoUsuarioId,
        'amigo-x',
      );
      await _verificarComun(db);
    },
  );

  test('v5 (primera versión enviada a la App Store) → v15 en una sola '
      'apertura', () async {
    final sqlV5 = await esquemaDriftEnVersion(5);
    expect(sqlV5.where((s) => s.contains('linea_credito')), isEmpty);
    expect(sqlV5.where((s) => s.contains('amigo_usuario_id')), isEmpty);
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) {
          for (final sql in sqlV5) {
            raw.execute(sql);
          }
          _insertar(raw.execute, 'cuentas', {
            'id': 'debito',
            'nombre': 'Débito BCP',
            'tipo': 'debito',
            'moneda': 'pen',
            'saldo_actual': 2500.0,
          });
          _insertar(raw.execute, 'deudas', _filaPrestamo());
          _pagosDelPrestamo(raw.execute);
          _movimiento(raw.execute);
          raw.userVersion = 5;
        },
      ),
    );
    addTearDown(db.close);

    final debito = (await CuentaRepositoryDrift(db).obtenerPorId('debito'))!;
    expect(debito.lineaCredito, isNull);
    expect(debito.fechaCorte, isNull);
    expect(debito.ultimosDigitos, isNull);
    expect(debito.pagoMinimo, isNull);
    final prestamo = (await DeudaRepositoryDrift(db).obtenerPorId('prestamo'))!;
    expect(prestamo.cuentaId, isNull);
    expect(prestamo.amigoUsuarioId, isNull);
    // `dia_corte`/`dia_pago` (agregadas en 6, borradas en 8) no quedan.
    final columnas = {
      for (final f in await db.customSelect('PRAGMA table_info(cuentas)').get())
        f.read<String>('name'),
    };
    expect(columnas, isNot(contains('dia_corte')));
    expect(columnas, containsAll(['fecha_corte', 'pago_minimo', 'tcea']));
    await _verificarComun(db);
  });

  // Fase 84b (D): el build 1.0.0+2 se subió a TestFlight con la v7 (y el
  // 1.0.0+1 pudo subirse ya con la v6): esas bases pueden existir en un
  // teléfono. Tenían `dia_corte`/`dia_pago`, que la v8 borra.
  for (final version in [6, 7]) {
    test('v$version (dia_corte/dia_pago) → v15 en una sola apertura', () async {
      final sql = await esquemaDriftEnVersion(version);
      final cuentasSql = sql.firstWhere((s) => s.contains('TABLE "cuentas"'));
      expect(cuentasSql, contains('"dia_corte" INTEGER NULL'));
      expect(cuentasSql, contains('"linea_credito"'));
      expect(cuentasSql, isNot(contains('fecha_corte')));
      expect(
        cuentasSql.contains('ultimos_digitos'),
        version == 7,
        reason: 'ultimos_digitos llega en la v7',
      );
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            for (final s in sql) {
              raw.execute(s);
            }
            _insertar(raw.execute, 'cuentas', {
              'id': 'debito',
              'nombre': 'Débito BCP',
              'tipo': 'debito',
              'moneda': 'pen',
              'saldo_actual': 2500.0,
            });
            _insertar(raw.execute, 'cuentas', {
              'id': 'visa',
              'nombre': 'Visa BCP',
              'tipo': 'credito',
              'moneda': 'pen',
              'saldo_actual': -1200.0,
              'linea_credito': 5000.0,
              'dia_corte': 10,
              'dia_pago': 28,
              if (version == 7) 'ultimos_digitos': '4321',
            });
            _insertar(raw.execute, 'deudas', _filaPrestamo());
            _pagosDelPrestamo(raw.execute);
            _movimiento(raw.execute);
            raw.userVersion = version;
          },
        ),
      );
      addTearDown(db.close);

      final visa = (await CuentaRepositoryDrift(db).obtenerPorId('visa'))!;
      expect(visa.lineaCredito, 5000);
      expect(visa.saldoActual, -1200);
      // Documentado en `from < 8`: el día suelto no alcanza para una fecha.
      expect(visa.fechaCorte, isNull);
      expect(visa.fechaPago, isNull);
      expect(visa.ultimosDigitos, version == 7 ? '4321' : isNull);
      final columnas = {
        for (final f in await db
            .customSelect('PRAGMA table_info(cuentas)')
            .get())
          f.read<String>('name'),
      };
      expect(columnas, isNot(contains('dia_corte')));
      expect(columnas, isNot(contains('dia_pago')));
      await _verificarComun(db);
    });
  }

  // Fase 85: también desde las versiones intermedias recientes.
  for (final version in [12, 13, 14]) {
    test('v$version → v15 en una sola apertura', () async {
      final sql = await esquemaDriftEnVersion(version);
      final transaccionesSql = sql.firstWhere(
        (s) => s.contains('TABLE "transacciones"'),
      );
      expect(transaccionesSql, contains('"categoria_id" TEXT NOT NULL'));
      expect(transaccionesSql, isNot(contains('transferencia_id')));
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            for (final s in sql) {
              raw.execute(s);
            }
            _insertar(raw.execute, 'cuentas', {
              'id': 'debito',
              'nombre': 'Débito BCP',
              'tipo': 'debito',
              'moneda': 'pen',
              'saldo_actual': 2500.0,
            });
            _insertar(raw.execute, 'deudas', _filaPrestamo());
            _pagosDelPrestamo(raw.execute);
            _movimiento(raw.execute);
            raw.userVersion = version;
          },
        ),
      );
      addTearDown(db.close);
      final columnas = {
        for (final f in await db
            .customSelect('PRAGMA table_info(transacciones)')
            .get())
          f.read<String>('name'): f.read<int>('notnull'),
      };
      expect(columnas['transferencia_id'], 0);
      expect(columnas['categoria_id'], 0, reason: 'ahora admite NULL');
      await _verificarComun(db);
    });
  }
}
