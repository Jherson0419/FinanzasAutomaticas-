import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/mensaje_consejo.dart';
import 'package:finanzas_automaticas/domain/repositories/consejos_financieros_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_para_consejos.dart';
import 'package:finanzas_automaticas/infrastructure/consejos/edge_function_consejos_repository.dart';

const _resumenVacio = ResumenParaConsejos(
  deudasActivas: [],
  ingresosPorCategoriaMes: [],
  gastosPorCategoriaMes: [],
  saldoTotalPorMoneda: {},
);

/// `SupabaseClient` con un `http.Client` inyectado (soportado por el
/// constructor, ver `supabase_adapters_mapeo_test.dart` para el mismo
/// patrón con `.from()`) — permite ejercitar `functions.invoke` sin tocar
/// la red real ni necesitar una sesión de verdad: el mock intercepta la
/// petición HTTP antes de que salga del dispositivo.
SupabaseClient _clienteConHttp(http.Client httpClient) {
  return SupabaseClient(
    'https://example.supabase.co',
    'clave-de-prueba',
    httpClient: httpClient,
  );
}

void main() {
  group('enviarMensaje', () {
    test('una respuesta 429 se traduce a LimiteDiarioConsejosError', () async {
      final client = MockClient((request) async {
        return http.Response(
          '{"error":"limite_diario_alcanzado"}',
          429,
          headers: {'content-type': 'application/json'},
        );
      });
      final repo = EdgeFunctionConsejosRepository(_clienteConHttp(client));

      await expectLater(
        () => repo.enviarMensaje(mensaje: 'Hola'),
        throwsA(isA<LimiteDiarioConsejosError>()),
      );
    });

    test(
      'manda mensaje/esPrimerMensaje/resumen en el body de la petición',
      () async {
        Map<String, dynamic>? bodyCapturado;
        final client = MockClient((request) async {
          bodyCapturado = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"respuesta":"Hola, encantado de ayudarte."}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final repo = EdgeFunctionConsejosRepository(_clienteConHttp(client));

        await repo.enviarMensaje(
          mensaje: '',
          esPrimerMensaje: true,
          resumen: _resumenVacio,
        );

        expect(bodyCapturado, isNotNull);
        expect(bodyCapturado!['esPrimerMensaje'], isTrue);
        expect(bodyCapturado!['resumen'], isNotNull);
        expect(bodyCapturado!['mensaje'], '');
      },
    );

    test(
      'Fase 60: incluye tarjetasCredito (usado/línea/disponible) en el '
      'resumen mandado, nunca mezclado con saldoTotalPorMoneda',
      () async {
        Map<String, dynamic>? bodyCapturado;
        final client = MockClient((request) async {
          bodyCapturado = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"respuesta":"Hola."}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final repo = EdgeFunctionConsejosRepository(_clienteConHttp(client));
        const resumenConTarjeta = ResumenParaConsejos(
          deudasActivas: [],
          ingresosPorCategoriaMes: [],
          gastosPorCategoriaMes: [],
          saldoTotalPorMoneda: {Moneda.pen: 500},
          tarjetasCredito: [
            TarjetaCreditoParaConsejos(
              montoUsado: 800,
              lineaTotal: 2000,
              creditoDisponible: 1200,
              moneda: Moneda.pen,
            ),
          ],
        );

        await repo.enviarMensaje(
          mensaje: '',
          esPrimerMensaje: true,
          resumen: resumenConTarjeta,
        );

        final resumenJson =
            bodyCapturado!['resumen'] as Map<String, dynamic>;
        expect(resumenJson['saldoTotalPorMoneda'], {'pen': 500});
        final tarjetas = resumenJson['tarjetasCredito'] as List<dynamic>;
        expect(tarjetas, hasLength(1));
        final tarjeta = tarjetas.single as Map<String, dynamic>;
        expect(tarjeta['montoUsado'], 800);
        expect(tarjeta['lineaTotal'], 2000);
        expect(tarjeta['creditoDisponible'], 1200);
        expect(tarjeta['moneda'], 'pen');
      },
    );

    test(
      'un mensaje de seguimiento manda esPrimerMensaje en false y sin resumen',
      () async {
        Map<String, dynamic>? bodyCapturado;
        final client = MockClient((request) async {
          bodyCapturado = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            '{"respuesta":"Claro, aquí va mi consejo."}',
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final repo = EdgeFunctionConsejosRepository(_clienteConHttp(client));

        await repo.enviarMensaje(mensaje: '¿Cómo ahorro más?');

        expect(bodyCapturado!['esPrimerMensaje'], isFalse);
        expect(bodyCapturado!['mensaje'], '¿Cómo ahorro más?');
        expect(bodyCapturado!.containsKey('resumen'), isFalse);
      },
    );

    test(
      'una respuesta de error distinta de 429 lanza un mensaje genérico, sin '
      'exponer los detalles crudos del servidor',
      () async {
        final client = MockClient((request) async {
          return http.Response(
            '{"error":"La función no tiene configurado GEMINI_API_KEY"}',
            500,
            headers: {'content-type': 'application/json'},
          );
        });
        final repo = EdgeFunctionConsejosRepository(_clienteConHttp(client));

        Object? errorCapturado;
        try {
          await repo.enviarMensaje(mensaje: 'Hola');
          fail('debería haber lanzado una excepción');
        } catch (error) {
          errorCapturado = error;
        }

        expect(errorCapturado, isA<StateError>());
        expect(errorCapturado, isNot(isA<LimiteDiarioConsejosError>()));
        final mensaje = (errorCapturado as StateError).message;
        expect(mensaje, isNot(contains('GEMINI_API_KEY')));
        expect(mensaje, contains('Intenta de nuevo'));
      },
    );

    test(
      'un fallo de red lanza un mensaje claro sin exponer la excepción cruda',
      () async {
        final client = MockClient((request) async {
          throw const SocketExceptionFake();
        });
        final repo = EdgeFunctionConsejosRepository(_clienteConHttp(client));

        await expectLater(
          () => repo.enviarMensaje(mensaje: 'Hola'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('conexión a internet'),
            ),
          ),
        );
      },
    );
  });

  group('aDominio', () {
    test('mapea rol/contenido/fecha de una fila de mensajes_consejos', () {
      final repo = EdgeFunctionConsejosRepository(
        SupabaseClient('https://example.supabase.co', 'clave-de-prueba'),
      );

      final mensaje = repo.aDominio({
        'id': 'msg-1',
        'user_id': 'user-1',
        'rol': 'usuario',
        'contenido': 'Hola, este es mi resumen.',
        'created_at': '2026-01-05T10:30:00.000Z',
      });

      expect(mensaje.id, 'msg-1');
      expect(mensaje.rol, RolMensajeConsejo.usuario);
      expect(mensaje.contenido, 'Hola, este es mi resumen.');
      expect(mensaje.fecha, DateTime.parse('2026-01-05T10:30:00.000Z'));
    });

    test('mapea rol asistente', () {
      final repo = EdgeFunctionConsejosRepository(
        SupabaseClient('https://example.supabase.co', 'clave-de-prueba'),
      );

      final mensaje = repo.aDominio({
        'id': 'msg-2',
        'user_id': 'user-1',
        'rol': 'asistente',
        'contenido': 'Encantado de ayudarte.',
        'created_at': '2026-01-05T10:31:00.000Z',
      });

      expect(mensaje.rol, RolMensajeConsejo.asistente);
    });
  });
}

/// Excepción simple para simular un fallo de red sin depender de `dart:io`
/// (mismo patrón que `gemini_consejos_repository_test.dart`).
class SocketExceptionFake implements Exception {
  const SocketExceptionFake();
  @override
  String toString() => 'SocketExceptionFake';
}
