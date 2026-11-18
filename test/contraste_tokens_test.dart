import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 80 — contraste WCAG 2.x de los tokens de texto nuevos.
///
/// Si alguien cambia un token y rompe el contraste, esta prueba falla con
/// el par exacto, el ratio obtenido y el mínimo exigido.

double _canalLineal(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

/// Luminancia relativa (WCAG 2.x).
double luminancia(Color c) =>
    0.2126 * _canalLineal(c.r) +
    0.7152 * _canalLineal(c.g) +
    0.0722 * _canalLineal(c.b);

/// Compone [frente] (con alpha) sobre [fondo] opaco.
Color componer(Color frente, Color fondo) {
  final a = frente.a;
  return Color.from(
    alpha: 1,
    red: frente.r * a + fondo.r * (1 - a),
    green: frente.g * a + fondo.g * (1 - a),
    blue: frente.b * a + fondo.b * (1 - a),
  );
}

/// Ratio de contraste entre [texto] y [fondo]. Un fondo translúcido se
/// compone primero sobre [base] (la superficie real debajo del chip).
double contraste(Color texto, Color fondo, {Color? base}) {
  final fondoOpaco = fondo.a < 1 ? componer(fondo, base!) : fondo;
  final l1 = luminancia(texto);
  final l2 = luminancia(fondoOpaco);
  final claro = math.max(l1, l2);
  final oscuro = math.min(l1, l2);
  return (claro + 0.05) / (oscuro + 0.05);
}

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

void _exigir(
  String nombre,
  Color texto,
  Color fondo, {
  Color? base,
  double minimo = 4.5,
}) {
  final ratio = contraste(texto, fondo, base: base);
  expect(
    ratio,
    greaterThanOrEqualTo(minimo),
    reason:
        'Contraste insuficiente en "$nombre": texto ${_hex(texto)} sobre '
        'fondo ${_hex(fondo)}${base != null ? ' (sobre ${_hex(base)})' : ''} '
        'da ${ratio.toStringAsFixed(2)}:1, se exige ≥ $minimo:1 (WCAG AA). '
        'Revisa AppColorTokens en lib/presentation/theme/app_theme.dart.',
  );
}

void main() {
  group('función de contraste', () {
    test('negro sobre blanco es 21:1 y un color consigo mismo 1:1', () {
      expect(
        contraste(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        contraste(const Color(0xFF5DCAA5), const Color(0xFF5DCAA5)),
        closeTo(1, 0.001),
      );
    });

    test('detecta el problema original: #5DCAA5 como texto sobre claro', () {
      expect(
        contraste(colorSuccess, AppColorTokens.claro.bgCard),
        lessThan(4.5),
      );
    });
  });

  for (final (nombreTema, t) in [
    ('claro', AppColorTokens.claro),
    ('oscuro', AppColorTokens.oscuro),
  ]) {
    group('tema $nombreTema', () {
      final textos = {
        'successText': (t.successText, t.successBg),
        'dangerText': (t.dangerText, t.dangerBg),
        'warningText': (t.warningText, t.warningBg),
      };

      for (final MapEntry(key: nombre, value: (texto, fondoChip))
          in textos.entries) {
        test('$nombre ≥ 4.5:1 sobre bgPage, bgCard y su propio chip', () {
          _exigir('$nombreTema/$nombre sobre bgPage', texto, t.bgPage);
          _exigir('$nombreTema/$nombre sobre bgCard', texto, t.bgCard);
          // El chip puede estar sobre la página o sobre una tarjeta.
          _exigir(
            '$nombreTema/$nombre sobre su chip (en bgCard)',
            texto,
            fondoChip,
            base: t.bgCard,
          );
          _exigir(
            '$nombreTema/$nombre sobre su chip (en bgPage)',
            texto,
            fondoChip,
            base: t.bgPage,
          );
        });
      }

      test('heroText y heroMuted ≥ 4.5:1 sobre heroBg', () {
        _exigir('$nombreTema/heroText', t.heroText, t.heroBg);
        _exigir('$nombreTema/heroMuted', t.heroMuted, t.heroBg);
      });

      test('textPrimary y textSecondary ≥ 4.5:1 sobre bgPage y bgCard', () {
        _exigir('$nombreTema/textPrimary', t.textPrimary, t.bgPage);
        _exigir('$nombreTema/textPrimary', t.textPrimary, t.bgCard);
        _exigir('$nombreTema/textSecondary', t.textSecondary, t.bgPage);
        _exigir('$nombreTema/textSecondary', t.textSecondary, t.bgCard);
      });
    });
  }

  for (final (nombre, t) in [
    ('claro', AppColorTokens.claro),
    ('oscuro', AppColorTokens.oscuro),
  ]) {
    test('textMuted en $nombre ≥ 4.5:1 sobre bgPage y bgCard', () {
      _exigir('$nombre/textMuted sobre bgPage', t.textMuted, t.bgPage);
      _exigir('$nombre/textMuted sobre bgCard', t.textMuted, t.bgCard);
    });
  }

  for (final (nombre, t) in [
    ('claro', AppColorTokens.claro),
    ('oscuro', AppColorTokens.oscuro),
  ]) {
    test('paleta de gráficos ($nombre): 4 colores ≥ 3:1 contra bgCard', () {
      expect(t.grafico, hasLength(4));
      for (var i = 0; i < t.grafico.length; i++) {
        _exigir(
          '$nombre/grafico[$i] sobre bgCard',
          t.grafico[i],
          t.bgCard,
          minimo: 3,
        );
      }
    });
  }

  test('estados sobre la tarjeta héroe (siempre oscura) ≥ 4.5:1', () {
    const o = AppColorTokens.oscuro;
    for (final t in [AppColorTokens.claro, o]) {
      _exigir('héroe/success', o.successText, t.heroBg);
      _exigir('héroe/danger', o.dangerText, t.heroBg);
      _exigir(
        'héroe/success sobre su chip',
        o.successText,
        o.successBg,
        base: t.heroBg,
      );
      _exigir(
        'héroe/danger sobre su chip',
        o.dangerText,
        o.dangerBg,
        base: t.heroBg,
      );
    }
  });

  test('Fase 81: textMuted oscuro = #79857F (mínimo de su familia)', () {
    expect(AppColorTokens.oscuro.textMuted, const Color(0xFF79857F));
  });

  test('valores exactos pedidos en la Fase 80', () {
    const claro = AppColorTokens.claro;
    const oscuro = AppColorTokens.oscuro;
    expect(claro.successText, const Color(0xFF0B6B4F));
    expect(claro.dangerText, const Color(0xFFA32F2F));
    expect(claro.warningText, const Color(0xFF7A4E00));
    expect(claro.successBg, const Color(0xFFE3F4EC));
    expect(claro.dangerBg, const Color(0xFFFBE9E9));
    expect(claro.warningBg, const Color(0xFFFFF1D6));
    expect(claro.textMuted, const Color(0xFF5D6B64));
    expect(oscuro.successText, colorSuccess);
    expect(oscuro.dangerText, colorDanger);
    expect(oscuro.warningText, colorWarning);
    for (final t in [claro, oscuro]) {
      expect(t.heroBg, const Color(0xFF0D1210));
      expect(t.heroText, const Color(0xFFFFFFFF));
      expect(t.heroMuted, const Color(0xFFA9BBB2));
      expect(t.brandAction, const Color(0xFF5DCAA5));
    }
  });
}
