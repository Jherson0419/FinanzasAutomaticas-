import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/screens/deudas_screen.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 80 — hub de deudas (destino "Deudas" de la barra).
DeudaActivaResumen _resumen({
  String id = 'd',
  bool enMora = false,
  int? diasMora,
  DateTime? fecha,
}) => DeudaActivaResumen(
  id: id,
  nombreDeuda: id,
  estructuraPago: EstructuraPago.cuotasFijas,
  proximaFechaPago: fecha,
  enMora: enMora,
  diasMora: diasMora,
  montoPagado: 0,
  montoTotal: 100,
  montoCuota: 10,
  moneda: Moneda.pen,
  fechaVencimientoReal: fecha,
);

void main() {
  group('etiquetaUrgencia (ícono + texto, nunca solo color)', () {
    final ahora = DateTime(2026, 11, 16, 15, 30);

    test('vence mañana / hoy / en N días / al día', () {
      expect(
        etiquetaUrgencia(_resumen(fecha: DateTime(2026, 11, 17)), ahora).texto,
        'Vence mañana',
      );
      expect(
        etiquetaUrgencia(_resumen(fecha: DateTime(2026, 11, 16)), ahora).texto,
        'Vence hoy',
      );
      final en5 = etiquetaUrgencia(
        _resumen(fecha: DateTime(2026, 11, 21)),
        ahora,
      );
      expect(en5.texto, 'En 5 días');
      expect(en5.tono, TonoUrgencia.neutro);
      expect(
        etiquetaUrgencia(_resumen(fecha: DateTime(2026, 12, 20)), ahora).texto,
        'Al día · 20 dic',
      );
      expect(etiquetaUrgencia(_resumen(), ahora).texto, 'Al día');
    });

    test('por vencer (≤ 3 días) usa tono de aviso; en mora, de peligro', () {
      final manana = etiquetaUrgencia(
        _resumen(fecha: DateTime(2026, 11, 17)),
        ahora,
      );
      expect(manana.tono, TonoUrgencia.aviso);
      expect(manana.icono, Icons.schedule);

      final mora = etiquetaUrgencia(
        _resumen(enMora: true, diasMora: 4, fecha: DateTime(2026, 11, 12)),
        ahora,
      );
      expect(mora.texto, 'Vencida hace 4 días');
      expect(mora.tono, TonoUrgencia.peligro);
      expect(mora.icono, Icons.error_outline);
    });
  });

  group('DeudasScreen con los datos de ejemplo (modo local)', () {
    late SharedPreferences prefs;
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() => db.close());

    Future<void> sembrar(WidgetTester tester) async {
      await tester.runAsync(() async {
        await SembrarDatosDemo(
          cuentaRepository: CuentaRepositoryDrift(db),
          categoriaRepository: CategoriaRepositoryDrift(db),
          transaccionRepository: TransaccionRepositoryDrift(db),
          deudaRepository: DeudaRepositoryDrift(db),
          pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
        ).call();
        // Una deuda extra con la primera cuota vencida hace 10 días y sin
        // pagos: `ActualizarEstadoMora` la marca en mora al cargar.
        final hoy = DateTime.now();
        await DeudaRepositoryDrift(db).crear(
          Deuda(
            id: 'atrasada',
            nombreDeuda: 'Celular en cuotas',
            tipoDeuda: TipoDeuda.compraCuotas,
            tipoAcreedor: TipoAcreedor.comercio,
            nombreAcreedor: 'Tienda',
            moneda: Moneda.pen,
            montoTotal: 600,
            montoPagado: 0,
            tieneInteres: false,
            estructuraPago: EstructuraPago.cuotasFijas,
            numeroCuotasTotal: 6,
            numeroCuotasPagadas: 0,
            montoCuota: 100,
            periodicidadCuotas: PeriodicidadCuota.mensual,
            fechaInicio: DateTime(hoy.year, hoy.month, hoy.day - 10),
            proximaFechaPago: DateTime(hoy.year, hoy.month, hoy.day - 10),
            enMora: false,
            estado: EstadoDeuda.activa,
          ),
        );
      });
    }

    Future<void> montar(
      WidgetTester tester, {
      double escala = 1.0,
      Size tamano = const Size(390, 1600),
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
            home: const DeudasScreen(),
          ),
        ),
      );
      // Drift corre en un isolate/zona real: dejar que resuelva.
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets(
      'muestra el saldo pendiente correcto (880 / 1,890 / 150), ordena por '
      'urgencia y el total que debes',
      (tester) async {
        await sembrar(tester);
        await montar(tester);

        expect(find.text('Total que debes'), findsOneWidget);
        // 880 + 1,890 + 150 + 600 (la atrasada) + 1,200 de la Visa de ejemplo
        // (Fase 84) = 4,720.
        expect(find.text('S/ 4,720.00'), findsOneWidget);

        for (final saldo in ['S/ 880.00', 'S/ 1,890.00', 'S/ 150.00']) {
          expect(find.text(saldo), findsOneWidget, reason: saldo);
        }
        expect(find.text('Cuota S/ 440.00 · 8 de 10 pagadas'), findsOneWidget);
        expect(find.text('Cuota S/ 210.00 · 3 de 12 pagadas'), findsOneWidget);
        // Préstamo de Luis y la Visa de ejemplo (Fase 84) son de pago libre.
        expect(find.text('Pago libre'), findsNWidgets(2));

        // La deuda en mora va primero, con chip de ícono + texto.
        final yAtrasada = tester.getTopLeft(find.text('Celular en cuotas')).dy;
        for (final nombre in [
          'Préstamo personal',
          'Laptop Lenovo',
          'Debes a Luis (primo)',
        ]) {
          expect(
            yAtrasada,
            lessThan(tester.getTopLeft(find.text(nombre)).dy),
            reason: '"Celular en cuotas" (en mora) debe ir antes que $nombre',
          );
        }
        expect(find.textContaining('Vencida hace'), findsOneWidget);
        final chipMora = find.ancestor(
          of: find.textContaining('Vencida hace'),
          matching: find.byType(ChipUrgencia),
        );
        expect(
          find.descendant(
            of: chipMora,
            matching: find.byIcon(Icons.error_outline),
          ),
          findsOneWidget,
        );
        expect(find.text('1 vencida'), findsOneWidget);
        // Modo local: sin "Registradas por tus amigos".
        expect(find.text('REGISTRADAS POR TUS AMIGOS'), findsNothing);
      },
    );

    testWidgets('tocar una deuda abre su detalle', (tester) async {
      await sembrar(tester);
      tester.view.physicalSize = const Size(390, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? abierta;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overridesModoLocal(prefs),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: const DeudasScreen(),
            onGenerateRoute: (settings) {
              if (settings.name == '/deudas/detalle') {
                abierta = settings.arguments as String;
                return MaterialPageRoute(
                  builder: (_) => const Scaffold(body: Text('Detalle')),
                );
              }
              return null;
            },
          ),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('Laptop Lenovo'));
      await tester.pumpAndSettle();
      expect(abierta, SembrarDatosDemo.idDeudaLaptop);
      expect(find.text('Detalle'), findsOneWidget);
    });

    for (final (nombreTema, tema) in [
      ('oscuro', appThemeOscuro()),
      ('claro', appThemeClaro()),
    ]) {
      testWidgets('textScale 1.3 a 360 dp sin overflow (tema $nombreTema)', (
        tester,
      ) async {
        await sembrar(tester);
        await montar(
          tester,
          escala: 1.3,
          tamano: const Size(360, 2400),
          tema: tema,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('S/ 880.00'), findsOneWidget);
      });
    }

    testWidgets('estado vacío con botón "Agregar deuda"', (tester) async {
      await montar(tester);
      expect(find.text('No tienes deudas activas'), findsOneWidget);
      expect(find.text('Agregar deuda'), findsOneWidget);
      expect(find.text('Total que debes'), findsNothing);
    });
  });

  group('"Te deben"', () {
    Widget app({required bool modoLocal}) => ProviderScope(
      overrides: [
        modoLocalProvider.overrideWithValue(modoLocal),
        resumenDashboardProvider.overrideWith(
          (ref) async => const ResumenDashboard(
            saldosPorCuenta: [],
            saldoTotalPorMoneda: {},
            ingresosMesPorMoneda: {},
            gastosMesPorMoneda: {},
            gastoPorCategoriaMes: [],
            deudasActivas: [],
            totalAdeudadoPorMoneda: {},
            movimientosRecientes: [],
          ),
        ),
        deudasProvider.overrideWith((ref) async => const []),
        amigosProvider.overrideWith((ref) async => const []),
        deudasQueMeDebenProvider.overrideWith(
          (ref) async => const [
            DeudaDeAmigo(
              id: 'x',
              deudorUsuarioId: 'u1',
              nombreDeuda: 'Almuerzo',
              montoAdeudado: 45,
              moneda: Moneda.pen,
            ),
          ],
        ),
      ],
      child: const MaterialApp(home: DeudasScreen()),
    );

    testWidgets('con la nube aparece debajo, de solo lectura', (tester) async {
      await tester.pumpWidget(app(modoLocal: false));
      await tester.pumpAndSettle();
      // Fase 82: el dueño la registró como "debo" → a mí me la deben, así
      // que aparece en la pestaña "Me deben" bajo "Registradas por tus
      // amigos" (fuera de los totales).
      expect(find.text('REGISTRADAS POR TUS AMIGOS'), findsNothing);
      await tester.tap(find.text('Me deben'));
      await tester.pumpAndSettle();
      expect(find.text('REGISTRADAS POR TUS AMIGOS'), findsOneWidget);
      expect(find.text('Alguien te debe S/ 45.00'), findsOneWidget);
    });

    testWidgets('en modo local no aparece', (tester) async {
      await tester.pumpWidget(app(modoLocal: true));
      await tester.pumpAndSettle();
      expect(find.text('REGISTRADAS POR TUS AMIGOS'), findsNothing);
      await tester.tap(find.text('Me deben'));
      await tester.pumpAndSettle();
      expect(find.text('REGISTRADAS POR TUS AMIGOS'), findsNothing);
    });
  });
}
