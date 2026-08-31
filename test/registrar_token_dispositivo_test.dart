import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/mensaje_push.dart';
import 'package:finanzas_automaticas/domain/repositories/push_notification_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/token_dispositivo_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_token_dispositivo.dart';

class _FakePushNotificationRepository implements PushNotificationRepository {
  bool permisoConcedido = true;
  String? token = 'token-abc';
  Object? errorAlSolicitarPermiso;
  Object? errorAlObtenerToken;
  int vecesSolicitarPermiso = 0;
  int vecesObtenerToken = 0;

  @override
  String plataforma = 'ios';

  @override
  Future<bool> solicitarPermiso() async {
    vecesSolicitarPermiso++;
    if (errorAlSolicitarPermiso != null) throw errorAlSolicitarPermiso!;
    return permisoConcedido;
  }

  @override
  Future<String?> obtenerToken() async {
    vecesObtenerToken++;
    if (errorAlObtenerToken != null) throw errorAlObtenerToken!;
    return token;
  }

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
  Object? errorAlGuardar;

  @override
  Future<void> guardarToken({
    required String token,
    required String plataforma,
  }) async {
    if (errorAlGuardar != null) throw errorAlGuardar!;
    tokenGuardado = token;
    plataformaGuardada = plataforma;
  }

  @override
  Future<void> eliminarToken(String token) async {}
}

void main() {
  late _FakePushNotificationRepository push;
  late _FakeTokenDispositivoRepository tokenRepo;
  late RegistrarTokenDispositivo caso;

  setUp(() {
    push = _FakePushNotificationRepository();
    tokenRepo = _FakeTokenDispositivoRepository();
    caso = RegistrarTokenDispositivo(
      pushNotificationRepository: push,
      tokenDispositivoRepository: tokenRepo,
    );
  });

  test('con permiso concedido, guarda el token y la plataforma', () async {
    await caso.call();

    expect(tokenRepo.tokenGuardado, 'token-abc');
    expect(tokenRepo.plataformaGuardada, 'ios');
  });

  test('con permiso denegado, no pide ni guarda ningún token', () async {
    push.permisoConcedido = false;

    await caso.call();

    expect(push.vecesObtenerToken, 0);
    expect(tokenRepo.tokenGuardado, isNull);
  });

  test('con permiso concedido pero sin token todavía, no guarda nada', () async {
    push.token = null;

    await caso.call();

    expect(tokenRepo.tokenGuardado, isNull);
  });

  test(
    'un error al pedir permiso no se propaga (registrar el token es secundario)',
    () async {
      push.errorAlSolicitarPermiso = StateError('sin Firebase inicializado');

      await expectLater(caso.call(), completes);
      expect(tokenRepo.tokenGuardado, isNull);
    },
  );

  test(
    'un error al guardar el token en Supabase no se propaga',
    () async {
      tokenRepo.errorAlGuardar = StateError('sin conexión');

      await expectLater(caso.call(), completes);
    },
  );
}
