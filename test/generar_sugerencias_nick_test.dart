import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/generar_sugerencias_nick.dart';

final _formatoNickValido = RegExp(r'^[a-zA-Z0-9_]{3,20}$');

void main() {
  test('con un nombre vacío no genera ninguna sugerencia', () {
    expect(generarSugerenciasNick(''), isEmpty);
    expect(generarSugerenciasNick('   '), isEmpty);
  });

  test('genera 3 sugerencias a partir del nombre', () {
    final sugerencias = generarSugerenciasNick('Jherson', random: Random(1));
    expect(sugerencias, hasLength(3));
  });

  test('todas las sugerencias empiezan con el nombre en minúsculas', () {
    final sugerencias = generarSugerenciasNick('Jherson', random: Random(7));
    for (final sugerencia in sugerencias) {
      expect(sugerencia, startsWith('jherson'));
    }
  });

  test('todas las sugerencias cumplen el formato válido de nick', () {
    final sugerencias = generarSugerenciasNick('Jherson', random: Random(42));
    for (final sugerencia in sugerencias) {
      expect(
        _formatoNickValido.hasMatch(sugerencia),
        isTrue,
        reason: '"$sugerencia" no matchea el formato de nick',
      );
    }
  });

  test('usa solo la primera palabra de un nombre compuesto', () {
    final sugerencias = generarSugerenciasNick(
      'Jherson Vásquez',
      random: Random(3),
    );
    for (final sugerencia in sugerencias) {
      expect(sugerencia, startsWith('jherson'));
      expect(sugerencia, isNot(contains('vasquez')));
    }
  });

  test('quita tildes y eñes, y cualquier símbolo fuera de [a-z0-9_]', () {
    final sugerencias = generarSugerenciasNick('Ñoño!!', random: Random(5));
    for (final sugerencia in sugerencias) {
      expect(sugerencia, startsWith('nono'));
    }
  });

  test('con la misma semilla, el resultado es determinístico', () {
    final a = generarSugerenciasNick('Jherson', random: Random(99));
    final b = generarSugerenciasNick('Jherson', random: Random(99));
    expect(a, equals(b));
  });

  test('nunca supera los 20 caracteres (límite de formato de nick)', () {
    final sugerencias = generarSugerenciasNick(
      'Estanombreesdeliberadamentemuylargoparaprobarelrecorte',
      random: Random(11),
    );
    for (final sugerencia in sugerencias) {
      expect(sugerencia.length, lessThanOrEqualTo(20));
    }
  });
}
