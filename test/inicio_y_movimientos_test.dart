import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/todos_los_movimientos_screen.dart';
import 'package:finanzas_automaticas/presentation/shared/fila_deuda.dart';
import 'package:finanzas_automaticas/presentation/shared/fila_movimiento.dart';
import 'package:finanzas_automaticas/presentation/shared/formatters.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 81 — Inicio nuevo y pantalla Movimientos con los datos de ejemplo
/// de `SembrarDatosDemo` (modo local, Drift en memoria):
/// cuentas Efectivo S/ 60 + BCP S/ 3,160 + Yape S/ 70 = S/ 3,290;
/// sueldo S/ 3,200, gastos S/ 2,560 (Comida 1,500 / Servicios 720 /
/// Transporte 340); deudas con saldo 880 / 1,890 / 150.
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

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
    Size tamano = const Size(390, 2600),
    ThemeData? tema,
  }) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await PerfilLocalNick.guardar(prefs);
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
          routes: {
            '/transacciones/todas': (_) =>
                const Scaffold(body: Text('Pantalla Movimientos')),
            '/deudas': (_) => const Scaffold(body: Text('Pantalla Deudas')),
            '/cuentas': (_) => const Scaffold(body: Text('Pantalla Cuentas')),
          },
        ),
      ),
    );
    // Drift resuelve en una zona real: dejar que termine.
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  double y(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  group('Inicio (01-inicio.png)', () {
    testWidgets('orden de secciones: héroe → Tus deudas → Próximos pagos → '
        'Movimientos recientes; sin las secciones viejas', (tester) async {
      await sembrar(tester);
      await montar(tester, const DashboardScreen());

      final orden = [
        find.text('Saldo total'),
        // Fase 83: con estimación del plan, la tarjeta de deudas se titula
        // "Libre de deudas en …" (01-inicio.png).
        find.textContaining('Libre de deudas en'),
        find.text('Próximos pagos'),
        find.text('Movimientos recientes'),
      ];
      for (final f in orden) {
        expect(f, findsOneWidget);
      }
      for (var i = 0; i < orden.length - 1; i++) {
        expect(y(tester, orden[i]), lessThan(y(tester, orden[i + 1])));
      }
      for (final viejo in [
        'SALDO TOTAL',
        'DEUDAS ACTIVAS',
        'GASTO POR CATEGORÍA',
        'INGRESOS (MES)',
      ]) {
        expect(find.text(viejo), findsNothing, reason: viejo);
      }
    });

    testWidgets('héroe: saldo total, resultado del mes con signo, ingresos, '
        'gastos y "3 cuentas" que abre Mis cuentas', (tester) async {
      await sembrar(tester);
      await montar(tester, const DashboardScreen());

      expect(find.text('S/ 3,290.00'), findsOneWidget);
      expect(find.text('+S/ 640.00 este mes'), findsOneWidget);
      expect(find.byIcon(Icons.north_east), findsOneWidget);
      expect(find.text('Ingresos'), findsOneWidget);
      expect(find.text('S/ 3,200.00'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('S/ 2,560.00'), findsOneWidget);

      await tester.tap(find.text('4 cuentas'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Cuentas'), findsOneWidget);
    });

    testWidgets('Tus deudas: 59% pagado y total que debes; abre Deudas', (
      tester,
    ) async {
      await sembrar(tester);
      await montar(tester, const DashboardScreen());

      expect(find.text('59% pagado'), findsOneWidget);
      // 880 + 1,890 + 150. Fase 82: "Me deben" sale de las deudas locales
      // (Lucía, S/ 380), fuera de lo que debo.
      expect(
        find.text('Debo S/ 4,120.00 · Me deben S/ 380.00'),
        findsOneWidget,
      );

      // Fase 83: título con la estimación del plan + botón "Mi plan".
      expect(
        // Fase 85 (A.2): "(aprox.)" — es una estimación del plan.
        find.textContaining(
          RegExp(r'^Libre de deudas en \w+ \d{4} \(aprox\.\)$'),
        ),
        findsOneWidget,
      );
      expect(find.text('Mi plan'), findsOneWidget);
      await tester.tap(find.textContaining('Libre de deudas en'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Deudas'), findsOneWidget);
    });

    testWidgets('Próximos pagos: 3 deudas ordenadas por urgencia, con chip '
        'de ícono + texto', (tester) async {
      await sembrar(tester);
      await montar(tester, const DashboardScreen());

      final filas = find.byType(FilaDeuda);
      expect(filas, findsNWidgets(3));

      // Orden esperado según la siembra (Fase 84: con la Visa): préstamo
      // vence el próximo día 20, laptop el 5 y la Visa paga el 28; la
      // informal no tiene fecha y queda fuera de las 3. Mismo criterio que
      // la app: primero las que vencen en ≤ 3 días, luego por fecha.
      final hoy = DateTime.now();
      DateTime proxima(int dia) => hoy.day <= dia
          ? DateTime(hoy.year, hoy.month, dia)
          : DateTime(hoy.year, hoy.month + 1, dia);
      final fechas = {
        'Préstamo personal · Cuota 9 de 10': proxima(20),
        'Laptop Lenovo · Cuota 4 de 12': proxima(5),
        'Visa BCP': proxima(28),
      };
      int grupo(DateTime f) => f.difference(hoy).inDays <= 3 ? 0 : 1;
      final esperado = fechas.keys.toList()
        ..sort((a, b) {
          final g = grupo(fechas[a]!).compareTo(grupo(fechas[b]!));
          return g != 0 ? g : fechas[a]!.compareTo(fechas[b]!);
        });
      for (final t in esperado) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      final ys = [for (final t in esperado) y(tester, find.text(t))];
      expect(ys, orderedEquals([...ys]..sort()), reason: '$esperado');
      expect(find.text('Debes a Luis (primo)'), findsNothing);

      // Cada fila lleva su chip, y cada chip ícono + texto.
      final chips = find.descendant(
        of: filas,
        matching: find.byType(ChipUrgencia),
      );
      expect(chips, findsNWidgets(3));
      expect(
        find.descendant(of: chips, matching: find.byType(Icon)),
        findsNWidgets(3),
      );
      // Montos: cuota en cuotas fijas, saldo en pago libre (la Visa).
      expect(find.text('S/ 440.00'), findsOneWidget);
      expect(find.text('S/ 210.00'), findsOneWidget);
      expect(find.text('S/ 1,200.00'), findsOneWidget);
    });

    testWidgets(
      'Movimientos recientes: 3 filas y "Ver todo" va a Movimientos',
      (tester) async {
        await sembrar(tester);
        await montar(tester, const DashboardScreen());

        expect(find.byType(FilaMovimiento), findsNWidgets(3));
        // Subtítulo "Categoría · Cuenta · Hoy/Ayer/fecha".
        expect(
          find.descendant(
            of: find.byType(FilaMovimiento),
            matching: find.textContaining(RegExp(r'^\w+ · .+ · .+$')),
          ),
          findsNWidgets(3),
        );

        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text('Movimientos recientes'),
              matching: find.byType(Row),
            ),
            matching: find.text('Ver todo'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pantalla Movimientos'), findsOneWidget);
      },
    );

    for (final (nombre, tema) in [
      ('oscuro', appThemeOscuro()),
      ('claro', appThemeClaro()),
    ]) {
      testWidgets('textScale 1.3 a 360 dp sin overflow (tema $nombre)', (
        tester,
      ) async {
        await sembrar(tester);
        await montar(
          tester,
          const DashboardScreen(),
          escala: 1.3,
          tamano: const Size(360, 3200),
          tema: tema,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('S/ 3,290.00'), findsOneWidget);
      });
    }

    testWidgets(
      'objetivos táctiles ≥ 44 dp (cuentas, Ver todo, avatar, campana)',
      (tester) async {
        await sembrar(tester);
        await montar(tester, const DashboardScreen());
        for (final f in [
          find.bySemanticsLabel('Ver mis 4 cuentas'),
          find.bySemanticsLabel('Ver todas las deudas'),
          find.bySemanticsLabel('Ver todos los movimientos'),
          find.bySemanticsLabel('Mi perfil'),
          find.byTooltip('Notificaciones'),
        ]) {
          final size = tester.getSize(f);
          expect(size.width, greaterThanOrEqualTo(44));
          expect(size.height, greaterThanOrEqualTo(44));
        }
      },
    );
  });

  group('Movimientos (02-movimientos.png)', () {
    int filas() => find.byType(FilaMovimiento).evaluate().length;

    testWidgets('mes actual por defecto: "Gasto del mes" con total, top '
        'categorías con % y 16 movimientos agrupados por día', (tester) async {
      await sembrar(tester);
      await montar(tester, const TodosLosMovimientosScreen());

      final mes = formatearMesActual();
      expect(find.text(mes), findsOneWidget);
      expect(find.text('Gasto del mes'), findsOneWidget);
      expect(find.text('S/ 2,560.00'), findsOneWidget);
      // 1,500 / 720 / 340 sobre 2,560 → 58.6 / 28.1 / 13.3 → 59 + 28 + 13.
      expect(find.text('Comida 59%'), findsOneWidget);
      expect(find.text('Servicios 28%'), findsOneWidget);
      expect(find.text('Transporte 13%'), findsOneWidget);
      expect(filas(), 16);
      // El último movimiento sembrado es del día 15 (o de hoy si es antes):
      // su grupo encabeza la lista como HOY / AYER / fecha.
      final hoy = DateTime.now();
      final dia = DateTime(hoy.year, hoy.month, hoy.day < 15 ? hoy.day : 15);
      final esperado = hoy.day == dia.day
          ? 'HOY'
          : hoy.day - 1 == dia.day
          ? 'AYER'
          : formatearDiaMesCorto(dia, ahora: hoy).toUpperCase();
      expect(find.text(esperado), findsOneWidget);
    });

    testWidgets(
      'buscar sin tildes ("cumpleanos") encuentra "Cena de cumpleaños"',
      (tester) async {
        await sembrar(tester);
        await montar(tester, const TodosLosMovimientosScreen());

        await tester.enterText(find.byType(TextField), 'cumpleanos');
        await tester.pumpAndSettle();
        expect(filas(), 1);
        expect(find.text('Cena de cumpleaños'), findsOneWidget);

        // Busca también por categoría.
        await tester.enterText(find.byType(TextField), 'servicios');
        await tester.pumpAndSettle();
        expect(filas(), 7);
      },
    );

    testWidgets('chips Gastos / Ingresos / Todo', (tester) async {
      await sembrar(tester);
      await montar(tester, const TodosLosMovimientosScreen());

      await tester.tap(find.text('Ingresos'));
      await tester.pumpAndSettle();
      expect(filas(), 1);
      expect(find.text('Sueldo'), findsWidgets);
      // "Gasto del mes" no depende del chip de tipo.
      expect(find.text('Gasto del mes'), findsOneWidget);

      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      expect(filas(), 15);

      await tester.tap(find.text('Todo'));
      await tester.pumpAndSettle();
      expect(filas(), 16);
    });

    testWidgets('filtro por cuenta desde la hoja de filtros', (tester) async {
      await sembrar(tester);
      await montar(tester, const TodosLosMovimientosScreen());

      await tester.tap(find.byIcon(Icons.filter_list));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todas las cuentas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yape').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      // Almuerzos, delivery, cena, Metropolitano y taxi.
      expect(filas(), 5);
      expect(find.bySemanticsLabel(RegExp('1 activos')), findsOneWidget);
    });

    testWidgets(
      'sin resultados de búsqueda → estado vacío y "Limpiar filtros"',
      (tester) async {
        await sembrar(tester);
        await montar(tester, const TodosLosMovimientosScreen());

        await tester.enterText(find.byType(TextField), 'zzzz');
        await tester.pumpAndSettle();
        expect(filas(), 0);
        expect(find.text('Sin resultados'), findsOneWidget);
        expect(
          find.text('No encontramos movimientos para «zzzz».'),
          findsOneWidget,
        );

        await tester.tap(find.text('Limpiar filtros'));
        await tester.pumpAndSettle();
        expect(filas(), 16);
      },
    );

    testWidgets('mes sin movimientos → estado vacío; "Todo el tiempo" los '
        'muestra', (tester) async {
      await sembrar(tester);
      final hoy = DateTime.now();
      await montar(
        tester,
        TodosLosMovimientosScreen(ahora: DateTime(hoy.year, hoy.month + 1, 10)),
        // Fase 86: alto suficiente para que la lista perezosa dibuje las 30.
        tamano: const Size(390, 7000),
      );

      expect(filas(), 0);
      expect(find.textContaining('No hay movimientos en'), findsOneWidget);

      await tester.tap(find.text('Ver todo el tiempo'));
      await tester.pumpAndSettle();
      // Fase 86: 16 del mes + 14 del historial de 3 meses de la demo.
      expect(filas(), 30);
      expect(find.text('Gasto total'), findsOneWidget);
    });

    testWidgets('cambiar de mes con el chip', (tester) async {
      await sembrar(tester);
      await montar(
        tester,
        const TodosLosMovimientosScreen(),
        tamano: const Size(390, 7000),
      );

      await tester.ensureVisible(find.byKey(const Key('chip_mes')));
      await tester.tap(find.byKey(const Key('chip_mes')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todo el tiempo'));
      await tester.pumpAndSettle();
      expect(find.text('Todo el tiempo'), findsOneWidget);
      // Fase 86: 16 del mes + 14 del historial de 3 meses de la demo.
      expect(filas(), 30);
    });

    for (final (nombre, tema) in [
      ('oscuro', appThemeOscuro()),
      ('claro', appThemeClaro()),
    ]) {
      testWidgets('textScale 1.3 a 360 dp sin overflow (tema $nombre)', (
        tester,
      ) async {
        await sembrar(tester);
        await montar(
          tester,
          const TodosLosMovimientosScreen(),
          escala: 1.3,
          tamano: const Size(360, 3200),
          tema: tema,
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.filter_list));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('objetivos táctiles ≥ 44 dp (filtros, chips, búsqueda)', (
      tester,
    ) async {
      await sembrar(tester);
      await montar(tester, const TodosLosMovimientosScreen());
      for (final f in [
        find.bySemanticsLabel(RegExp('^Filtros por cuenta')),
        find.byKey(const Key('chip_mes')),
        find.widgetWithText(ChoiceChip, 'Gastos'),
        find.byType(TextField),
      ]) {
        final size = tester.getSize(f);
        expect(size.height, greaterThanOrEqualTo(44));
        expect(size.width, greaterThanOrEqualTo(44));
      }
    });
  });
}

/// Nombre del mes actual tal como lo muestra el chip ("Noviembre").
String formatearMesActual() {
  const meses = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];
  return meses[DateTime.now().month - 1];
}

/// El Inicio solo se ve tras el onboarding; aquí basta con un nick local.
class PerfilLocalNick {
  static Future<void> guardar(SharedPreferences prefs) =>
      prefs.setString('modo_local.perfil.nick', 'jherson');
}
