import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/parsear_deep_link_agregar_amigo.dart';

void main() {
  test('extrae el nick de un link válido', () {
    final nick = parsearNickDesdeLinkAgregarAmigo(
      Uri.parse('finzo://agregar-amigo?nick=jherson23'),
    );

    expect(nick, 'jherson23');
  });

  test('recorta espacios alrededor del nick', () {
    final nick = parsearNickDesdeLinkAgregarAmigo(
      Uri.parse('finzo://agregar-amigo?nick=%20jherson23%20'),
    );

    expect(nick, 'jherson23');
  });

  test('devuelve null si el host no es agregar-amigo', () {
    final nick = parsearNickDesdeLinkAgregarAmigo(
      Uri.parse('finzo://login-callback?nick=jherson23'),
    );

    expect(nick, isNull);
  });

  test('devuelve null si no trae el parámetro nick', () {
    final nick = parsearNickDesdeLinkAgregarAmigo(
      Uri.parse('finzo://agregar-amigo'),
    );

    expect(nick, isNull);
  });

  test('devuelve null si el nick viene vacío', () {
    final nick = parsearNickDesdeLinkAgregarAmigo(
      Uri.parse('finzo://agregar-amigo?nick='),
    );

    expect(nick, isNull);
  });
}
