import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/amistad_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/auth_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/notificacion_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/perfil_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/servicios_nube_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/main_local.dart';
import 'package:finanzas_automaticas/presentation/app.dart';
import 'package:finanzas_automaticas/presentation/screens/deuda_formulario.dart';
import 'package:finanzas_automaticas/presentation/screens/mi_perfil_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/onboarding/onboarding_flow_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Fase 78 — el árbol de `main_local.dart` funciona sin `Supabase.
/// initialize` ni `Firebase.initializeApp` (en estas pruebas ninguno de los
/// dos existe: cualquier acceso a `Supabase.instance` lanzaría).
void main() {
  late SharedPreferences prefs;
  late AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  ProviderContainer contenedor() {
    final container = ProviderContainer(
      overrides: [
        ...overridesModoLocal(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('overridesModoLocal', () {
    test('resuelve cada puerto a su adaptador local y a Drift', () async {
      final c = contenedor();

      expect(c.read(modoLocalProvider), isTrue);
      expect(c.read(datosEnLaNubeProvider), isFalse);
      expect(c.read(haySesionActivaProvider), isTrue);
      expect(await c.read(necesitaMigracionProvider.future), isFalse);
      expect(c.read(cuentaRepositoryProvider), isA<CuentaRepositoryDrift>());
      expect(c.read(authRepositoryProvider), isA<AuthRepositoryLocal>());
      expect(c.read(perfilRepositoryProvider), isA<PerfilRepositoryLocal>());
      expect(c.read(amistadRepositoryProvider), isA<AmistadRepositoryLocal>());
      expect(
        c.read(notificacionRepositoryProvider),
        isA<NotificacionRepositoryLocal>(),
      );
      expect(
        c.read(automatizacionRepositoryProvider),
        isA<AutomatizacionRepositoryLocal>(),
      );
      expect(
        c.read(tokenDispositivoRepositoryProvider),
        isA<TokenDispositivoRepositoryLocal>(),
      );
      expect(
        c.read(pushNotificationRepositoryProvider),
        isA<PushNotificationRepositoryLocal>(),
      );
      expect(
        c.read(chatConsejosRepositoryProvider),
        isA<ChatConsejosRepositoryLocal>(),
      );
    });

    test('ignora datos_en_la_nube=true heredado de producción', () async {
      await prefs.setBool('datos_en_la_nube', true);
      final c = contenedor();
      expect(c.read(datosEnLaNubeProvider), isFalse);
      expect(c.read(cuentaRepositoryProvider), isA<CuentaRepositoryDrift>());
    });

    test('no marca datos_en_la_nube aunque Drift esté vacío', () async {
      final c = contenedor();
      await c.read(necesitaMigracionProvider.future);
      expect(prefs.getBool('datos_en_la_nube'), isNull);
    });

    test('el onboarding se completa solo con perfil local', () async {
      final c = contenedor();
      expect(await c.read(onboardingCompletadoProvider.future), isFalse);

      final perfil = c.read(perfilRepositoryProvider);
      expect(await perfil.nickDisponible('jherson'), isTrue);
      await perfil.guardarNick('jherson');
      c.invalidate(perfilProvider);

      expect(await c.read(onboardingCompletadoProvider.future), isTrue);
    });

    test('Cargar datos de ejemplo + Borrar todo vía providers', () async {
      final c = contenedor();
      await c.read(perfilRepositoryProvider).guardarNick('jherson');

      final resultado = await c.read(sembrarDatosDemoProvider).call();
      expect(resultado.registrosCreados, greaterThan(0));
      // 3 de fondos + la Visa de ejemplo (Fase 84).
      expect(await c.read(cuentasProvider.future), hasLength(4));

      await c.read(datosLocalesRepositoryProvider).borrarTodo();
      c.invalidate(cuentasProvider);
      c.invalidate(perfilProvider);
      expect(await c.read(cuentasProvider.future), isEmpty);
      expect(await c.read(onboardingCompletadoProvider.future), isFalse);
    });
  });

  group('UI en modo local', () {
    Future<void> montar(WidgetTester tester, Widget hijo) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overridesModoLocal(prefs),
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: hijo,
        ),
      );
    }

    testWidgets(
      'la app arranca sin login y sin Supabase directo al onboarding',
      (tester) async {
        await montar(tester, const FinanzasAutomaticasApp());
        await tester.pumpAndSettle();

        expect(find.byType(OnboardingFlowScreen), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsNothing);
      },
    );

    testWidgets(
      'Mi perfil: sección "Modo local" y lo de la nube deshabilitado con aviso',
      (tester) async {
        await PerfilRepositoryLocal(prefs).guardarNick('jherson');
        await montar(tester, const MaterialApp(home: MiPerfilScreen()));
        await tester.pumpAndSettle();

        expect(find.text('Modo local'), findsOneWidget);
        expect(find.byKey(const Key('indicador_modo_local')), findsOneWidget);
        expect(find.text('Cargar datos de ejemplo'), findsOneWidget);
        expect(find.text('Borrar todos los datos locales'), findsOneWidget);
        expect(find.text('Disponible con la nube'), findsWidgets);

        ListTile tile(String titulo) => tester.widget<ListTile>(
          find.ancestor(of: find.text(titulo), matching: find.byType(ListTile)),
        );
        expect(tile('Automatización').enabled, isFalse);
        expect(tile('Mis amigos').enabled, isFalse);

        ButtonStyleButton boton(String texto) =>
            tester.widget<ButtonStyleButton>(
              find.ancestor(
                of: find.text(texto),
                matching: find.bySubtype<ButtonStyleButton>(),
              ),
            );
        expect(boton('Cerrar sesión').onPressed, isNull);
        expect(boton('Eliminar mi cuenta').onPressed, isNull);
        expect(boton('Compartir mi perfil').onPressed, isNull);
      },
    );

    testWidgets('Cargar datos de ejemplo siembra Drift y avisa', (
      tester,
    ) async {
      await PerfilRepositoryLocal(prefs).guardarNick('jherson');
      await montar(tester, const MaterialApp(home: MiPerfilScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cargar datos de ejemplo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Datos de ejemplo cargados'), findsOneWidget);
      final cuentas = await tester.runAsync(
        () => CuentaRepositoryDrift(db).obtenerTodas(),
      );
      expect(cuentas, hasLength(4)); // incluye la Visa (Fase 84)
    });

    testWidgets('Borrar todos los datos locales pide confirmación', (
      tester,
    ) async {
      await PerfilRepositoryLocal(prefs).guardarNick('jherson');
      await montar(tester, const MaterialApp(home: MiPerfilScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Borrar todos los datos locales'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar todos los datos locales?'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(prefs.getString(PerfilRepositoryLocal.claveNick), 'jherson');

      await tester.tap(find.text('Borrar todos los datos locales'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Borrar todo'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pumpAndSettle();
      expect(prefs.getString(PerfilRepositoryLocal.claveNick), isNull);
    });

    testWidgets('deuda_formulario: vincular amigo deshabilitado con aviso', (
      tester,
    ) async {
      await montar(
        tester,
        MaterialApp(
          home: Scaffold(body: DeudaFormulario(onGuardadoExitoso: () {})),
        ),
      );
      await tester.pumpAndSettle();

      // Elegir "Persona natural" como tipo de acreedor.
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<TipoAcreedor>,
          'Tipo de acreedor',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persona natural').last);
      await tester.pumpAndSettle();

      final switchAmigo = tester.widget<SwitchListTile>(
        find.widgetWithText(SwitchListTile, '¿Es un amigo de Finzo?'),
      );
      expect(switchAmigo.onChanged, isNull);
      expect(find.text('Disponible con la nube'), findsOneWidget);
    });
  });
}
