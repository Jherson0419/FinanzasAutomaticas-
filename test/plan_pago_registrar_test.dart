import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/pago_deuda_nuevo_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/plan_pago_screen.dart';
import 'package:finanzas_automaticas/presentation/state/plan_pago_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Fase 84 (E) — "Registrar pago" desde el plan con los datos de ejemplo
/// (préstamo y laptop en cuotas, préstamo informal en pago libre, Visa).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;
  final ahora = DateTime(2026, 11, 17);

  setUp(() async {
    // Avalancha con S/ 100 extra: la laptop (≈ 55 % TEA) va primera.
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

  Future<void> montar(WidgetTester tester) async {
    await tester.runAsync(
      () => SembrarDatosDemo(
        cuentaRepository: CuentaRepositoryDrift(db),
        categoriaRepository: CategoriaRepositoryDrift(db),
        transaccionRepository: TransaccionRepositoryDrift(db),
        deudaRepository: DeudaRepositoryDrift(db),
        pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
      ).call(),
    );
    tester.view.physicalSize = const Size(390, 3200);
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
          home: PlanPagoScreen(ahora: ahora),
          onGenerateRoute: (s) {
            final args = s.arguments;
            if (s.name == '/deudas/pago' && args is PagoDeudaRouteArgs) {
              return MaterialPageRoute(
                builder: (_) => PagoDeudaNuevoScreen(
                  deudaId: args.deudaId,
                  montoEsperadoInicial: args.montoEsperadoInicial,
                  modoInicial: args.modoInicial,
                ),
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

  double capitalDelPlan(WidgetTester tester) {
    final contenedor = ProviderScope.containerOf(
      tester.element(find.byType(PlanPagoScreen)),
    );
    final comparacion = contenedor
        .read(comparacionesPlanProvider)
        .requireValue[Moneda.pen]!;
    return comparacion.plan(EstrategiaPago.avalancha).capitalTotal;
  }

  testWidgets('cada fila que no es tarjeta tiene "Registrar pago"; la Visa '
      'explica que se actualiza sola', (tester) async {
    await montar(tester);
    // Préstamo, laptop e informal: 3 botones. La Visa ninguno.
    expect(find.text('Registrar pago'), findsNWidgets(3));
    expect(find.text(notaTarjetaSinPago), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Registrar pago de Visa')),
      findsNothing,
    );
  });

  testWidgets('desde la primera fila: abre "Abono a capital" con el extra '
      'sugerido; al volver el plan se recalcula', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);
    final antes = capitalDelPlan(tester);

    await tester.tap(find.text('Registrar pago').first);
    await asentar(tester);

    final abono = tester.getSemantics(find.bySemanticsLabel('Abono a capital'));
    expect(abono.flagsCollection.isSelected, Tristate.isTrue);
    final campo = find.widgetWithText(TextFormField, 'Monto del abono');
    expect(
      tester.widget<TextFormField>(campo).controller!.text,
      '100.00',
      reason: 'el extra del plan, como sugerencia editable',
    );
    expect(find.textContaining('Laptop'), findsWidgets);

    // Editable: se cambia a 1000 y se registra (retroactivo).
    await tester.enterText(campo, '1000');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await asentar(tester);

    expect(find.byType(PlanPagoScreen), findsOneWidget);
    final despues = capitalDelPlan(tester);
    expect(despues, lessThan(antes - 500));
    semantica.dispose();
  });

  testWidgets('pago libre: abre el pago normal con mínimo + extra si es la '
      'primera, sin monto si no', (tester) async {
    await montar(tester);
    // El préstamo informal no tiene pago mínimo ni va primero: abre el pago
    // normal sin selector de abono.
    final botones = find.text('Registrar pago');
    await tester.tap(botones.last);
    await asentar(tester);
    expect(find.byType(PagoDeudaNuevoScreen), findsOneWidget);
    expect(find.text('Monto pagado'), findsOneWidget);
    expect(find.text('Abono a capital'), findsNothing);
  });
}
