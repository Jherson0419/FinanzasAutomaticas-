import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/mensaje_push.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/push_notification_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/token_dispositivo_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/login_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/olvide_contrasena_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAuthRepository implements AuthRepository {
  bool _haySesion = false;
  String? emailRecibido;
  String? passwordRecibido;
  Object? errorAlIniciarSesion;
  Object? errorAlIniciarSesionConGoogle;
  int vecesIniciarSesionConGoogle = 0;

  @override
  bool get haySesionActiva => _haySesion;

  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {
    emailRecibido = email;
    passwordRecibido = password;
    if (errorAlIniciarSesion != null) throw errorAlIniciarSesion!;
    _haySesion = true;
  }

  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> cerrarSesion() async => _haySesion = false;

  @override
  Future<void> eliminarCuenta() async => _haySesion = false;

  @override
  Future<void> enviarLinkRecuperacion({required String email}) async {}

  @override
  Future<void> actualizarContrasena({required String nuevaContrasena}) async {}

  @override
  Future<void> iniciarSesionConGoogle() async {
    vecesIniciarSesionConGoogle++;
    if (errorAlIniciarSesionConGoogle != null) {
      throw errorAlIniciarSesionConGoogle!;
    }
    // A propósito NO pone `_haySesion = true` aquí: en la app real, la
    // sesión llega después por el deep link, no como resultado directo de
    // este método (ver `AuthRepository.iniciarSesionConGoogle`).
  }
}

/// Fase 65 — solo lo que `LoginScreen`/`OlvideContrasenaScreen` tocan:
/// `guardarRecordarSesion` (B.2). El resto de `PreferenciasRepository` no
/// aplica a esta pantalla.
class _FakePreferenciasRepository implements PreferenciasRepository {
  bool? recordarSesionGuardado;

  @override
  Future<bool> recordarSesion() async => recordarSesionGuardado ?? true;
  @override
  Future<void> guardarRecordarSesion(bool recordar) async =>
      recordarSesionGuardado = recordar;
  @override
  Future<DateTime?> ultimaGeneracionNotificacionesVencimiento() async => null;
  @override
  Future<void> guardarUltimaGeneracionNotificacionesVencimiento(
    DateTime fecha,
  ) async {}

  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<bool> onboardingCompletado() async => true;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<void> limpiarTodo() async {}
}

/// Fase 71 — usado solo por el grupo de tests de "registrar el token de
/// push tras un login exitoso".
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

