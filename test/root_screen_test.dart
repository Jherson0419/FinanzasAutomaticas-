import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/mensaje_push.dart';
import 'package:finanzas_automaticas/domain/repositories/push_notification_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/token_dispositivo_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/dashboard_fixtures.dart';
import 'package:finanzas_automaticas/presentation/screens/root_screen.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Fase 76 — controlable a mano desde el test (a diferencia de
/// `haySesionActivaProvider`, que en la app real reacciona sola al deep
/// link): simula la transición de "sin sesión" a "con sesión" sin importar
/// el camino de login que la produjo.
final _sesionControladaProvider = StateProvider<bool>((ref) => false);

class _FakePushNotificationRepository implements PushNotificationRepository {
  bool permisoConcedido = true;
  String? token = 'token-abc';

  @override
  String plataforma = 'ios';

  @override
  Future<bool> solicitarPermiso() async => permisoConcedido;

  @override
  Future<String?> obtenerToken() async => token;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<MensajePush> get onMensajePrimerPlano => const Stream.empty();

  @override
  Stream<MensajePush> get onMensajeAbierto => const Stream.empty();

  @override
  Future<MensajePush?> mensajeInicial() async => null;
}

class _FakeTokenDispositivoRepository implements TokenDispositivoRepository {
  String? tokenGuardado;
  String? plataformaGuardada;

  @override
  Future<void> guardarToken({
    required String token,
    required String plataforma,
  }) async {
    tokenGuardado = token;
    plataformaGuardada = plataforma;
  }

  @override
  Future<void> eliminarToken(String token) async {}
}

/// Overrides comunes para simular "ya hay sesión, sin datos locales sin
/// migrar" — el estado por defecto para probar la lógica de onboarding sin
/// que `LoginScreen`/`MigrarDatosScreen` se interpongan.
List<Override> _sesionActiva() => [
  haySesionActivaProvider.overrideWith((ref) => true),
  necesitaMigracionProvider.overrideWith((ref) async => false),
];

