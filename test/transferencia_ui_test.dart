import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_transferencia.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/movimientos_cuenta_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/plan_pago_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/todos_los_movimientos_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/transferencia_screen.dart';
import 'package:finanzas_automaticas/presentation/shared/formatters.dart';
import 'package:finanzas_automaticas/presentation/state/plan_pago_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 85 (D/E) — transferencias y "Pagar tarjeta" en la UI, con los
/// datos de ejemplo (Efectivo, Débito BCP, Yape y la Visa BCP).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    // Avalancha con S/ 100 extra: la laptop va primera, la Visa no.
    SharedPreferences.setMockInitialValues({
      'plan_pago.extra_mensual': 100.0,
      'plan_pago.estrategia': EstrategiaPago.avalancha.name,
    });
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
    ).call(),
  );

  Future<Cuenta> cuenta(WidgetTester tester, String nombre) async =>
      (await tester.runAsync(() => CuentaRepositoryDrift(db).obtenerTodas()))!
          .firstWhere((c) => c.nombre == nombre);

  Future<void> montar(
    WidgetTester tester,
    Widget home, {
    double ancho = 390,
    double escala = 1,
    ThemeData? tema,
  }) async {
    tester.view.physicalSize = Size(ancho, 3200);
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
          theme: tema ?? appThemeClaro(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: home,
          onGenerateRoute: (s) {
            final args = s.arguments;
            if (s.name == '/transferencias/nueva') {
              final t = args is TransferenciaRouteArgs
                  ? args
                  : const TransferenciaRouteArgs();
              return MaterialPageRoute(
                builder: (_) => TransferenciaScreen(
                  origenId: t.origenId,
                  destinoId: t.destinoId,
                  montoSugerido: t.montoSugerido,
                ),
              );
            }
            if (s.name == '/transferencias/detalle') {
              return MaterialPageRoute(
                builder: (_) =>
                    TransferenciaDetalleScreen(transferenciaId: args as String),
              );
            }
            return MaterialPageRoute(
              builder: (_) => Scaffold(body: Text('Ruta ${s.name}')),
            );
          },
        ),
      ),
    );
    await asentar(tester);
  }

  Future<void> elegirCuenta(
    WidgetTester tester,
    String campo,
    String nombre,
  ) async {
    await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, campo));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('$nombre · ').last);
    await tester.pumpAndSettle();
  }

  Future<void> transferirDirecto(
    WidgetTester tester,
    String origen,
    String destino,
    double monto,
  ) async {
    final o = await cuenta(tester, origen);
    final d = await cuenta(tester, destino);
    await tester.runAsync(
      () => RegistrarTransferencia(
        cuentaRepository: CuentaRepositoryDrift(db),
        transaccionRepository: TransaccionRepositoryDrift(db),
        deudaRepository: DeudaRepositoryDrift(db),
      )(origenId: o.id, destinoId: d.id, monto: monto),
    );
  }

  testWidgets('transferencia entre cuentas: selectores accesibles, mueve los '
      'saldos y vuelve', (tester) async {
    await sembrar(tester);
    final debitoAntes = (await cuenta(tester, 'Débito BCP')).saldoActual;
    final yapeAntes = (await cuenta(tester, 'Yape')).saldoActual;
    await montar(tester, const TransferenciaScreen());

    expect(find.text('Transferencia'), findsOneWidget, reason: 'título');
    expect(find.text('Desde'), findsOneWidget);
    expect(find.text('Hacia'), findsOneWidget);
    expect(
      find.text(
        'Una transferencia entre tus cuentas no cuenta como ingreso ni como '
        'gasto.',
      ),
      findsOneWidget,
    );
    await elegirCuenta(tester, 'Desde', 'Débito BCP');
    await elegirCuenta(tester, 'Hacia', 'Yape');
    // Sin chips de tarjeta: el destino no es de crédito.
    expect(find.text('Otro monto'), findsNothing);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Monto'),
      '100',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nota (opcional)'),
      'Para el almuerzo',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferir'));
    await asentar(tester);

    expect(
      (await cuenta(tester, 'Débito BCP')).saldoActual,
      debitoAntes - 100,
    );
    expect((await cuenta(tester, 'Yape')).saldoActual, yapeAntes + 100);
    final caras = (await tester.runAsync(
      () => TransaccionRepositoryDrift(db).obtenerTodas(),
    ))!.where((t) => t.esTransferencia);
    expect(caras, hasLength(2));
    expect(caras.every((t) => t.concepto == 'Para el almuerzo'), isTrue);
    expect(find.byType(TransferenciaScreen), findsNothing, reason: 'volvió');
  });

  testWidgets('"Pagar tarjeta" desde el plan: destino elegido, chips de '
      'monto, mínimo sugerido; al volver el plan se recalcula', (
    tester,
  ) async {
    await sembrar(tester);
    final visa = await cuenta(tester, 'Visa BCP');
    final usado = -visa.saldoActual;
    await montar(tester, PlanPagoScreen(ahora: DateTime(2026, 11, 17)));
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PlanPagoScreen)),
    );
    double capital() => contenedor
        .read(comparacionesPlanProvider)
        .requireValue[Moneda.pen]!
        .plan(EstrategiaPago.avalancha)
        .capitalTotal;
    final capitalAntes = capital();

    // La ayuda se mantiene junto al botón.
    expect(find.text(notaTarjetaSinPago), findsOneWidget);
    await tester.ensureVisible(find.text('Pagar tarjeta'));
    await tester.tap(find.text('Pagar tarjeta'));
    await asentar(tester);

    expect(find.byType(TransferenciaScreen), findsOneWidget);
    expect(find.widgetWithText(AppBar, 'Pagar tarjeta'), findsOneWidget);
    // La Visa no va primera: se sugiere solo el mínimo.
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Monto'))
          .controller!
          .text,
      '120.00',
    );
    expect(find.text('Pago mínimo S/ 120.00'), findsOneWidget);
    expect(
      find.text('Deuda total ${formatearMonto(usado, Moneda.pen)}'),
      findsOneWidget,
    );
    expect(find.text('Otro monto'), findsOneWidget);
    for (final chip in find.byType(ChoiceChip).evaluate()) {
      expect(tester.getSize(find.byWidget(chip.widget)).height,
          greaterThanOrEqualTo(44));
    }

    // "Otro monto" limpia el campo; "Deuda total" lo llena.
    await tester.tap(find.text('Otro monto'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Monto'))
          .controller!
          .text,
      '',
    );
    await tester.tap(find.textContaining('Deuda total'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Transferir'));
    await tester.tap(find.text('Transferir'));
    await asentar(tester);

    expect(find.byType(PlanPagoScreen), findsOneWidget);
    final deudaVisa = (await tester.runAsync(
      () => DeudaRepositoryDrift(db).obtenerTodas(),
    ))!.firstWhere((d) => d.cuentaId == visa.id);
    expect(saldoPendiente(deudaVisa), closeTo(0, 1e-9));
    expect(capital(), closeTo(capitalAntes - usado, 1e-6));
  });

  testWidgets('Movimientos: una fila neutra "Transferencia a Visa BCP", '
      'filtro "Transferencias", detalle y borrado', (tester) async {
    await sembrar(tester);
    await transferirDirecto(tester, 'Débito BCP', 'Visa BCP', 300);
    final debito = (await cuenta(tester, 'Débito BCP')).saldoActual;
    final semantica = tester.ensureSemantics();
    await montar(tester, TodosLosMovimientosScreen(ahora: DateTime.now()));

    expect(find.text('Transferencia a Visa BCP'), findsOneWidget);
    expect(find.text('Transferencia desde Débito BCP'), findsNothing);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    // Sin signo en "todas las cuentas": no cambia el total.
    expect(find.text('S/ 300.00'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Transferencia: Transferencia a Visa')),
      findsOneWidget,
    );

    await tester.tap(find.text('Transferencias'));
    await tester.pumpAndSettle();
    expect(find.text('Transferencia a Visa BCP'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    semantica.dispose();

    await tester.tap(find.text('Transferencia a Visa BCP'));
    await asentar(tester);
    expect(find.byType(TransferenciaDetalleScreen), findsOneWidget);
    expect(find.text('Débito BCP'), findsOneWidget);
    expect(find.text('Visa BCP'), findsOneWidget);
    await tester.tap(find.text('Eliminar transferencia'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Eliminar'));
    await asentar(tester);
    expect(find.byType(TransferenciaDetalleScreen), findsNothing);
    expect((await cuenta(tester, 'Débito BCP')).saldoActual, debito + 300);
    expect(find.text('Transferencia a Visa BCP'), findsNothing);
  });

  testWidgets('historial de la tarjeta: "Transferencia desde Débito BCP" '
      'con "+", tono neutro', (tester) async {
    await sembrar(tester);
    await transferirDirecto(tester, 'Débito BCP', 'Visa BCP', 300);
    final visa = await cuenta(tester, 'Visa BCP');
    await montar(tester, MovimientosCuentaScreen(cuentaId: visa.id));
    expect(find.text('Transferencia desde Débito BCP'), findsOneWidget);
    expect(find.text('+S/ 300.00'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });

  for (final (nombre, tema) in [
    ('claro', appThemeClaro()),
    ('oscuro', appThemeOscuro()),
  ]) {
    testWidgets('360 dp con texto al 130 %: pagar tarjeta, detalle y lista '
        'sin desbordes ($nombre)', (tester) async {
      await sembrar(tester);
      final visa = await cuenta(tester, 'Visa BCP');
      await montar(
        tester,
        TransferenciaScreen(destinoId: visa.id, montoSugerido: 120),
        ancho: 360,
        escala: 1.3,
        tema: tema,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Otro monto'), findsOneWidget);

      await transferirDirecto(tester, 'Débito BCP', 'Visa BCP', 300);
      await montar(
        tester,
        TodosLosMovimientosScreen(ahora: DateTime.now()),
        ancho: 360,
        escala: 1.3,
        tema: tema,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Transferencia a Visa BCP'));
      await asentar(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Eliminar transferencia'), findsOneWidget);
    });
  }
}