Future<_FakeAuthRepository> _pumpScreen(
  WidgetTester tester, {
  Object? errorAlIniciarSesion,
  _FakePreferenciasRepository? fakePreferencias,
  PushNotificationRepository? fakePush,
  TokenDispositivoRepository? fakeTokenDispositivo,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeAuthRepository()
    ..errorAlIniciarSesion = errorAlIniciarSesion;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(fake),
        preferenciasRepositoryProvider.overrideWithValue(
          fakePreferencias ?? _FakePreferenciasRepository(),
        ),
        if (fakePush != null)
          pushNotificationRepositoryProvider.overrideWithValue(fakePush),
        if (fakeTokenDispositivo != null)
          tokenDispositivoRepositoryProvider.overrideWithValue(
            fakeTokenDispositivo,
          ),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets(
    'el botón Iniciar sesión está deshabilitado con el formulario vacío',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'un correo con formato inválido mantiene el botón deshabilitado',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'no-es-un-correo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'una contraseña de menos de 6 caracteres mantiene el botón deshabilitado',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        '123',
      );
      await tester.pump();

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'con datos válidos, iniciar sesión invoca AuthRepository con el correo y contraseña ingresados',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(fake.emailRecibido, 'user@example.com');
      expect(fake.passwordRecibido, 'secreto123');
      expect(fake.haySesionActiva, isTrue);
    },
  );

  testWidgets('un error de credenciales muestra el mensaje traducido', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      errorAlIniciarSesion: StateError('Correo o contraseña incorrectos.'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo'),
      'user@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'secreto123',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
  });

  testWidgets('el enlace "Crear cuenta" navega a la pantalla de registro', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar contraseña'), findsOneWidget);
  });

  testWidgets(
    'Fase 54: tras crear una cuenta con éxito, vuelve al login y avisa '
    'que hay que confirmar el correo (el deep link llega después, por '
    'fuera de la app)',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'nuevo@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'secreto123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'secreto123',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      // De vuelta en LoginScreen (el formulario de registro ya no está).
      expect(find.text('Confirmar contraseña'), findsNothing);
      expect(
        find.text('Revisa tu correo para confirmar tu cuenta.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Fase 56: "Continuar con Google" invoca AuthRepository.iniciarSesionConGoogle '
    'sin dejar la sesión activa de inmediato (llega después, por el deep link)',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Continuar con Google'));
      await tester.pumpAndSettle();

      expect(fake.vecesIniciarSesionConGoogle, 1);
      expect(fake.haySesionActiva, isFalse);
    },
  );

  testWidgets(
    'Fase 56: un error al continuar con Google muestra el mensaje traducido',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);
      fake.errorAlIniciarSesionConGoogle = StateError(
        'No se pudo continuar con Google. Revisa tu conexión a internet e '
        'intenta de nuevo.',
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Continuar con Google'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No se pudo continuar con Google. Revisa tu conexión a internet e '
          'intenta de nuevo.',
        ),
        findsOneWidget,
      );
    },
  );

  group('Fase 65 — "Recuérdame" (B.2)', () {
    testWidgets('el checkbox "Recuérdame" empieza marcado por defecto', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets(
      'iniciar sesión con "Recuérdame" marcado guarda recordarSesion=true',
      (WidgetTester tester) async {
        final fakePreferencias = _FakePreferenciasRepository();
        await _pumpScreen(tester, fakePreferencias: fakePreferencias);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'user@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'secreto123',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(fakePreferencias.recordarSesionGuardado, isTrue);
      },
    );

    testWidgets(
      'desmarcar "Recuérdame" y luego iniciar sesión guarda recordarSesion=false',
      (WidgetTester tester) async {
        final fakePreferencias = _FakePreferenciasRepository();
        await _pumpScreen(tester, fakePreferencias: fakePreferencias);

        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'user@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'secreto123',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(fakePreferencias.recordarSesionGuardado, isFalse);
      },
    );

    testWidgets(
      'un intento de login fallido no guarda ninguna preferencia de recordarSesion',
      (WidgetTester tester) async {
        final fakePreferencias = _FakePreferenciasRepository();
        await _pumpScreen(
          tester,
          fakePreferencias: fakePreferencias,
          errorAlIniciarSesion: StateError('Correo o contraseña incorrectos.'),
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'user@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'secreto123',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(fakePreferencias.recordarSesionGuardado, isNull);
      },
    );
  });

  testWidgets(
    'Fase 65 (B.3): "¿Olvidaste tu contraseña?" navega a OlvideContrasenaScreen',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();

      expect(find.byType(OlvideContrasenaScreen), findsOneWidget);
    },
  );

  group('Fase 71 — registrar el token de push tras un login exitoso', () {
    testWidgets(
      'con permiso concedido, guarda el token del dispositivo en Supabase',
      (WidgetTester tester) async {
        final fakePush = _FakePushNotificationRepository();
        final fakeTokenDispositivo = _FakeTokenDispositivoRepository();
        await _pumpScreen(
          tester,
          fakePush: fakePush,
          fakeTokenDispositivo: fakeTokenDispositivo,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'user@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'secreto123',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(fakeTokenDispositivo.tokenGuardado, 'token-abc');
        expect(fakeTokenDispositivo.plataformaGuardada, 'ios');
      },
    );

    testWidgets(
      'con permiso denegado, no guarda ningún token pero el login igual '
      'termina con éxito',
      (WidgetTester tester) async {
        final fakePush = _FakePushNotificationRepository()
          ..permisoConcedido = false;
        final fakeTokenDispositivo = _FakeTokenDispositivoRepository();
        final fake = await _pumpScreen(
          tester,
          fakePush: fakePush,
          fakeTokenDispositivo: fakeTokenDispositivo,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'user@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'secreto123',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(fakeTokenDispositivo.tokenGuardado, isNull);
        expect(fake.haySesionActiva, isTrue);
      },
    );

    testWidgets(
      'sin overrides de push/token (como en el resto de los tests de esta '
      'pantalla), el login igual termina con éxito — el registro del token '
      'es secundario y nunca debe bloquearlo',
      (WidgetTester tester) async {
        final fake = await _pumpScreen(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Correo'),
          'user@example.com',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Contraseña'),
          'secreto123',
        );
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(fake.haySesionActiva, isTrue);
      },
    );
  });
}
