import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/costo_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/sincronizar_deuda_tarjeta.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/cuenta_repository_supabase.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/cuenta_formulario.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

import 'helpers/esquema_drift.dart';
import 'helpers/supabase_cliente.dart';

/// Fase 83 (C) — TCEA de la tarjeta de crédito.
void main() {
  late AppDatabase db;
  late CuentaRepositoryDrift cuentas;
  late DeudaRepositoryDrift deudas;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cuentas = CuentaRepositoryDrift(db);
    deudas = DeudaRepositoryDrift(db);
  });
  tearDown(() => db.close());

  Future<Deuda> deudaDe(String cuentaId) async =>
      (await deudas.obtenerTodas()).firstWhere((d) => d.cuentaId == cuentaId);

  group('casos de uso copian la TCEA a la deuda vinculada', () {
    test(
      'RegistrarCuenta: 65 % → tasaInteres 65, tieneInteres, costo 0.65',
      () async {
        final cuenta =
            await RegistrarCuenta(
              cuentaRepository: cuentas,
              deudaRepository: deudas,
            ).call(
              nombre: 'Visa BCP',
              tipo: TipoCuenta.credito,
              moneda: Moneda.pen,
              saldoInicial: -1200,
              lineaCredito: 5000,
              fechaCorte: DateTime(2026, 11, 10),
              fechaPago: DateTime(2026, 12, 5),
              tcea: 0.65,
            );
        expect((await cuentas.obtenerPorId(cuenta.id))!.tcea, 0.65);
        final deuda = await deudaDe(cuenta.id);
        expect(deuda.tasaInteres, closeTo(65, 1e-9));
        expect(deuda.tieneInteres, isTrue);
        expect(tasaEfectivaAnual(deuda), closeTo(0.65, 1e-9));
      },
    );

    test(
      'RegistrarCuenta sin TCEA: la deuda queda sin tasa ("Falta la tasa")',
      () async {
        final cuenta =
            await RegistrarCuenta(
              cuentaRepository: cuentas,
              deudaRepository: deudas,
            ).call(
              nombre: 'Visa',
              tipo: TipoCuenta.credito,
              moneda: Moneda.pen,
              lineaCredito: 3000,
              fechaCorte: DateTime(2026, 11, 10),
              fechaPago: DateTime(2026, 12, 5),
            );
        expect(tasaEfectivaAnual(await deudaDe(cuenta.id)), isNull);
      },
    );

    test('una cuenta que no es de crédito no guarda TCEA', () async {
      final cuenta =
          await RegistrarCuenta(
            cuentaRepository: cuentas,
            deudaRepository: deudas,
          ).call(
            nombre: 'Ahorros',
            tipo: TipoCuenta.debito,
            moneda: Moneda.pen,
            tcea: 0.5,
          );
      expect((await cuentas.obtenerPorId(cuenta.id))!.tcea, isNull);
    });

    test(
      'EditarCuenta: cambiar y luego quitar la TCEA actualiza la deuda',
      () async {
        final cuenta =
            await RegistrarCuenta(
              cuentaRepository: cuentas,
              deudaRepository: deudas,
            ).call(
              nombre: 'Visa',
              tipo: TipoCuenta.credito,
              moneda: Moneda.pen,
              lineaCredito: 3000,
              fechaCorte: DateTime(2026, 11, 10),
              fechaPago: DateTime(2026, 12, 5),
              tcea: 0.40,
            );
        final editar = EditarCuenta(
          cuentaRepository: cuentas,
          transaccionRepository: TransaccionRepositoryDrift(db),
          pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
          deudaRepository: deudas,
        );
        Future<void> conTcea(double? tcea) => editar.call(
          cuentaId: cuenta.id,
          nombre: 'Visa',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          lineaCredito: 3000,
          fechaCorte: DateTime(2026, 11, 10),
          fechaPago: DateTime(2026, 12, 5),
          tcea: tcea,
        );

        await conTcea(0.80);
        expect(
          tasaEfectivaAnual(await deudaDe(cuenta.id)),
          closeTo(0.80, 1e-9),
        );

        await conTcea(null);
        final sinTasa = await deudaDe(cuenta.id);
        expect(sinTasa.tasaInteres, isNull);
        expect(sinTasa.tieneInteres, isFalse);
        expect(tasaEfectivaAnual(sinTasa), isNull);
        expect((await cuentas.obtenerPorId(cuenta.id))!.tcea, isNull);
      },
    );

    test('SincronizarDeudaTarjeta también copia la TCEA', () async {
      await deudas.crear(
        Deuda(
          id: 'deuda-visa',
          nombreDeuda: 'Visa',
          tipoDeuda: TipoDeuda.tarjetaCredito,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: 'Visa',
          moneda: Moneda.pen,
          montoTotal: 2000,
          montoPagado: 2000,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
          cuentaId: 'visa',
        ),
      );
      await SincronizarDeudaTarjeta(deudaRepository: deudas).call(
        const Cuenta(
          id: 'visa',
          nombre: 'Visa',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -500,
          lineaCredito: 2000,
          tcea: 0.48,
        ),
      );
      final deuda = (await deudas.obtenerPorId('deuda-visa'))!;
      expect(deuda.montoPagado, 1500);
      expect(tasaEfectivaAnual(deuda), closeTo(0.48, 1e-9));
    });
  });

  test(
    'Drift: migración 11 → 12 agrega cuentas.tcea y conserva los datos',
    () async {
      final sqlV11 = await esquemaDriftEnVersion(11);
      expect(sqlV11.where((s) => s.contains('"tcea"')), isEmpty);

      final migrada = AppDatabase.forTesting(
        NativeDatabase.memory(
          setup: (raw) {
            for (final sql in sqlV11) {
              raw.execute(sql);
            }
            raw.execute(
              'INSERT INTO cuentas (id, nombre, tipo, moneda, saldo_actual, '
              'linea_credito, pago_minimo) VALUES (?, ?, ?, ?, ?, ?, ?)',
              ['visa', 'Visa BCP', 'credito', 'pen', -1200.0, 5000.0, 150.0],
            );
            raw.userVersion = 11;
          },
        ),
      );
      addTearDown(migrada.close);

      final cuenta = (await CuentaRepositoryDrift(
        migrada,
      ).obtenerPorId('visa'))!;
      expect(cuenta.tcea, isNull);
      expect(cuenta.nombre, 'Visa BCP');
      expect(cuenta.saldoActual, -1200);
      expect(cuenta.lineaCredito, 5000);
      expect(cuenta.pagoMinimo, 150);
      final version = await migrada
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.read<int>('user_version'), 15);
      expect(migrada.schemaVersion, 15);
    },
  );

  group('Supabase: mapeo tolerante', () {
    final base = {
      'id': 'c1',
      'nombre': 'Visa',
      'tipo': 'credito',
      'moneda': 'PEN',
      'saldo_actual': -10,
    };

    test('fila sin la columna (producción antes del SQL) → tcea null', () {
      final repo = CuentaRepositorySupabase(clienteSupabaseFalso());
      expect(repo.aDominio(base).tcea, isNull);
      expect(repo.aDominio({...base, 'tcea': 0.65}).tcea, 0.65);
    });

    test('aFila solo envía tcea si la cuenta tiene una', () async {
      final repo = CuentaRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      const sin = Cuenta(
        id: 'c1',
        nombre: 'Visa',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        saldoActual: 0,
      );
      expect(repo.aFila(sin).containsKey('tcea'), isFalse);
      expect(repo.aFila(sin.copyWith(tcea: 0.5))['tcea'], 0.5);
    });
  });

  testWidgets('formulario de cuenta: "TCEA (%)" en crédito; 65 se guarda '
      'como 0.65', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => cuentas.crear(
        Cuenta(
          id: 'visa',
          nombre: 'Visa',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -100,
          lineaCredito: 2000,
          fechaCorte: DateTime(2026, 11, 10),
          fechaPago: DateTime(2026, 12, 5),
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overridesModoLocal(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CuentaFormulario(
                cuentaId: 'visa',
                onGuardadoExitoso: () {},
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('TCEA (%)'), findsOneWidget);
    expect(
      find.text('Opcional. La encuentras en tu estado de cuenta.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'TCEA (%)'),
      '65',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Guardar cambios'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar cambios'));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    final guardada = await tester.runAsync(() => cuentas.obtenerPorId('visa'));
    expect(guardada!.tcea, closeTo(0.65, 1e-9));
  });
}
