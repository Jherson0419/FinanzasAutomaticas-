import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/avance.dart';
import 'package:finanzas_automaticas/domain/hitos.dart';
import 'package:finanzas_automaticas/domain/recordatorios.dart';
import 'package:finanzas_automaticas/domain/repositories/notificaciones_locales_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_recordatorios_repository_shared_prefs.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/deudas_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/mi_avance_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/plan_pago_screen.dart';
import 'package:finanzas_automaticas/presentation/shared/formatters.dart';
import 'package:finanzas_automaticas/presentation/shared/notificaciones_recordatorios.dart';
import 'package:finanzas_automaticas/presentation/state/avance_providers.dart';
import 'package:finanzas_automaticas/presentation/state/consejero_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

class _FakeNotificaciones implements NotificacionesLocalesRepository {
  EstadoPermisoNotificaciones permiso =
      EstadoPermisoNotificaciones.sinPreguntar;
  bool concedeAlPedir = true;
  final programadas = <int, Recordatorio>{};
  int pedidos = 0;
  int ajustesAbiertos = 0;

  @override
  Future<EstadoPermisoNotificaciones> estadoPermiso() async => permiso;
  @override
  Future<bool> pedirPermiso() async {
    pedidos++;
    permiso = concedeAlPedir
        ? EstadoPermisoNotificaciones.concedido
        : EstadoPermisoNotificaciones.denegado;
    return concedeAlPedir;
  }

  @override
  Future<List<int>> pendientes() async => programadas.keys.toList();
  @override
  Future<void> programar(Recordatorio r) async => programadas[r.id] = r;
  @override
  Future<void> cancelar(int id) async => programadas.remove(id);
  @override
  Future<void> abrirAjustes() async => ajustesAbiertos++;
}

