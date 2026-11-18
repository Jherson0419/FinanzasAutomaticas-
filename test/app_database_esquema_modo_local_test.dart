import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';

/// Fase 78 — el modo local depende de que Drift guarde TODO lo que hoy
/// tienen las entidades. Al revisarlo no faltaba ninguna columna
/// (schemaVersion 10 ya las tenía), así que no hubo migración nueva; estas
/// pruebas fijan ese estado para que una entidad nueva sin su columna
/// rompa aquí y no en silencio en el modo local.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Set<String>> columnas(String tabla) async {
    final filas = await db.customSelect('PRAGMA table_info($tabla)').get();
    return {for (final f in filas) f.read<String>('name')};
  }

  // Fase 82: pasó de 10 a 11 por la columna `deudas.direccion` (la
  // migración 10 → 11 se prueba en `direccion_deuda_modelo_test.dart`).
  // Fase 83: 11 → 12 por cuentas.tcea (migración probada en
  // tcea_tarjeta_test.dart).
  // Fase 84: 12 → 13 por pagos_deuda.tipo y deudas.monto_abonado_capital
  // (migración probada en abono_capital_modelo_test.dart).
  // Fase 84b: 13 → 14 por deudas.monto_ultima_cuota (migración probada en
  // ultima_cuota_test.dart y migracion_encadenada_test.dart).
  // Fase 85: 14 → 15 por transacciones.transferencia_id y categoria_id
  // nullable (migración probada en migracion_encadenada_test.dart).
  test('schemaVersion = 15 (Fase 85: transferencias)', () {
    expect(db.schemaVersion, 15);
  });

  test(
    'deudas/pagos_deuda/cuentas tienen las columnas de las entidades actuales',
    () async {
      expect(
        await columnas('deudas'),
        containsAll([
          'cuenta_id',
          'amigo_usuario_id',
          'periodicidad_cuotas',
          'interes_total',
          'tasa_interes',
          'tipo_tasa',
          'direccion',
          'monto_abonado_capital',
          'monto_ultima_cuota',
        ]),
      );
      expect(
        await columnas('pagos_deuda'),
        containsAll(['monto_capital', 'monto_interes', 'numero_cuota', 'tipo']),
      );
      expect(
        await columnas('cuentas'),
        containsAll([
          'linea_credito',
          'fecha_corte',
          'fecha_pago',
          'ultimos_digitos',
          'pago_minimo',
          'tcea',
        ]),
      );
      expect(await columnas('transacciones'), contains('transferencia_id'));
    },
  );

  test('una base nueva siembra las categorías predeterminadas', () async {
    final categorias = await CategoriaRepositoryDrift(db).obtenerTodas();
    final porTipo = {
      for (final c in categorias) '${c.tipo.name}:${c.nombre}': c,
    };
    expect(
      porTipo.keys,
      containsAll([
        'gasto:Comida',
        'gasto:Transporte',
        'gasto:Servicios',
        'ingreso:Sueldo',
        'ingreso:Ajuste de saldo',
        'gasto:Ajuste de saldo',
      ]),
    );
    expect(categorias.every((c) => c.esPredeterminada), isTrue);
    expect(porTipo['gasto:Comida']!.tipo, TipoCategoria.gasto);
  });

  test(
    'Deuda con todos los campos opcionales sobrevive ida y vuelta',
    () async {
      final repo = DeudaRepositoryDrift(db);
      final deuda = Deuda(
        id: 'd1',
        nombreDeuda: 'Tarjeta',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'Ana',
        moneda: Moneda.usd,
        montoTotal: 1000,
        montoPagado: 100,
        tieneInteres: true,
        tasaInteres: 12.5,
        tipoTasa: TipoTasa.variable,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 6,
        numeroCuotasPagadas: 1,
        montoCuota: 180,
        pagoMinimo: 50,
        periodicidadCuotas: PeriodicidadCuota.quincenal,
        interesTotal: 80,
        fechaInicio: DateTime(2026, 1, 15),
        fechaVencimientoFinal: DateTime(2026, 4, 15),
        diaPago: 15,
        proximaFechaPago: DateTime(2026, 2, 1),
        enMora: true,
        diasMora: 3,
        tasaInteresMoratorio: 2,
        estado: EstadoDeuda.enMora,
        notas: 'nota',
        cuentaId: 'c-credito',
        amigoUsuarioId: 'amigo-1',
      );
      await repo.crear(deuda);

      final leida = (await repo.obtenerPorId('d1'))!;
      expect(leida.cuentaId, 'c-credito');
      expect(leida.amigoUsuarioId, 'amigo-1');
      expect(leida.periodicidadCuotas, PeriodicidadCuota.quincenal);
      expect(leida.interesTotal, 80);
      expect(leida.tasaInteres, 12.5);
      expect(leida.tipoTasa, TipoTasa.variable);
      expect(leida.moneda, Moneda.usd);
      expect(leida.estado, EstadoDeuda.enMora);
      expect(leida.diasMora, 3);
    },
  );

  test(
    'PagoDeuda con capital/interés/número de cuota sobrevive ida y vuelta',
    () async {
      final repo = PagoDeudaRepositoryDrift(db);
      await repo.crear(
        PagoDeuda(
          id: 'p1',
          deudaId: 'd1',
          montoPagado: 180,
          montoCapital: 165,
          montoInteres: 15,
          fechaPago: DateTime(2026, 2, 1),
          numeroCuota: 2,
        ),
      );

      final leido = (await repo.obtenerPorDeuda('d1')).single;
      expect(leido.cuentaId, isNull);
      expect(leido.montoCapital, 165);
      expect(leido.montoInteres, 15);
      expect(leido.numeroCuota, 2);
    },
  );

  test(
    'Cuenta de crédito con todos sus campos sobrevive ida y vuelta',
    () async {
      final repo = CuentaRepositoryDrift(db);
      await repo.crear(
        Cuenta(
          id: 'c1',
          nombre: 'Visa',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -350,
          lineaCredito: 5000,
          fechaCorte: DateTime(2026, 11, 10),
          fechaPago: DateTime(2026, 12, 5),
          ultimosDigitos: '1234',
          pagoMinimo: 120,
        ),
      );

      final leida = (await repo.obtenerPorId('c1'))!;
      expect(leida.tipo, TipoCuenta.credito);
      expect(leida.lineaCredito, 5000);
      expect(leida.fechaCorte, DateTime(2026, 11, 10));
      expect(leida.fechaPago, DateTime(2026, 12, 5));
      expect(leida.ultimosDigitos, '1234');
      expect(leida.pagoMinimo, 120);
    },
  );
}