void main() {
  testWidgets('sin sesión activa se muestra el login', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [haySesionActivaProvider.overrideWith((ref) => false)],
        child: const MaterialApp(home: RootScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('SALDO TOTAL'), findsNothing);
    expect(find.text('Bienvenido a Finzo: Finanzas Automáticas'), findsNothing);
  });

  testWidgets(
    'con sesión activa pero onboardingCompletado en false se muestra el wizard en vez del dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._sesionActiva(),
            onboardingCompletadoProvider.overrideWith((ref) => false),
            cuentasProvider.overrideWith((ref) => const []),
            deudasProvider.overrideWith((ref) => const []),
          ],
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsOneWidget,
      );
      expect(find.text('SALDO TOTAL'), findsNothing);
    },
  );

  testWidgets(
    'con sesión activa y onboardingCompletado en true se muestra el dashboard',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._sesionActiva(),
            onboardingCompletadoProvider.overrideWith((ref) => true),
            cuentasProvider.overrideWith((ref) => cuentasDashboardFixture),
            resumenDashboardProvider.overrideWith(
              (ref) => resumenDashboardFixture,
            ),
            nombreUsuarioProvider.overrideWith((ref) => 'Jherson'),
          ],
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsNothing,
      );
    },
  );

  group(
    'Fase 76 — pedir permiso de notificaciones y registrar el token tras '
    'cualquier login exitoso',
    () {
      Future<void> pumpConSesionControlable(
        WidgetTester tester, {
        required PushNotificationRepository fakePush,
        required TokenDispositivoRepository fakeTokenDispositivo,
      }) async {
        tester.view.physicalSize = const Size(1200, 3000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              haySesionActivaProvider.overrideWith(
                (ref) => ref.watch(_sesionControladaProvider),
              ),
              necesitaMigracionProvider.overrideWith((ref) async => false),
              onboardingCompletadoProvider.overrideWith((ref) => false),
              cuentasProvider.overrideWith((ref) => const []),
              deudasProvider.overrideWith((ref) => const []),
              pushNotificationRepositoryProvider.overrideWithValue(fakePush),
              tokenDispositivoRepositoryProvider.overrideWithValue(
                fakeTokenDispositivo,
              ),
            ],
            child: const MaterialApp(home: RootScreen()),
          ),
        );
        await tester.pumpAndSettle();
      }

      void iniciarSesion(WidgetTester tester) {
        final element = tester.element(find.byType(RootScreen));
        final container = ProviderScope.containerOf(element);
        container.read(_sesionControladaProvider.notifier).state = true;
      }

      testWidgets(
        'tras un login con correo/contraseña (invalidación síncrona en '
        'LoginScreen), guarda el token del dispositivo',
        (WidgetTester tester) async {
          final fakePush = _FakePushNotificationRepository();
          final fakeTokenDispositivo = _FakeTokenDispositivoRepository();
          await pumpConSesionControlable(
            tester,
            fakePush: fakePush,
            fakeTokenDispositivo: fakeTokenDispositivo,
          );

          iniciarSesion(tester);
          await tester.pumpAndSettle();

          expect(fakeTokenDispositivo.tokenGuardado, 'token-abc');
          expect(fakeTokenDispositivo.plataformaGuardada, 'ios');
        },
      );

      testWidgets(
        'tras un login con Google (la sesión llega sola, por el deep link, '
        'sin que LoginScreen haga nada), también guarda el token del '
        'dispositivo — el mismo mecanismo que el de correo/contraseña, '
        'porque ambos terminan siendo la misma transición de '
        'haySesionActivaProvider',
        (WidgetTester tester) async {
          final fakePush = _FakePushNotificationRepository();
          final fakeTokenDispositivo = _FakeTokenDispositivoRepository();
          await pumpConSesionControlable(
            tester,
            fakePush: fakePush,
            fakeTokenDispositivo: fakeTokenDispositivo,
          );

          // Nada llama a un método de "login con Google" aquí a propósito:
          // en la app real ese método (`_continuarConGoogle`) solo abre el
          // navegador y nunca deja la sesión activa de inmediato — la
          // transición de `haySesionActivaProvider` es la única señal
          // observable de que el login por Google (o por confirmación de
          // correo, Fase 54) terminó.
          iniciarSesion(tester);
          await tester.pumpAndSettle();

          expect(fakeTokenDispositivo.tokenGuardado, 'token-abc');
          expect(fakeTokenDispositivo.plataformaGuardada, 'ios');
        },
      );

      testWidgets(
        'con permiso denegado, no guarda ningún token pero no rompe la app',
        (WidgetTester tester) async {
          final fakePush = _FakePushNotificationRepository()
            ..permisoConcedido = false;
          final fakeTokenDispositivo = _FakeTokenDispositivoRepository();
          await pumpConSesionControlable(
            tester,
            fakePush: fakePush,
            fakeTokenDispositivo: fakeTokenDispositivo,
          );

          iniciarSesion(tester);
          await tester.pumpAndSettle();

          expect(fakeTokenDispositivo.tokenGuardado, isNull);
        },
      );

      testWidgets(
        'con sesión ya activa desde el primer build (app reabierta, no un '
        'login nuevo) no pide permiso ni registra ningún token',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(1200, 3000);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final fakeTokenDispositivo = _FakeTokenDispositivoRepository();

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                ..._sesionActiva(),
                onboardingCompletadoProvider.overrideWith((ref) => false),
                cuentasProvider.overrideWith((ref) => const []),
                deudasProvider.overrideWith((ref) => const []),
                pushNotificationRepositoryProvider.overrideWithValue(
                  _FakePushNotificationRepository(),
                ),
                tokenDispositivoRepositoryProvider.overrideWithValue(
                  fakeTokenDispositivo,
                ),
              ],
              child: const MaterialApp(home: RootScreen()),
            ),
          );
          await tester.pumpAndSettle();

          expect(fakeTokenDispositivo.tokenGuardado, isNull);
        },
      );
    },
  );
}
