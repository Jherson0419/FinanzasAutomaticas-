import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/cronograma_cuotas.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/historial_pagos_deuda_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/pago_deuda_nuevo_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 84 (D) — selector "Pagar cuota / Adelantar cuotas / Abono a
/// capital" en la pantalla de pago.
Deuda _credito({
  String id = 'auto',
  DireccionDeuda direccion = DireccionDeuda.debo,
  EstructuraPago estructura = EstructuraPago.cuotasFijas,
}) => Deuda(
  id: id,
  nombreDeuda: 'Crédito auto',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 10000,
  montoPagado: 5400,
  tieneInteres: true,
  estructuraPago: estructura,
  numeroCuotasTotal: 36,
  numeroCuotasPagadas: 12,
  montoCuota: 450,
  periodicidadCuotas: PeriodicidadCuota.mensual,
  fechaInicio: DateTime(2026, 1, 15),
  enMora: false,
  estado: EstadoDeuda.activa,
  direccion: direccion,
);

void main() {
  late AppDatabase db;
  late DeudaRepositoryDrift deudas;
  late PagoDeudaRepositoryDrift pagos;
  final navegador = GlobalKey<NavigatorState>();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deudas = DeudaRepositoryDrift(db);
    pagos = PagoDeudaRepositoryDrift(db);
  });
  tearDown(() => db.close());

  Future<void> sembrar(WidgetTester tester, Deuda deuda) =>
      tester.runAsync(() async {
        await deudas.crear(deuda);
        for (var n = 1; n <= (deuda.numeroCuotasPagadas ?? 0); n++) {
          await pagos.crear(
            PagoDeuda(
              id: '${deuda.id}-c$n',
              deudaId: deuda.id,
              montoPagado: 450,
              fechaPago: sumarMeses(deuda.fechaInicio, n - 1),
              numeroCuota: n,
            ),
          );
        }
        final cuentas = CuentaRepositoryDrift(db);
        if (await cuentas.obtenerPorId('bcp') == null) {
          await cuentas.crear(
            const Cuenta(
              id: 'bcp',
              nombre: 'Débito BCP',
              tipo: TipoCuenta.debito,
              moneda: Moneda.pen,
              saldoActual: 9000,
            ),
          );
        }
      });

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> abrir(
    WidgetTester tester,
    Widget pantalla, {
    double ancho = 390,
    double escala = 1,
    ThemeData? tema,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = Size(ancho, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overridesModoLocal(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: tema,
          navigatorKey: navegador,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: const Scaffold(body: Text('inicio')),
        ),
      ),
    );
    navegador.currentState!.push(MaterialPageRoute(builder: (_) => pantalla));
    await asentar(tester);
  }

  Future<void> guardarComoRetroactivo(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await asentar(tester);
  }

  testWidgets('cuotas fijas que debo: muestra el selector con 3 modos', (
    tester,
  ) async {
    await sembrar(tester, _credito());
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    expect(find.text('Pagar cuota'), findsOneWidget);
    expect(find.text('Adelantar cuotas'), findsOneWidget);
    expect(find.text('Abono a capital'), findsOneWidget);
    // Por defecto: pagar cuota, con el monto de la cuota.
    expect(find.text('Monto pagado'), findsOneWidget);
  });

  testWidgets('abono a capital: estimación y registro', (tester) async {
    await sembrar(tester, _credito());
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    await tester.tap(find.text('Abono a capital'));
    await tester.pumpAndSettle();
    expect(find.text('Monto pagado'), findsNothing);
    expect(
      find.text('Cuotas que te quedan según tu banco (opcional)'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto del abono'),
      '3000',
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(textoEstimacionAbono(quedan: 13, antes: 24)),
      findsOneWidget,
    );
    // Fase 84b: la vista previa suma la última cuota cuando cambia.
    expect(
      find.text(
        'Estimamos que te quedarán 13 cuotas (antes 24). Confírmalo con tu '
        'banco. Tu última cuota bajaría a S/ 300.69 (antes S/ 450.00).',
      ),
      findsOneWidget,
    );

    await guardarComoRetroactivo(tester);
    final d = (await tester.runAsync(() => deudas.obtenerPorId('auto')))!;
    expect(d.numeroCuotasTotal, 25);
    expect(d.montoAbonadoCapital, 3000);
    expect(find.text('inicio'), findsOneWidget, reason: 'volvió atrás');
  });

  testWidgets('abono: lo que dice el banco manda; fuera de rango se avisa', (
    tester,
  ) async {
    await sembrar(tester, _credito());
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    await tester.tap(find.text('Abono a capital'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto del abono'),
      '3000',
    );
    final banco = find.widgetWithText(
      TextFormField,
      'Cuotas que te quedan según tu banco (opcional)',
    );
    await tester.enterText(banco, '30');
    await tester.pumpAndSettle();
    expect(
      find.text('Las cuotas según tu banco deben estar entre 0 y 24.'),
      findsOneWidget,
    );
    await tester.enterText(banco, '15');
    await tester.pumpAndSettle();
    await guardarComoRetroactivo(tester);
    final d = (await tester.runAsync(() => deudas.obtenerPorId('auto')))!;
    expect(d.numeroCuotasTotal, 27);
  });

  testWidgets('adelantar cuotas: contador, aviso y 3 pagos', (tester) async {
    final semantica = tester.ensureSemantics();
    await sembrar(tester, _credito());
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    await tester.tap(find.text('Adelantar cuotas'));
    await tester.pumpAndSettle();
    expect(find.text(avisoAdelantoCuotas), findsOneWidget);
    expect(
      find.text(
        'Tu banco puede cobrar menos por adelantar; si es así, registra el '
        'monto real',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Una cuota más'));
    await tester.pump();
    await tester.tap(find.byTooltip('Una cuota más'));
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(find.bySemanticsLabel('3 de 24 cuotas pendientes'), findsOneWidget);
    semantica.dispose();
    await guardarComoRetroactivo(tester);
    final d = (await tester.runAsync(() => deudas.obtenerPorId('auto')))!;
    expect(d.numeroCuotasPagadas, 15);
    expect(d.montoPagado, 5400 + 1350);
  });

  testWidgets('pago libre y "me deben" no muestran selector', (tester) async {
    await sembrar(
      tester,
      _credito(id: 'pl', estructura: EstructuraPago.pagoLibre),
    );
    await sembrar(
      tester,
      _credito(id: 'md', direccion: DireccionDeuda.meDeben),
    );
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'pl'));
    expect(find.text('Abono a capital'), findsNothing);
    expect(find.text('Adelantar cuotas'), findsNothing);

    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'md'));
    expect(find.text('Abono a capital'), findsNothing);
    expect(find.text('Monto cobrado'), findsOneWidget);
  });

  testWidgets('modoInicial abono con monto sugerido editable', (tester) async {
    await sembrar(tester, _credito());
    await abrir(
      tester,
      const PagoDeudaNuevoScreen(
        deudaId: 'auto',
        modoInicial: ModoPagoDeuda.abono,
        montoEsperadoInicial: 100,
      ),
    );
    final campo = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Monto del abono'),
    );
    expect(campo.controller!.text, '100.00');
    final seleccionado = tester.getSemantics(
      find.bySemanticsLabel('Abono a capital'),
    );
    expect(seleccionado.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('360 dp con texto 1.3×: los tres modos sin desbordes', (
    tester,
  ) async {
    await sembrar(tester, _credito());
    await abrir(
      tester,
      const PagoDeudaNuevoScreen(deudaId: 'auto'),
      ancho: 360,
      escala: 1.3,
    );
    for (final modo in ['Adelantar cuotas', 'Abono a capital', 'Pagar cuota']) {
      await tester.tap(find.text(modo));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: modo);
    }
  });

  for (final (nombre, tema) in [
    ('claro', appThemeClaro()),
    ('oscuro', appThemeOscuro()),
  ]) {
    testWidgets('Fase 84b (C): abono de 200 muestra la última cuota; 360 dp '
        'con texto 1.3× sin desbordes ($nombre)', (tester) async {
      await sembrar(tester, _credito());
      await abrir(
        tester,
        const PagoDeudaNuevoScreen(deudaId: 'auto'),
        ancho: 360,
        escala: 1.3,
        tema: tema,
      );
      await tester.tap(find.text('Abono a capital'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto del abono'),
        '200',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Caso B: no libera cuota (24 → 24), pero la última baja a 54.49.
      expect(
        find.text(
          'Estimamos que te quedarán 24 cuotas (antes 24). Confírmalo con '
          'tu banco. Tu última cuota bajaría a S/ 54.49 (antes S/ 450.00).',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Monto de la última cuota según tu banco (opcional)'),
        findsOneWidget,
      );
    });
  }

  testWidgets('Fase 84b: la última cuota del banco manda en la vista previa '
      'y al guardar; fuera de rango se avisa', (tester) async {
    await sembrar(tester, _credito());
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    await tester.tap(find.text('Abono a capital'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto del abono'),
      '3000',
    );
    final ultima = find.widgetWithText(
      TextFormField,
      'Monto de la última cuota según tu banco (opcional)',
    );
    await tester.enterText(ultima, '500');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La última cuota según tu banco debe ser mayor a 0 y no mayor a '
        'S/ 450.00.',
      ),
      findsOneWidget,
    );
    await tester.enterText(ultima, '280');
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tu última cuota bajaría a S/ 280.00'),
      findsOneWidget,
    );
    await guardarComoRetroactivo(tester);
    final d = (await tester.runAsync(() => deudas.obtenerPorId('auto')))!;
    expect(d.numeroCuotasTotal, 25);
    expect(d.montoUltimaCuota, 280);
  });

  testWidgets('Fase 85 (A.3): otro número de cuotas sin última → pide el '
      'monto de la última', (tester) async {
    await sembrar(tester, _credito());
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    await tester.tap(find.text('Abono a capital'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto del abono'),
      '3000',
    );
    final banco = find.widgetWithText(
      TextFormField,
      'Cuotas que te quedan según tu banco (opcional)',
    );
    // Igual a la estimación (13): no hace falta.
    await tester.enterText(banco, '13');
    await tester.pumpAndSettle();
    expect(find.text(avisoUltimaCuotaBanco), findsNothing);
    await tester.enterText(banco, '15');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Si tu banco te da el monto de la última cuota, ingrésalo para un '
        'saldo exacto',
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.widgetWithText(
        TextFormField,
        'Monto de la última cuota según tu banco (opcional)',
      ),
      '200',
    );
    await tester.pumpAndSettle();
    expect(find.text(avisoUltimaCuotaBanco), findsNothing);
  });

  testWidgets('Fase 84b: pagar la última cuota sugiere F', (tester) async {
    await sembrar(
      tester,
      Deuda(
        id: 'auto',
        nombreDeuda: 'Crédito auto',
        tipoDeuda: TipoDeuda.prestamoPersonal,
        tipoAcreedor: TipoAcreedor.entidadFinanciera,
        nombreAcreedor: 'BCP',
        moneda: Moneda.pen,
        montoTotal: 1000,
        montoPagado: 900 + 300,
        tieneInteres: false,
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasTotal: 3,
        numeroCuotasPagadas: 2,
        montoCuota: 450,
        periodicidadCuotas: PeriodicidadCuota.mensual,
        fechaInicio: DateTime(2026, 1, 15),
        enMora: false,
        estado: EstadoDeuda.activa,
        montoAbonadoCapital: 300,
        montoUltimaCuota: 120.5,
      ),
    );
    await abrir(tester, const PagoDeudaNuevoScreen(deudaId: 'auto'));
    final campo = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Monto pagado'),
    );
    expect(campo.controller!.text, '120.50');
  });

  testWidgets('el historial marca "Abono a capital"', (tester) async {
    await sembrar(tester, _credito());
    await tester.runAsync(
      () => pagos.crear(
        PagoDeuda(
          id: 'ab',
          deudaId: 'auto',
          montoPagado: 3000,
          fechaPago: DateTime(2026, 12, 20),
          tipo: TipoPagoDeuda.abonoCapital,
        ),
      ),
    );
    await abrir(tester, const HistorialPagosDeudaScreen(deudaId: 'auto'));
    expect(find.text('Abono a capital'), findsOneWidget);
  });
}
