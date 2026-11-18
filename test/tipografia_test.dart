import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/presentation/shared/estilos.dart';
import 'package:finanzas_automaticas/presentation/shared/formatters.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Fase 80 — tipografía (Manrope empaquetada) y formato de montos.
void main() {
  test('formatearMonto mantiene el formato "S/ 4,820.50"', () {
    expect(formatearMonto(4820.5, Moneda.pen), 'S/ 4,820.50');
    expect(formatearMonto(1234567.891, Moneda.pen), 'S/ 1,234,567.89');
    expect(formatearMonto(0, Moneda.pen), 'S/ 0.00');
    expect(formatearMonto(99.9, Moneda.usd), r'US$ 99.90');
  });

  test('los dos temas usan Manrope', () {
    expect(appThemeClaro().textTheme.bodyMedium?.fontFamily, fuenteApp);
    expect(appThemeOscuro().textTheme.titleLarge?.fontFamily, fuenteApp);
    expect(fuenteApp, 'Manrope');
  });

  test(
    'Manrope 500/600/700/800 está empaquetada (no se descarga) con su licencia',
    () {
      final pubspec = File(
        'pubspec.yaml',
      ).readAsStringSync().replaceAll('\r\n', '\n');
      for (final (archivo, peso) in [
        ('Manrope-Medium.ttf', 500),
        ('Manrope-SemiBold.ttf', 600),
        ('Manrope-Bold.ttf', 700),
        ('Manrope-ExtraBold.ttf', 800),
      ]) {
        final ruta = 'assets/fonts/$archivo';
        final f = File(ruta);
        expect(f.existsSync(), isTrue, reason: 'falta $ruta');
        // Cabecera TrueType 0x00010000.
        expect(f.readAsBytesSync().sublist(0, 4), [0, 1, 0, 0], reason: ruta);
        expect(
          pubspec,
          contains('asset: $ruta\n          weight: $peso'),
          reason: '$ruta debe declararse con weight $peso en pubspec.yaml',
        );
      }
      expect(
        File('assets/fonts/OFL.txt').readAsStringSync(),
        contains('SIL Open Font License'),
      );
    },
  );

  test(
    'estiloMonto agrega cifras tabulares y conserva el resto del estilo',
    () {
      final base = const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
      final monto = estiloMonto(base);
      expect(monto.fontFeatures, [const FontFeature.tabularFigures()]);
      expect(monto.fontSize, 20);
      expect(monto.fontWeight, FontWeight.w700);
      expect(estiloMonto(null).fontFeatures, cifrasTabulares);
    },
  );
}
