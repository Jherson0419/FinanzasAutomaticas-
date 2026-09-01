import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:finanzas_automaticas/domain/repositories/consejos_financieros_repository.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_para_consejos.dart';
import 'package:finanzas_automaticas/infrastructure/consejos/gemini_consejos_repository.dart';

class _FakePreferenciasRepository implements PreferenciasRepository {
  String? apiKey;
  _FakePreferenciasRepository({this.apiKey});

  @override
  Future<String?> obtenerApiKeyGemini() async => apiKey;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async => this.apiKey = apiKey;
  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}
  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<bool> recordarSesion() async => true;
  @override
  Future<void> guardarRecordarSesion(bool recordar) async {}
  @override
  Future<DateTime?> ultimaGeneracionNotificacionesVencimiento() async => null;
  @override
  Future<void> guardarUltimaGeneracionNotificacionesVencimiento(
    DateTime fecha,
  ) async {}
  @override
  Future<void> limpiarTodo() async {}
}

const _resumenVacio = ResumenParaConsejos(
  deudasActivas: [],
  ingresosPorCategoriaMes: [],
  gastosPorCategoriaMes: [],
  saldoTotalPorMoneda: {},
);

void main() {
  test(
    'sin API key configurada lanza ApiKeyGeminiFaltanteError sin llamar a la red',
    () async {
      var llamadoHttp = false;
      final client = MockClient((request) async {
        llamadoHttp = true;
        return http.Response('{}', 200);
      });
      final repo = GeminiConsejosRepository(
        preferenciasRepository: _FakePreferenciasRepository(apiKey: null),
        client: client,
      );

      await expectLater(
        () => repo.generarConsejos(_resumenVacio),
        throwsA(isA<ApiKeyGeminiFaltanteError>()),
      );
      expect(llamadoHttp, isFalse);
    },
  );

  test(
    'con una API key vacía (solo espacios) también lanza ApiKeyGeminiFaltanteError',
    () async {
      final client = MockClient((request) async => http.Response('{}', 200));
      final repo = GeminiConsejosRepository(
        preferenciasRepository: _FakePreferenciasRepository(apiKey: '   '),
        client: client,
      );

      await expectLater(
        () => repo.generarConsejos(_resumenVacio),
        throwsA(isA<ApiKeyGeminiFaltanteError>()),
      );
    },
  );

  test('parsea la lista de consejos de una respuesta 200 exitosa', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), contains('key=clave-valida'));
      return http.Response(
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text':
                        'Paga primero la deuda con más interés\n'
                        'Aparta un 10% de tu sueldo cada mes\n'
                        'Considera un fondo de emergencia',
                  },
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final repo = GeminiConsejosRepository(
      preferenciasRepository: _FakePreferenciasRepository(
        apiKey: 'clave-valida',
      ),
      client: client,
    );

    final consejos = await repo.generarConsejos(_resumenVacio);

    expect(consejos, [
      'Paga primero la deuda con más interés',
      'Aparta un 10% de tu sueldo cada mes',
      'Considera un fondo de emergencia',
    ]);
  });

  test('un statusCode 403 lanza un mensaje claro sobre la API key', () async {
    final client = MockClient(
      (request) async => http.Response('{"error": "forbidden"}', 403),
    );
    final repo = GeminiConsejosRepository(
      preferenciasRepository: _FakePreferenciasRepository(
        apiKey: 'clave-invalida',
      ),
      client: client,
    );

    await expectLater(
      () => repo.generarConsejos(_resumenVacio),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('API key de Gemini parece inválida'),
        ),
      ),
    );
  });

  test(
    'un fallo de red lanza un mensaje claro sin exponer la excepción cruda',
    () async {
      final client = MockClient((request) async {
        throw const SocketExceptionFake();
      });
      final repo = GeminiConsejosRepository(
        preferenciasRepository: _FakePreferenciasRepository(apiKey: 'clave'),
        client: client,
      );

      await expectLater(
        () => repo.generarConsejos(_resumenVacio),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar con Gemini'),
          ),
        ),
      );
    },
  );
}

/// Excepción simple para simular un fallo de red sin depender de
/// `dart:io` (no disponible/necesario en este test).
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
  @override
  String toString() => 'SocketExceptionFake';
}