/// Fase 87 (F) — "Mi avance", hitos, notificaciones y permiso, con los
/// datos de ejemplo sembrados el 17 nov 2026.
void main() {
  final ahora = DateTime(2026, 11, 17, 10);
  late SharedPreferences prefs;
  late AppDatabase db;
  late _FakeNotificaciones fake;
  late ProviderContainer contenedor;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fake = _FakeNotificaciones();
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
          ahoraAvanceProvider.overrideWithValue(ahora),
          ahoraConsejeroProvider.overrideWithValue(ahora),
          notificacionesLocalesRepositoryProvider.overrideWithValue(fake),
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
          onGenerateRoute: (s) => MaterialPageRoute(
            builder: (_) => s.name == '/avance'
                ? const MiAvanceScreen()
                : Scaffold(body: Text('Ruta ${s.name}')),
          ),
        ),
      ),
    );
    contenedor = ProviderScope.containerOf(tester.element(find.byWidget(home)));
    await asentar(tester);
  }

  group('Mi avance', () {
    testWidgets('sin datos: lo dice, y todos los hitos "Por lograr"', (
      tester,
    ) async {
      await montar(tester, const MiAvanceScreen());
      expect(find.textContaining('Cuando registres una deuda'), findsOneWidget);
      expect(
        find.textContaining('Por lograr'),
        findsNWidgets(Hito.values.length),
      );
      expect(find.textContaining('Logrado el'), findsNothing);
      expect(find.textContaining('Logro:'), findsNothing);
    });

    testWidgets('con datos: pagado, %, racha, hitos guardados y una sola '
        'celebración a la vez', (tester) async {
      await sembrar(tester);
      await montar(tester, const MiAvanceScreen());
      final a = contenedor.read(avanceProvider).requireValue;
      expect(
        find.text('${formatearMonto(a.pagado.total, a.moneda)} en deudas'),
        findsOneWidget,
      );
      expect(
        find.text('Llevas el ${a.porcentaje} % de tus deudas'),
        findsOneWidget,
      );
      expect(find.text(notaPorcentajeAvance), findsOneWidget);
      expect(find.text('Pagos a tiempo'), findsOneWidget);
      expect(find.text('Uso de tarjetas'), findsOneWidget);

      // Hitos logrados se guardan (con ícono y texto, no solo color).
      final hitos = contenedor.read(hitosProvider);
      expect(hitos, contains(Hito.primerPago));
      expect(find.textContaining('Logrado el'), findsNWidgets(hitos.length));
      expect(find.byIcon(Icons.check_circle), findsNWidgets(hitos.length));
      expect(prefs.getString('avance.hitos'), isNotNull);

      // Una celebración a la vez; "Entendido" pasa a la siguiente.
      expect(find.text('Entendido'), findsOneWidget);
      final primera = siguienteACelebrar(hitos)!;
      expect(find.text('Logro: ${tituloHito(primera.hito)}'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await asentar(tester);
      expect(find.text('Logro: ${tituloHito(primera.hito)}'), findsNothing);
      expect(contenedor.read(hitosProvider)[primera.hito]!.celebrado, isTrue);
      expect(find.text('Entendido'), findsAtLeast(0));
      expect(find.text('Entendido').evaluate().length, lessThanOrEqualTo(1));
    });
  });

  group('Notificaciones', () {
    Widget seccion() => const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: SeccionNotificaciones(),
      ),
    );

    testWidgets('todo apagado de inicio; no pide permiso al abrir', (
      tester,
    ) async {
      await montar(tester, seccion());
      final switches = tester
          .widgetList<SwitchListTile>(find.byType(SwitchListTile))
          .toList();
      expect(switches, hasLength(4));
      expect(switches.every((s) => !s.value), isTrue);
      expect(fake.pedidos, 0);
    });

    testWidgets('activar: explicación → permiso → programa', (tester) async {
      await sembrar(tester);
      await montar(tester, seccion());
      await tester.tap(find.text('Vencimientos de cuotas y tarjetas'));
      await tester.pumpAndSettle();
      expect(find.text(explicacionPermisoRecordatorios), findsOneWidget);
      expect(fake.pedidos, 0, reason: 'antes, la explicación');
      await tester.tap(find.text('Continuar'));
      await asentar(tester);
      expect(fake.pedidos, 1);
      expect(
        PreferenciasRecordatoriosRepositorySharedPrefs(
          prefs,
        ).leer().vencimientos,
        isTrue,
      );
      expect(fake.programadas, isNotEmpty);
      // Montos ocultos por defecto.
      expect(
        fake.programadas.values.any((r) => r.cuerpo.contains('S/')),
        isFalse,
      );
    });

    testWidgets('"Ahora no": no pide permiso y queda apagado', (tester) async {
      await montar(tester, seccion());
      await tester.tap(find.text('Cobros'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ahora no'));
      await asentar(tester);
      expect(fake.pedidos, 0);
      expect(
        tester
            .widgetList<SwitchListTile>(find.byType(SwitchListTile))
            .every((s) => !s.value),
        isTrue,
      );
    });

    testWidgets('permiso negado: lo dice y lleva a Ajustes', (tester) async {
      fake.concedeAlPedir = false;
      await montar(tester, seccion());
      await tester.tap(find.text('Revisión semanal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await asentar(tester);
      expect(find.text(textoPermisoDenegado), findsOneWidget);
      expect(
        PreferenciasRecordatoriosRepositorySharedPrefs(
          prefs,
        ).leer().revisionSemanal,
        isFalse,
      );
      await tester.tap(find.text('Abrir Ajustes'));
      await tester.pump();
      expect(fake.ajustesAbiertos, 1);
    });

    testWidgets('revisión semanal: día y hora visibles al activarla', (
      tester,
    ) async {
      fake.permiso = EstadoPermisoNotificaciones.concedido;
      await montar(tester, seccion());
      expect(find.text('Domingo a las 7:00 PM'), findsOneWidget);
      await tester.tap(find.text('Revisión semanal'));
      await asentar(tester);
      expect(find.text('Día'), findsOneWidget);
      expect(find.textContaining('Hora:'), findsOneWidget);
      expect(fake.programadas, hasLength(revisionesSemanalesProgramadas));
    });
  });

  group('Oferta tras la primera deuda', () {
    Widget oferta() => const Scaffold(body: OfrecimientoRecordatorios());

    testWidgets('se ofrece una vez; "No, gracias" no vuelve a preguntar', (
      tester,
    ) async {
      await sembrar(tester);
      await montar(tester, oferta());
      expect(find.text(preguntaOfrecimiento), findsOneWidget);
      await tester.tap(find.text('No, gracias'));
      await asentar(tester);
      expect(find.text(preguntaOfrecimiento), findsNothing);
      expect(
        PreferenciasRecordatoriosRepositorySharedPrefs(
          prefs,
        ).leer().ofrecimientoHecho,
        isTrue,
      );
      await montar(tester, const Scaffold(body: OfrecimientoRecordatorios()));
      expect(find.text(preguntaOfrecimiento), findsNothing);
      expect(fake.pedidos, 0);
    });

    testWidgets('"Sí, avisarme" activa los vencimientos', (tester) async {
      await sembrar(tester);
      await montar(tester, oferta());
      await tester.tap(find.text('Sí, avisarme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await asentar(tester);
      final c = PreferenciasRecordatoriosRepositorySharedPrefs(prefs).leer();
      expect(c.vencimientos, isTrue);
      expect(c.ofrecimientoHecho, isTrue);
      expect(fake.programadas, isNotEmpty);
    });

    testWidgets('sin deudas no se ofrece', (tester) async {
      await montar(tester, oferta());
      expect(find.text(preguntaOfrecimiento), findsNothing);
    });
  });

  group('Entradas', () {
    testWidgets('hub de Deudas → "Mi avance"', (tester) async {
      await sembrar(tester);
      await montar(tester, const DeudasScreen());
      await tester.tap(find.text('Mi avance'));
      await asentar(tester);
      expect(find.byType(MiAvanceScreen), findsOneWidget);
    });

    testWidgets('plan → "Mi avance"', (tester) async {
      await sembrar(tester);
      await montar(tester, PlanPagoScreen(ahora: ahora));
      await tester.tap(find.byTooltip('Mi avance'));
      await asentar(tester);
      expect(find.byType(MiAvanceScreen), findsOneWidget);
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
      await montar(
        tester,
        const MiAvanceScreen(),
        ancho: 360,
        escala: 1.3,
        tema: tema,
      );
      expect(tester.takeException(), isNull);
      await montar(
        tester,
        const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [OfrecimientoRecordatorios(), SeccionNotificaciones()],
            ),
          ),
        ),
        ancho: 360,
        escala: 1.3,
        tema: tema,
      );
      expect(tester.takeException(), isNull);
      for (final b in find.byType(TextButton).evaluate()) {
        expect(
          tester.getSize(find.byWidget(b.widget)).height,
          greaterThanOrEqualTo(44),
        );
      }
    });
  }

  test('avance demo coherente con el dominio', () {
    expect(diasToleranciaATiempo, 3);
  });
}
