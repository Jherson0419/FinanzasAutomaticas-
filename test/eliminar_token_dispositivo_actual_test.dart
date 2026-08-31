import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/mensaje_push.dart';
import 'package:finanzas_automaticas/domain/repositories/push_notification_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/token_dispositivo_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_token_dispositivo_actual.dart';

class _FakePushNotificationRepository implements PushNotificationRepository {
  String? token = 'token-abc';
  Object? errorAlObtenerToken;

  @override
  String plataforma = 'ios';

  @override
  Future<bool> solicitarPermiso() async => true;

  @override
  Future<String?> obtenerToken() async {
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
  String? tokenEliminado;
  Object? errorAlEliminar;

  @override
  Future<void> guardarToken({
    required String token,
    required String plataforma,
  }) async {}

  @override
  Future<void> eliminarToken(String token) async {
    if (errorAlEliminar != null) throw errorAlEliminar!;
    tokenEliminado = token;
  }
}

void main() {
  late _FakePushNotificationRepository push;
  late _FakeTokenDispositivoRepository tokenRepo;
  late EliminarTokenDispositivoActual caso;

  setUp(() {
    push = _FakePushNotificationRepository();
    tokenRepo = _FakeTokenDispositivoRepository();
    caso = EliminarTokenDispositivoActual(
      pushNotificationRepository: push,
      tokenDispositivoRepository: tokenRepo,
    );
  });

  test('elimina el token de este dispositivo', () async {
    await caso.call();

    expect(tokenRepo.tokenEliminado, 'token-abc');
  });

  test('sin token disponible, no llama a eliminarToken', () async {
    push.token = null;

    await caso.call();

    expect(tokenRepo.tokenEliminado, isNull);
  });

  test(
    'un error al obtener el token no se propaga (no debe bloquear cerrar sesión)',
    () async {
      push.errorAlObtenerToken = StateError('sin Firebase inicializado');

      await expectLater(caso.call(), completes);
    },
  );

  test(
    'un error al eliminar el token en Supabase no se propaga',
    () async {
      tokenRepo.errorAlEliminar = StateError('sin conexión');

      await expectLater(caso.call(), completes);
    },
  );
}
