import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_plan_repository_shared_prefs.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/deudas_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/plan_pago_screen.dart';
import 'package:finanzas_automaticas/presentation/state/plan_pago_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 83 (E) — pantalla "Mi plan de pago" con los datos de ejemplo.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final ahora = DateTime(2026, 11, 17);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> sembrar(WidgetTester tester) => tester.runAsync(
    () => SembrarDatosDemo(
      cuentaRepository: CuentaRepositoryDrift(db),
      categoriaRepository: CategoriaRepositoryDrift(db),
      transaccionRepository: TransaccionRepositoryDrift(db),
      deudaRepository: DeudaRepositoryDrift(db),
      pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
    ).call(),
  );

  Future<void> montar(
    WidgetTester tester,
    Widget pantalla, {
    double escala = 1.0,
    Size tamano = const Size(390, 3000),
    ThemeData? tema,
  }) async {
    tester.view.physicalSize = tamano;
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
          theme: tema ?? appThemeOscuro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: pantalla,
          onGenerateRoute: (s) => MaterialPageRoute(
            builder: (_) =>
                Scaffold(body: Text('Ruta ${s.name} ${s.arguments}')),
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
  }

  testWidgets('estructura: héroe con fecha (aprox.), comparador, presupuesto, '
      'lista con "Paga primero" y aviso de estimación', (tester) async {
    await sembrar(tester);
    await montar(tester, PlanPagoScreen(ahora: ahora));

    expect(find.text('Mi plan de pago'), findsOneWidget);
    expect(find.text('Puedes estar libre de deudas en'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^\w+ \d{4} \(aprox\.\)$')),
      findsOneWidget,
    );
    expect(find.text('Cuánto puedes pagar de más cada mes'), findsOneWidget);
    expect(find.text('Orden de pago'), findsOneWidget);
    expect(find.textContaining('Paga primero: '), findsOneWidget);
    expect(find.text(avisoEstimacionPlan), findsOneWidget);
    // Lucía (me deben) nunca entra al plan.
    expect(find.textContaining('Lucía'), findsNothing);
    // Fase 84 (E): el plan no paga solo; cada fila abre el registro de
    // pago (ver plan_pago_registrar_test.dart). Fase 85: la única acción
    // "Pagar" es "Pagar tarjeta", que abre una transferencia (ver
    // transferencia_ui_test.dart).
    expect(find.textContaining('Pagar '), findsOneWidget);
    expect(find.text('Pagar tarjeta'), findsOneWidget);
  });

  testWidgets('Avalancha / Bola de nieve: tarjetas accesibles, la elección se '
      'guarda y cambia el motivo de "Paga primero"', (tester) async {
    final semantics = tester.ensureSemantics();
    await sembrar(tester);
    await montar(tester, PlanPagoScreen(ahora: ahora));

    SemanticsData datos(Pattern etiqueta) =>
        tester.getSemantics(find.bySemanticsLabel(etiqueta)).getSemanticsData();
    final bola = RegExp('^Bola de nieve');
    final avalancha = RegExp('^Avalancha');
    for (final e in [bola, avalancha]) {
      expect(datos(e).flagsCollection.isButton, isTrue);
      expect(
        tester.getSize(find.bySemanticsLabel(e)).height,
        greaterThanOrEqualTo(44),
      );
    }

    await tester.tap(find.bySemanticsLabel(bola));
    await tester.pumpAndSettle();
    expect(datos(bola).flagsCollection.isSelected, Tristate.isTrue);
    expect(datos(avalancha).flagsCollection.isSelected, Tristate.isFalse);
    expect(find.text('Paga primero: menor saldo'), findsOneWidget);
    expect(
      PreferenciasPlanRepositorySharedPrefs(prefs).leer().estrategia,
      EstrategiaPago.bolaDeNieve,
    );

    await tester.tap(find.bySemanticsLabel(avalancha));
    await tester.pumpAndSettle();
    expect(find.textContaining('Paga primero: mayor interés'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('presupuesto extra: chips +50/+100/+200 suman, se guardan y '
      'recalculan (más extra ⇒ libre antes o igual)', (tester) async {
    await sembrar(tester);
    await montar(tester, PlanPagoScreen(ahora: ahora));

    String fecha() =>
        tester.widget<Text>(find.textContaining(RegExp(r'\(aprox\.\)$'))).data!;
    final antes = fecha();

    await tester.tap(find.text('+100'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+200'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(find.text('S/ 300.00/mes'), findsOneWidget);
    expect(
      PreferenciasPlanRepositorySharedPrefs(prefs).leer().extraMensual,
      300,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '300',
    );
    // Con más extra la fecha no puede ser posterior.
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    int indice(String t) {
      final partes = t.split(' ');
      return int.parse(partes[1]) * 12 + meses.indexOf(partes[0]);
    }

    expect(indice(fecha()), lessThanOrEqualTo(indice(antes)));

    // Escribir a mano también recalcula y guarda.
    await tester.enterText(find.byType(TextField), '50');
    await tester.pumpAndSettle();
    expect(
      PreferenciasPlanRepositorySharedPrefs(prefs).leer().extraMensual,
      50,
    );
  });

  testWidgets('deuda sin tasa: "Falta la tasa" con acceso a editar', (
    tester,
  ) async {
    await tester.runAsync(
      () => DeudaRepositoryDrift(db).crear(
        Deuda(
          id: 'sin-tasa',
          nombreDeuda: 'Préstamo de la caja',
          tipoDeuda: TipoDeuda.prestamoPersonal,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: 'Caja',
          moneda: Moneda.pen,
          montoTotal: 900,
          montoPagado: 0,
          tieneInteres: true,
          estructuraPago: EstructuraPago.pagoLibre,
          pagoMinimo: 100,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
        ),
      ),
    );
    await montar(tester, PlanPagoScreen(ahora: ahora));

    expect(find.textContaining('Falta la tasa'), findsOneWidget);
    expect(find.textContaining('no tienen tasa'), findsOneWidget);
    await tester.tap(find.text('Agregar la tasa'));
    await tester.pumpAndSettle();
    expect(find.text('Ruta /deudas/nueva sin-tasa'), findsOneWidget);
  });

  testWidgets('estado vacío: sin deudas (o solo "me deben") no rompe la '
      'pantalla', (tester) async {
    await tester.runAsync(
      () => DeudaRepositoryDrift(db).crear(
        Deuda(
          id: 'cobro',
          nombreDeuda: 'Préstamo a Lucía',
          tipoDeuda: TipoDeuda.deudaInformal,
          tipoAcreedor: TipoAcreedor.personaNatural,
          nombreAcreedor: 'Lucía',
          moneda: Moneda.pen,
          montoTotal: 380,
          montoPagado: 0,
          tieneInteres: false,
          estructuraPago: EstructuraPago.pagoLibre,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
          direccion: DireccionDeuda.meDeben,
        ),
      ),
    );
    await montar(tester, PlanPagoScreen(ahora: ahora));
    expect(find.text('No tienes deudas que planificar'), findsOneWidget);
    expect(find.text('Agregar deuda'), findsOneWidget);
  });

  test('Inicio: sin estimación posible no hay fecha de plan (la tarjeta '
      'sigue como "Tus deudas")', () async {
    await DeudaRepositoryDrift(db).crear(
      Deuda(
        id: 'sin-minimo',
        nombreDeuda: 'Informal',
        tipoDeuda: TipoDeuda.deudaInformal,
        tipoAcreedor: TipoAcreedor.personaNatural,
        nombreAcreedor: 'Ana',
        moneda: Moneda.pen,
        montoTotal: 300,
        montoPagado: 0,
        tieneInteres: false,
        estructuraPago: EstructuraPago.pagoLibre,
        fechaInicio: DateTime(2026, 1, 1),
        enMora: false,
        estado: EstadoDeuda.activa,
      ),
    );
    final c = ProviderContainer(
      overrides: [
        ...overridesModoLocal(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(c.dispose);
    // Sin mínimo ni extra, a este ritmo no se termina.
    await c.read(comparacionesPlanProvider.future);
    expect(c.read(fechaLibrePlanProvider), isNull);

    // Con extra sí hay estimación.
    await c.read(configPlanPagoProvider.notifier).cambiarExtra(100);
    await c.read(comparacionesPlanProvider.future);
    expect(c.read(fechaLibrePlanProvider), isNotNull);
  });

  testWidgets('Fase 84 (A.1): con extra 0 el ahorro viene de reasignar las '
      'cuotas liberadas; con extra, "con tu pago extra…"', (tester) async {
    await tester.runAsync(() async {
      final repo = DeudaRepositoryDrift(db);
      // Una corta sin interés (3 × 100) y una larga con interés y mínimo
      // que sí cubre su interés: "sin plan" termina, pero más tarde.
      await repo.crear(
        Deuda(
          id: 'corta',
          nombreDeuda: 'Corta',
          tipoDeuda: TipoDeuda.compraCuotas,
          tipoAcreedor: TipoAcreedor.comercio,
          nombreAcreedor: 'Tienda',
          moneda: Moneda.pen,
          montoTotal: 300,
          montoPagado: 0,
          tieneInteres: false,
          estructuraPago: EstructuraPago.cuotasFijas,
          numeroCuotasTotal: 3,
          numeroCuotasPagadas: 0,
          montoCuota: 100,
          periodicidadCuotas: PeriodicidadCuota.mensual,
          fechaInicio: DateTime(2026, 12, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
        ),
      );
      await repo.crear(
        Deuda(
          id: 'larga',
          nombreDeuda: 'Larga',
          tipoDeuda: TipoDeuda.prestamoPersonal,
          tipoAcreedor: TipoAcreedor.entidadFinanciera,
          nombreAcreedor: 'Caja',
          moneda: Moneda.pen,
          montoTotal: 2000,
          montoPagado: 0,
          tieneInteres: true,
          tasaInteres: 40,
          estructuraPago: EstructuraPago.pagoLibre,
          pagoMinimo: 100,
          fechaInicio: DateTime(2026, 1, 1),
          enMora: false,
          estado: EstadoDeuda.activa,
        ),
      );
    });
    await montar(tester, PlanPagoScreen(ahora: ahora));

    expect(find.textContaining('meses antes que sin plan'), findsOneWidget);
    expect(
      find.text('Ahorro por reasignar las cuotas que vas liberando'),
      findsOneWidget,
    );

    await tester.tap(find.text('+50'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Ahorro con tu pago extra y las cuotas liberadas'),
      findsOneWidget,
    );
  });

  testWidgets('Fase 84 (A.2/A.3): la Visa de ejemplo trae TCEA 48 % y su fila '
      'aclara que no cobra si pagas el total', (tester) async {
    await sembrar(tester);
    await montar(tester, PlanPagoScreen(ahora: ahora));

    expect(find.text('Visa BCP'), findsOneWidget);
    expect(find.textContaining('48 % de interés anual'), findsOneWidget);
    expect(find.text(notaTasaTarjeta), findsOneWidget);
    // Con los datos de ejemplo "sin plan" no termina (la deuda informal no
    // tiene mínimo): se explica en vez de mostrar un ahorro inventado.
    expect(
      find.textContaining('Sin plan, alguna deuda no se termina'),
      findsOneWidget,
    );
  });

  testWidgets('entrada desde el hub: "Ver mi plan de pago"', (tester) async {
    await sembrar(tester);
    await montar(tester, const DeudasScreen());
    await tester.tap(find.text('Ver mi plan de pago'));
    await tester.pumpAndSettle();
    expect(find.text('Ruta /plan-pago null'), findsOneWidget);
  });

  test('Fase 84b (C): texto del supuesto, también con extra 0', () {
    expect(
      textoSupuestoPlan(minimos: 1250, extra: 100, moneda: Moneda.pen),
      'Supone que destinas S/ 1,350.00 al mes a tus deudas (mínimos '
      'S/ 1,250.00 + extra S/ 100.00) y que reasignas lo que vas liberando',
    );
    expect(
      textoSupuestoPlan(minimos: 1250, extra: 0, moneda: Moneda.pen),
      'Supone que destinas S/ 1,250.00 al mes a tus deudas (mínimos '
      'S/ 1,250.00 + extra S/ 0.00) y que reasignas lo que vas liberando',
    );
  });

  testWidgets('Fase 84b (C): el héroe muestra el supuesto con los mínimos '
      'del plan, con extra 0 y con extra', (tester) async {
    await sembrar(tester);
    await montar(tester, PlanPagoScreen(ahora: ahora));
    final c = ProviderScope.containerOf(
      tester.element(find.byType(PlanPagoScreen)),
    );
    ResultadoPlan planVigente() {
      final comp = c.read(comparacionesPlanProvider).requireValue[Moneda.pen]!;
      return comp.plan(
        c.read(configPlanPagoProvider).estrategia ??
            comp.recomendacion.estrategia,
      );
    }

    final plan0 = planVigente();
    expect(plan0.extraMensual, 0);
    // Mínimos de los datos de ejemplo: cuotas del préstamo y la laptop +
    // mínimo de la Visa (el préstamo informal no tiene mínimo).
    expect(plan0.minimosMensuales, greaterThan(0));
    expect(
      find.text(
        textoSupuestoPlan(
          minimos: plan0.minimosMensuales,
          extra: 0,
          moneda: Moneda.pen,
        ),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('+100'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    final plan100 = planVigente();
    expect(plan100.extraMensual, 100);
    expect(
      find.text(
        textoSupuestoPlan(
          minimos: plan100.minimosMensuales,
          extra: 100,
          moneda: Moneda.pen,
        ),
      ),
      findsOneWidget,
    );
  });

  for (final (nombre, tema) in [
    ('oscuro', appThemeOscuro()),
    ('claro', appThemeClaro()),
  ]) {
    testWidgets('Fase 84b (C): 360 dp con texto al 130 % sin desbordes '
        '($nombre)', (tester) async {
      await sembrar(tester);
      await montar(
        tester,
        PlanPagoScreen(ahora: ahora),
        escala: 1.3,
        tamano: const Size(360, 4000),
        tema: tema,
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Supone que destinas'), findsOneWidget);
    });

    testWidgets('texto al 130 % a 390 dp sin desbordes; chips ≥ 44 dp '
        '($nombre)', (tester) async {
      await sembrar(tester);
      await montar(
        tester,
        PlanPagoScreen(ahora: ahora),
        escala: 1.3,
        tamano: const Size(390, 3600),
        tema: tema,
      );
      expect(tester.takeException(), isNull);
      for (final chip in ['+50', '+100', '+200']) {
        final size = tester.getSize(
          find.ancestor(of: find.text(chip), matching: find.byType(ActionChip)),
        );
        expect(size.height, greaterThanOrEqualTo(44));
      }
    });
  }
}
