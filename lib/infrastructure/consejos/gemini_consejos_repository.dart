import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/repositories/consejos_financieros_repository.dart';
import '../../domain/repositories/preferencias_repository.dart';
import '../../domain/usecases/dto/resumen_para_consejos.dart';

/// Adapter de `ConsejosFinancierosRepository` sobre la API de Gemini
/// (`generateContent`). Vive fuera de `infrastructure/persistence/` a
/// propósito: no es persistencia, es un servicio externo.
class GeminiConsejosRepository implements ConsejosFinancierosRepository {
  static const _modelo = 'gemini-2.0-flash';

  final PreferenciasRepository _preferenciasRepository;
  final http.Client _client;

  GeminiConsejosRepository({
    required PreferenciasRepository preferenciasRepository,
    http.Client? client,
  }) : _preferenciasRepository = preferenciasRepository,
       _client = client ?? http.Client();

  @override
  Future<List<String>> generarConsejos(ResumenParaConsejos resumen) async {
    final apiKey = await _preferenciasRepository.obtenerApiKeyGemini();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw ApiKeyGeminiFaltanteError();
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_modelo:generateContent'
      '?key=$apiKey',
    );

    http.Response respuesta;
    try {
      respuesta = await _client.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': _construirPrompt(resumen)},
              ],
            },
          ],
        }),
      );
    } catch (error) {
      debugPrint('GeminiConsejosRepository: fallo de red: $error');
      throw StateError(
        'No se pudo conectar con Gemini. Revisa tu conexión a internet e '
        'intenta de nuevo.',
      );
    }

    if (respuesta.statusCode != 200) {
      debugPrint(
        'GeminiConsejosRepository: respuesta ${respuesta.statusCode}: '
        '${respuesta.body}',
      );
      if (respuesta.statusCode == 400 || respuesta.statusCode == 403) {
        throw StateError(
          'Tu API key de Gemini parece inválida. Revísala en Ajustes.',
        );
      }
      if (respuesta.statusCode == 429) {
        throw StateError(
          'Se alcanzó el límite de uso de Gemini por ahora. Intenta de '
          'nuevo más tarde.',
        );
      }
      throw StateError(
        'No se pudo generar consejos en este momento. Intenta de nuevo '
        'más tarde.',
      );
    }

    final String? texto;
    try {
      texto = _extraerTexto(jsonDecode(respuesta.body) as Map<String, dynamic>);
    } catch (error) {
      debugPrint(
        'GeminiConsejosRepository: no se pudo parsear la respuesta: $error',
      );
      throw StateError('No se pudo interpretar la respuesta de Gemini.');
    }

    if (texto == null || texto.trim().isEmpty) {
      throw StateError('Gemini no devolvió ningún consejo. Intenta de nuevo.');
    }

    return _parsearConsejos(texto);
  }

  String? _extraerTexto(Map<String, dynamic> json) {
    final candidatos = json['candidates'] as List<dynamic>?;
    if (candidatos == null || candidatos.isEmpty) return null;
    final contenido = (candidatos.first as Map<String, dynamic>)['content'];
    final partes =
        (contenido as Map<String, dynamic>)['parts'] as List<dynamic>?;
    if (partes == null || partes.isEmpty) return null;
    return (partes.first as Map<String, dynamic>)['text'] as String?;
  }

  String _construirPrompt(ResumenParaConsejos resumen) {
    final buffer = StringBuffer()
      ..writeln(
        'Eres un asesor financiero personal. Con base en el siguiente '
        'resumen financiero anonimizado de un usuario en Perú, dame entre '
        '3 y 5 consejos financieros concretos y accionables.',
      )
      ..writeln(
        'Prioriza en este orden: cómo pagar las deudas más rápido, '
        'oportunidades de ahorro, e ideas simples de inversión.',
      )
      ..writeln(
        'Responde SOLO con una lista simple, una idea por línea, sin '
        'markdown, sin numeración ni viñetas, sin texto introductorio ni '
        'de cierre.',
      )
      ..writeln()
      ..writeln('Deudas activas:');
    if (resumen.deudasActivas.isEmpty) {
      buffer.writeln('- Ninguna');
    } else {
      for (final deuda in resumen.deudasActivas) {
        final pendiente = deuda.montoTotal - deuda.montoPagado;
        final interes = deuda.interesTotal;
        buffer.writeln(
          '- Tipo: ${deuda.tipoDeuda.name}, pendiente: '
          '${pendiente.toStringAsFixed(2)} ${deuda.moneda.name.toUpperCase()}'
          '${interes != null && interes > 0 ? ', interés total: ${interes.toStringAsFixed(2)}' : ''}',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('Ingresos del mes por categoría:');
    _escribirCategorias(buffer, resumen.ingresosPorCategoriaMes);
    buffer
      ..writeln()
      ..writeln('Gastos del mes por categoría:');
    _escribirCategorias(buffer, resumen.gastosPorCategoriaMes);
    buffer
      ..writeln()
      ..writeln('Saldo total disponible:');
    if (resumen.saldoTotalPorMoneda.isEmpty) {
      buffer.writeln('- Ninguno');
    } else {
      for (final entry in resumen.saldoTotalPorMoneda.entries) {
        buffer.writeln(
          '- ${entry.value.toStringAsFixed(2)} ${entry.key.name.toUpperCase()}',
        );
      }
    }
    return buffer.toString();
  }

  void _escribirCategorias(
    StringBuffer buffer,
    List<CategoriaMontoConsejo> categorias,
  ) {
    if (categorias.isEmpty) {
      buffer.writeln('- Ninguno');
      return;
    }
    for (final c in categorias) {
      buffer.writeln(
        '- ${c.categoriaNombre}: ${c.monto.toStringAsFixed(2)} '
        '${c.moneda.name.toUpperCase()}',
      );
    }
  }

  List<String> _parsearConsejos(String texto) {
    return texto
        .split('\n')
        .map((linea) => linea.trim())
        .map((linea) => linea.replaceFirst(RegExp(r'^[-*•\d]+[.\)]?\s*'), ''))
        .where((linea) => linea.isNotEmpty)
        .toList();
  }
}
