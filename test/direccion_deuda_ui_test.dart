import 'dart:ui' show Tristate;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/deuda_detalle_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/deuda_formulario.dart';
import 'package:finanzas_automaticas/presentation/screens/deudas_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/pago_deuda_nuevo_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 82 (D/F) — Debo / Me deben en la UI, con los datos de ejemplo
/// (incluye "Lucía te debe S/ 380").
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

  Future<void> esperarDrift(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> montar(
    WidgetTester tester,
    Widget pantalla, {
    double escala = 1.0,
    Size tamano = const Size(390, 2400),
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
    await esperarDrift(tester);
  }

  group('Hub de Deudas: pestañas Debo / Me deben', () {
    testWidgets('Debo por defecto; "Me deben" muestra su total y "Lucía te '
        'debe", fuera del total de lo que debo', (tester) async {
      await sembrar(tester);
      await montar(tester, const DeudasScreen());

      expect(find.text('Total que debes'), findsOneWidget);
      // 880 + 1,890 + 150 + 1,200 de la Visa de ejemplo (Fase 84).
      expect(find.text('S/ 4,120.00'), findsOneWidget);
      expect(find.text('Debes a Luis (primo)'), findsOneWidget);
      expect(find.text('Lucía te debe'), findsNothing);

      await tester.tap(find.text('Me deben'));
      await tester.pumpAndSettle();

      expect(find.text('Total que te deben'), findsOneWidget);
      expect(find.text('S/ 380.00'), findsWidgets);
      expect(find.text('Lucía te debe'), findsOneWidget);
      expect(find.text('Por cobrar'), findsOneWidget);
      expect(find.text('1 préstamo por cobrar'), findsOneWidget);
      expect(find.text('Debes a Luis (primo)'), findsNothing);
    });

    testWidgets('las pestañas son botones accesibles con estado seleccionado '
        'y ≥ 44 dp', (tester) async {
      final semantics = tester.ensureSemantics();
      await sembrar(tester);
      await montar(tester, const DeudasScreen());

      SemanticsData datos(String etiqueta) => tester
          .getSemantics(find.bySemanticsLabel(etiqueta))
          .getSemanticsData();
      expect(datos('Debo').flagsCollection.isSelected, Tristate.isTrue);
      expect(datos('Me deben').flagsCollection.isSelected, Tristate.isFalse);
      expect(datos('Me deben').flagsCollection.isButton, isTrue);
      for (final e in ['Debo', 'Me deben']) {
        final size = tester.getSize(find.bySemanticsLabel(e));
        expect(size.height, greaterThanOrEqualTo(44));
      }

      await tester.tap(find.text('Me deben'));
      await tester.pumpAndSettle();
      expect(datos('Me deben').flagsCollection.isSelected, Tristate.isTrue);
      semantics.dispose();
    });

    testWidgets('estados vacíos por pestaña', (tester) async {
      await montar(tester, const DeudasScreen());

      expect(find.text('No tienes deudas activas'), findsOneWidget);
      expect(find.text('Agregar deuda'), findsOneWidget);

      await tester.tap(find.text('Me deben'));
      await tester.pumpAndSettle();
      expect(find.text('Nadie te debe'), findsOneWidget);

      await tester.tap(find.text('Registrar préstamo'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ruta /deudas/nueva ${DireccionDeuda.meDeben}'),
        findsOneWidget,
      );
    });

    for (final (nombre, tema) in [
      ('oscuro', appThemeOscuro()),
      ('claro', appThemeClaro()),
    ]) {
      testWidgets('texto al 130 % sin overflow en ambas pestañas ($nombre)', (
        tester,
      ) async {
        await sembrar(tester);
        await montar(
          tester,
          const DeudasScreen(),
          escala: 1.3,
          tamano: const Size(360, 3000),
          tema: tema,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Me deben'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Formulario: Yo debo / Me deben', () {
    Widget formulario({DireccionDeuda d = DireccionDeuda.debo}) => Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: DeudaFormulario(direccionInicial: d, onGuardadoExitoso: () {}),
      ),
    );

    testWidgets('"Me deben": "¿Quién te debe?" y sin tipo de deuda ni interés; '
        '"Yo debo" los muestra', (tester) async {
      await montar(tester, formulario(d: DireccionDeuda.meDeben));

      expect(find.text('¿Quién te debe?'), findsOneWidget);
      expect(find.text('¿Cómo te pagará?'), findsOneWidget);
      expect(find.text('Tipo de deuda'), findsNothing);
      expect(find.text('Tipo de acreedor'), findsNothing);
      expect(find.text('¿Tiene interés?'), findsNothing);
      expect(find.text('Pago mínimo (opcional)'), findsNothing);
      // Modo local: vincular amigo deshabilitado, con el aviso.
      expect(find.text('Disponible con la nube'), findsOneWidget);

      await tester.tap(find.text('Yo debo'));
      await tester.pumpAndSettle();
      expect(find.text('Tipo de deuda'), findsOneWidget);
      expect(find.text('Nombre del acreedor'), findsOneWidget);
      expect(find.text('¿Quién te debe?'), findsNothing);
    });

    testWidgets('guardar un "me deben" crea la deuda con esa dirección y '
        '"Préstamo a …" como nombre', (tester) async {
      await montar(tester, formulario(d: DireccionDeuda.meDeben));

      await tester.enterText(
        find.widgetWithText(TextFormField, '¿Quién te debe?'),
        'Lucía',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto prestado'),
        '250',
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Tú la verás como «Lucía te debe»'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await esperarDrift(tester);

      final deudas = await tester.runAsync(
        () => DeudaRepositoryDrift(db).obtenerTodas(),
      );
      expect(deudas, hasLength(1));
      final d = deudas!.single;
      expect(d.direccion, DireccionDeuda.meDeben);
      expect(d.nombreDeuda, 'Préstamo a Lucía');
      expect(d.tipoAcreedor, TipoAcreedor.personaNatural);
      expect(d.estructuraPago, EstructuraPago.pagoLibre);
    });

    testWidgets('texto al 130 % sin overflow en "Me deben" (claro)', (
      tester,
    ) async {
      await montar(
        tester,
        formulario(d: DireccionDeuda.meDeben),
        escala: 1.3,
        tamano: const Size(360, 2400),
        tema: appThemeClaro(),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('Costo anual en el detalle (E)', () {
    testWidgets('préstamo en cuotas: muestra el costo anual estimado; sin '
        'interés: 0.0 %', (tester) async {
      await sembrar(tester);
      await montar(
        tester,
        DeudaDetalleScreen(deudaId: SembrarDatosDemo.idDeudaPrestamo),
      );
      expect(find.text('Costo anual estimado'), findsOneWidget);
      // 3,800 en 10 × 440 mensuales ≈ 38-39 % efectivo anual.
      expect(find.textContaining(RegExp(r'^3[89]\.\d %$')), findsOneWidget);

      await montar(
        tester,
        DeudaDetalleScreen(deudaId: SembrarDatosDemo.idDeudaInformal),
      );
      expect(find.text('0.0 %'), findsOneWidget);
    });

    testWidgets('"Falta la tasa" con acceso a editar cuando no se puede '
        'calcular', (tester) async {
      await tester.runAsync(
        () => DeudaRepositoryDrift(db).crear(
          Deuda(
            id: 'sin-tasa',
            nombreDeuda: 'Préstamo sin tasa',
            tipoDeuda: TipoDeuda.prestamoPersonal,
            tipoAcreedor: TipoAcreedor.entidadFinanciera,
            nombreAcreedor: 'Caja',
            moneda: Moneda.pen,
            montoTotal: 1000,
            montoPagado: 0,
            tieneInteres: true,
            estructuraPago: EstructuraPago.pagoLibre,
            fechaInicio: DateTime(2026, 1, 1),
            enMora: false,
            estado: EstadoDeuda.activa,
          ),
        ),
      );
      await montar(tester, const DeudaDetalleScreen(deudaId: 'sin-tasa'));

      expect(find.text('Falta la tasa'), findsOneWidget);
      await tester.tap(find.text('Agregar tasa'));
      await tester.pumpAndSettle();
      expect(find.text('Ruta /deudas/nueva sin-tasa'), findsOneWidget);
    });

    testWidgets('un "me deben" no muestra costo', (tester) async {
      await sembrar(tester);
      await montar(
        tester,
        DeudaDetalleScreen(deudaId: SembrarDatosDemo.idDeudaLucia),
      );
      expect(find.text('Costo anual estimado'), findsNothing);
      expect(find.text('Falta la tasa'), findsNothing);
    });
  });

  group('Cobro', () {
    testWidgets('detalle y pantalla de pago de un "me deben" hablan de cobro', (
      tester,
    ) async {
      await sembrar(tester);
      await montar(
        tester,
        DeudaDetalleScreen(deudaId: SembrarDatosDemo.idDeudaLucia),
      );
      expect(find.text('Registrar cobro'), findsOneWidget);
      expect(find.text('Registrar pago'), findsNothing);
      expect(find.textContaining('Cobrado S/ 0.00'), findsOneWidget);

      await montar(
        tester,
        PagoDeudaNuevoScreen(deudaId: SembrarDatosDemo.idDeudaLucia),
      );
      expect(find.text('Registrar cobro'), findsOneWidget);
      expect(find.text('Cobrar a Lucía'), findsOneWidget);
      expect(find.text('Monto cobrado'), findsOneWidget);
      expect(find.text('Recibir en'), findsOneWidget);

      // Fase 83: "Recibir en" no ofrece tarjetas de crédito.
      await tester.runAsync(
        () => CuentaRepositoryDrift(db).crear(
          const Cuenta(
            id: 'visa',
            nombre: 'Visa Oro',
            tipo: TipoCuenta.credito,
            moneda: Moneda.pen,
            saldoActual: 0,
            lineaCredito: 3000,
          ),
        ),
      );
      await montar(
        tester,
        PagoDeudaNuevoScreen(deudaId: SembrarDatosDemo.idDeudaLucia),
      );
      await tester.tap(find.text('Recibir en'));
      await tester.pumpAndSettle();
      expect(find.text('Yape (S/)'), findsWidgets);
      expect(find.text('Visa Oro (S/)'), findsNothing);
    });

    testWidgets('una deuda "debo" de pago libre ahora tiene "Registrar pago" '
        'visible en el detalle (antes solo en el Inicio)', (tester) async {
      await sembrar(tester);
      await montar(
        tester,
        DeudaDetalleScreen(deudaId: SembrarDatosDemo.idDeudaInformal),
      );
      expect(find.text('Registrar pago'), findsOneWidget);
      await tester.tap(find.text('Registrar pago'));
      await tester.pumpAndSettle();
      expect(
        find.text('Ruta /deudas/pago ${SembrarDatosDemo.idDeudaInformal}'),
        findsOneWidget,
      );
    });
  });
}
