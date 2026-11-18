import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente sin sesión: alcanza para los `aDominio*` (no leen
/// `auth.currentUser`).
SupabaseClient clienteSupabaseFalso() =>
    SupabaseClient('https://example.supabase.co', 'clave-de-prueba');

String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// Cliente con sesión válida sin red real (mismo truco que
/// `supabase_adapters_mapeo_test.dart`) para poder llamar `aFila`, que
/// escribe `user_id` desde `auth.currentUser`.
Future<SupabaseClient> clienteSupabaseAutenticado(String userId) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'clave-de-prueba',
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode({'id': userId}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  final jwt = [
    _b64({'alg': 'HS256', 'typ': 'JWT'}),
    _b64({'sub': userId, 'exp': exp, 'role': 'authenticated'}),
    _b64('firma-no-verificada-en-tests'),
  ].join('.');
  await client.auth.setSession('refresh-token-de-prueba', accessToken: jwt);
  return client;
}
