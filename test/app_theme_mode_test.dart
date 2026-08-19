import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/presentation/app.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Pumpea la app completa con `temaProvider` fijo en [tema] y devuelve el
/// `MaterialApp` real, ya montado — verifica que el selector de "Mi perfil
/// → Apariencia" (`temaProvider`, Fase 31) efectivamente controla el
/// `ThemeMode` de `MaterialApp`, no solo el estado guardado.
/// `haySesionActivaProvider` en `false` es suficiente para que `RootScreen`
/// resuelva a `LoginScreen` sin necesitar Supabase real.
Future<MaterialApp> _pumpAppConTema(WidgetTester tester, TemaApp tema) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        temaProvider.overrideWithValue(tema),
        haySesionActivaProvider.overrideWithValue(false),
      ],
      child: const FinanzasAutomaticasApp(),
    ),
  );
  await tester.pump();
  return tester.widget<MaterialApp>(find.byType(MaterialApp));
}

void main() {
  testWidgets('TemaApp.claro produce ThemeMode.light', (
    WidgetTester tester,
  ) async {
    final app = await _pumpAppConTema(tester, TemaApp.claro);
    expect(app.themeMode, ThemeMode.light);
  });

  testWidgets('TemaApp.oscuro produce ThemeMode.dark', (
    WidgetTester tester,
  ) async {
    final app = await _pumpAppConTema(tester, TemaApp.oscuro);
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('TemaApp.sistema produce ThemeMode.system', (
    WidgetTester tester,
  ) async {
    final app = await _pumpAppConTema(tester, TemaApp.sistema);
    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('el tema claro y el oscuro tienen fondos de página distintos', (
    WidgetTester tester,
  ) async {
    final app = await _pumpAppConTema(tester, TemaApp.claro);
    expect(
      app.theme!.scaffoldBackgroundColor,
      isNot(app.darkTheme!.scaffoldBackgroundColor),
    );
    // El claro debe ser efectivamente más claro que el oscuro (luminancia
    // mayor), no solo "distinto".
    expect(
      app.theme!.scaffoldBackgroundColor.computeLuminance(),
      greaterThan(app.darkTheme!.scaffoldBackgroundColor.computeLuminance()),
    );
  });
}
