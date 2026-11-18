import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/consejero.dart';
import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_consejero_repository_shared_prefs.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/capacidad_pago_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/consejero_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/plan_pago_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/simulador_screen.dart';
import 'package:finanzas_automaticas/presentation/state/consejero_providers.dart';
import 'package:finanzas_automaticas/presentation/state/plan_pago_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 86 (F) — capacidad, simulador, consejero y su navegación, con los
/// datos de ejemplo sembrados el 17 nov 2026 (historial ago–oct).
void main() {
  final ahora = DateTime(2026, 11, 17, 10);
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> asentar(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> sembrar(WidgetTester tester) => tester.runAsync(
    () => SembrarDatosDemo(
      cuentaRepository: CuentaRepositoryDrift(db),
      categoriaRepository: CategoriaRepositoryDrift(db),
      transaccionRepository: TransaccionRepositoryDrift(db),
      deudaRepository: DeudaRepositoryDrift(db),
      pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
    ).call(ahora: ahora),
  );

  late ProviderContainer contenedor;

  Future<void> montar(
    WidgetTester tester,
    Widget home, {
    double ancho = 390,
    double escala = 1,
    ThemeData? tema,
  }) async {
    tester.view.physicalSize = Size(ancho, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overridesModoLocal(prefs),
          appDatabaseProvider.overrideWithValue(db),
          ahoraConsejeroProvider.overrideWithValue(ahora),
        ],
        child: MaterialApp(
          theme: tema ?? appThemeClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: home,
          onGenerateRoute: (s) => switch (s.name) {
            '/plan-pago/capacidad' => MaterialPageRoute<double>(
              builder: (_) => CapacidadPagoScreen(ahora: ahora),
            ),
            '/plan-pago/simulador' => MaterialPageRoute<double>(
              builder: (_) => SimuladorScreen(
                extraInicial: s.arguments as double?,
                ahora: ahora,
              ),
            ),
            '/consejero' => MaterialPageRoute(
              builder: (_) => const ConsejeroScreen(),
            ),
            _ => MaterialPageRoute(
              builder: (_) => Scaffold(body: Text('Ruta ${s.name}')),
            ),
          },
        ),
      ),
    );
    contenedor = ProviderScope.containerOf(tester.element(find.byWidget(home)));
    await asentar(tester);
  }

  double extraGuardado() =>
      contenedor.read(configPlanPagoProvider).extraMensual;

  group('Capacidad', () {
    testWidgets('datos suficientes: recomienda la segura, muestra la típica y '
        'la guarda como pago extra', (tester) async {
      await sembrar(tester);
      await montar(tester, CapacidadPagoScreen(ahora: ahora));
      expect(find.text('TUS ÚLTIMOS 3 MESES COMPLETOS'), findsOneWidget);
      // Fase 87: segura = peor margen mensual (sep: 3200 − 1750 − 320) − 770.
      expect(find.text('S/ 360.00 extra al mes'), findsOneWidget);
      expect(find.textContaining('te sobrarían S/ 620.00'), findsOneWidget);
      expect(find.text('S/ 770.00'), findsOneWidget, reason: 'mínimos');
      expect(find.text(avisoCapacidad), findsOneWidget);

      // Menos colchón (5 %) → 3200 − 1750 − 160 − 770 = 520.
      await tester.tap(find.byTooltip('Menos colchón'));
      await tester.pumpAndSettle();
      expect(find.text('S/ 520.00 extra al mes'), findsOneWidget);
      await tester.tap(find.byTooltip('Más colchón'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Usar este monto como pago extra'));
      await tester.tap(find.text('Usar este monto como pago extra'));
      await asentar(tester);
      expect(extraGuardado(), 360);
      expect(prefs.getDouble('plan_pago.extra_mensual'), 360);
    });

    testWidgets('datos insuficientes: pide un monto manual', (tester) async {
      await tester.runAsync(
        () => CuentaRepositoryDrift(db).crear(
          const Cuenta(
            id: 'c',
            nombre: 'Débito',
            tipo: TipoCuenta.debito,
            moneda: Moneda.pen,
            saldoActual: 100,
          ),
        ),
      );
      await montar(tester, CapacidadPagoScreen(ahora: ahora));
      expect(find.text('Aún no hay datos suficientes'), findsOneWidget);
      expect(find.textContaining('extra al mes'), findsNothing);
      final usar = find.widgetWithText(
        FilledButton,
        'Usar este monto como pago extra',
      );
      expect(tester.widget<FilledButton>(usar).onPressed, isNull);
      await tester.enterText(find.byType(TextField), '150');
      await tester.pumpAndSettle();
      await tester.tap(usar);
      await asentar(tester);
      expect(extraGuardado(), 150);
    });

    testWidgets('segura negativa y típica positiva: lo dice y ofrece solo la '
        'opción arriesgada', (tester) async {
      await sembrar(tester);
      // Agosto con S/ 5,000 de gasto extra: el peor escenario no alcanza.
      await tester.runAsync(() async {
        final comida = (await CategoriaRepositoryDrift(db).obtenerTodas())
            .firstWhere(
              (c) => c.nombre == 'Comida' && c.tipo == TipoCategoria.gasto,
            );
        await TransaccionRepositoryDrift(db).crear(
          Transaccion(
            id: 'grande',
            cuentaId: SembrarDatosDemo.idCuentaBcp,
            categoriaId: comida.id,
            monto: 5000,
            moneda: Moneda.pen,
            tipo: TipoTransaccion.gasto,
            concepto: 'Gasto grande',
            metodoPago: MetodoPago.tarjeta,
            esRecurrente: false,
            fuenteCaptura: FuenteCaptura.manual,
            fecha: DateTime(2026, 8, 20),
          ),
        );
      });
      await montar(tester, CapacidadPagoScreen(ahora: ahora));
      // Agosto: 3600 − 6900 − 360 = −3660; − 770 → −4430. Típica 620.
      expect(find.text(textoSoloMesTipico('S/ 620.00')), findsOneWidget);
      expect(
        find.text(
          'En tu peor mes no alcanzó para tus mínimos; en un mes típico te '
          'sobran S/ 620.00',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('te faltan S/ 4,430.00'), findsOneWidget);
      expect(find.text('Usar este monto como pago extra'), findsNothing);
      expect(find.textContaining('extra al mes'), findsNothing);
      final arriesgado = find.text(
        'Usar S/ 620.00 (arriesgado en meses bajos)',
      );
      expect(arriesgado, findsOneWidget);
      await tester.ensureVisible(arriesgado);
      await tester.tap(arriesgado);
      await asentar(tester);
      expect(extraGuardado(), 620);
    });
  });

  testWidgets('Simulador: compara contra el plan actual; − / + y pago único', (
    tester,
  ) async {
    await sembrar(tester);
    await montar(tester, SimuladorScreen(ahora: ahora));
    expect(find.text('Igual que tu plan actual'), findsOneWidget);
    expect(find.text(avisoSimulador), findsOneWidget);
    expect(find.text('Plan actual'), findsOneWidget);
    expect(find.text('Este escenario'), findsOneWidget);

    await tester.tap(find.byTooltip('Sumar S/ 50.00'));
    await tester.pumpAndSettle();
    // Con la demo, S/ 50 más ahorra intereses pero no adelanta un mes
    // entero; nunca debe salir "después".
    expect(find.textContaining('Ahorras S/'), findsOneWidget);
    expect(find.textContaining('después'), findsNothing);
    expect(find.text('Usar S/ 50.00 en mi plan'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Monto del pago único'),
      '500',
    );
    await tester.tap(find.byTooltip('Un mes después'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lo pagas en 2 meses'), findsOneWidget);
    expect(
      find.text('El pago único no se guarda: es solo para comparar.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Usar S/ 50.00 en mi plan'));
    await tester.tap(find.text('Usar S/ 50.00 en mi plan'));
    await asentar(tester);
    expect(extraGuardado(), 50);
  });

  group('Consejero', () {
    testWidgets('con consejos: revisión semanal, a lo sumo 3, "Ver más", '
        'descartar persiste', (tester) async {
      await sembrar(tester);
      await montar(tester, const ConsejeroScreen());
      expect(find.text('Tus últimos 7 días'), findsOneWidget);
      expect(find.text('Próximos 7 días'), findsOneWidget);
      expect(find.text(pieConsejero), findsOneWidget);

      final todos = contenedor.read(consejosProvider).requireValue;
      expect(todos.length, greaterThan(maximoConsejosVisibles));
      expect(find.text('Descartar'), findsNWidgets(maximoConsejosVisibles));
      expect(find.text('Ver más (${todos.length - 3})'), findsOneWidget);
      // El de mayor prioridad: el préstamo vence en 3 días.
      expect(todos.first.regla, ReglaConsejo.vencePronto);
      expect(find.text(todos.first.titulo), findsOneWidget);

      await tester.tap(find.textContaining('Ver más'));
      await tester.pumpAndSettle();
      expect(find.text('Ver menos'), findsOneWidget);
      expect(find.text('Descartar'), findsNWidgets(todos.length));
      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Descartar').first);
      await asentar(tester);
      expect(find.text(todos.first.titulo), findsNothing);
      final guardado = PreferenciasConsejeroRepositorySharedPrefs(prefs).leer();
      expect(guardado[todos.first.id]!.tipo, TipoEstadoConsejo.descartado);
      // El siguiente sube a los 3 visibles.
      expect(find.text(todos[3].titulo), findsOneWidget);
    });

    testWidgets('sin consejos: lo dice sin inventar', (tester) async {
      await montar(tester, const ConsejeroScreen());
      expect(find.textContaining('No tengo consejos nuevos'), findsOneWidget);
      expect(find.text('Descartar'), findsNothing);
      expect(find.text('No vence nada esta semana.'), findsOneWidget);
    });

    testWidgets('posponer oculta el consejo', (tester) async {
      await sembrar(tester);
      await montar(tester, const ConsejeroScreen());
      final primero = contenedor.read(consejosProvider).requireValue.first;
      await tester.tap(find.text('Posponer 7 días').first);
      await asentar(tester);
      expect(find.text(primero.titulo), findsNothing);
      expect(
        PreferenciasConsejeroRepositorySharedPrefs(
          prefs,
        ).leer()[primero.id]!.tipo,
        TipoEstadoConsejo.pospuesto,
      );
    });
  });

  group('Navegación', () {
    testWidgets('Plan: "Calcular mi capacidad" y "Simular otro escenario"; '
        'al volver el campo muestra el extra guardado', (tester) async {
      await sembrar(tester);
      await montar(tester, PlanPagoScreen(ahora: ahora));
      await tester.ensureVisible(find.text('Calcular mi capacidad'));
      await tester.tap(find.text('Calcular mi capacidad'));
      await asentar(tester);
      expect(find.byType(CapacidadPagoScreen), findsOneWidget);
      await tester.ensureVisible(find.text('Usar este monto como pago extra'));
      await tester.tap(find.text('Usar este monto como pago extra'));
      await asentar(tester);
      expect(find.byType(PlanPagoScreen), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Pago extra mensual'),
            )
            .controller!
            .text,
        '360',
      );

      await tester.ensureVisible(find.text('Simular otro escenario'));
      await tester.tap(find.text('Simular otro escenario'));
      await asentar(tester);
      expect(find.byType(SimuladorScreen), findsOneWidget);
      expect(find.text('Igual que tu plan actual'), findsOneWidget);
    });

    testWidgets('Inicio: línea compacta con el consejo principal → consejero', (
      tester,
    ) async {
      await sembrar(tester);
      await montar(tester, const Scaffold(body: ConsejoDestacadoLinea()));
      final primero = contenedor.read(consejosProvider).requireValue.first;
      expect(find.text(primero.titulo), findsOneWidget);
      expect(
        tester.getSize(find.byType(ConsejoDestacadoLinea)).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byType(ConsejoDestacadoLinea));
      await asentar(tester);
      expect(find.byType(ConsejeroScreen), findsOneWidget);
    });

    testWidgets('Inicio sin consejos: la línea no ocupa espacio', (
      tester,
    ) async {
      await montar(tester, const Scaffold(body: ConsejoDestacadoLinea()));
      expect(tester.getSize(find.byType(ConsejoDestacadoLinea)).height, 0);
    });
  });

  for (final (nombre, tema) in [
    ('claro', appThemeClaro()),
    ('oscuro', appThemeOscuro()),
  ]) {
    testWidgets('360 dp con texto al 130 % sin desbordes ($nombre)', (
      tester,
    ) async {
      await sembrar(tester);
      for (final pantalla in <Widget>[
        CapacidadPagoScreen(ahora: ahora),
        SimuladorScreen(ahora: ahora),
        const ConsejeroScreen(),
      ]) {
        await montar(tester, pantalla, ancho: 360, escala: 1.3, tema: tema);
        expect(tester.takeException(), isNull, reason: '$pantalla');
      }
      // Botones − / + de 48 dp.
      for (final b in find.byType(IconButton).evaluate()) {
        expect(
          tester.getSize(find.byWidget(b.widget)).height,
          greaterThanOrEqualTo(44),
        );
      }
    });
  }
}
