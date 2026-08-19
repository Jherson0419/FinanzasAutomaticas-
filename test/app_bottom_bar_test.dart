import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/presentation/shared/app_bottom_bar.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Pantalla mínima que reproduce cómo Dashboard/Consejos/Perfil montan
/// [AppBottomBar] (Fase 19) para poder probar la barra con un `Navigator`
/// real, sin depender de las pantallas completas ni de sus providers.
Widget _pantalla(String titulo, AppBottomTab? tab) {
  return Scaffold(
    body: Center(child: Text(titulo)),
    bottomNavigationBar: AppBottomBar(actual: tab),
  );
}

Widget _appDePrueba({GlobalKey<NavigatorState>? navigatorKey}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    theme: appThemeOscuro(),
    initialRoute: '/',
    routes: {
      '/': (_) => _pantalla('Pantalla: Dashboard', AppBottomTab.dashboard),
      '/consejos': (_) =>
          _pantalla('Pantalla: Consejos', AppBottomTab.consejos),
      '/perfil': (_) => _pantalla('Pantalla: Perfil', AppBottomTab.perfil),
      '/transacciones/nueva': (_) =>
          Scaffold(appBar: AppBar(title: const Text('Gasto nuevo'))),
      '/deudas/nueva': (_) =>
          Scaffold(appBar: AppBar(title: const Text('Deuda nueva'))),
    },
  );
}

AnimatedContainer _contenedorInicio(WidgetTester tester) {
  return tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.byIcon(Icons.home_rounded),
      matching: find.byType(AnimatedContainer),
    ),
  );
}

TextStyle? _estiloEtiqueta(WidgetTester tester, String etiqueta) {
  return tester.widget<Text>(find.text(etiqueta)).style;
}

void main() {
  group('AppBottomBar (Fase 32)', () {
    testWidgets('muestra los 5 botones en el orden Gasto·Deuda·Inicio·'
        'Consejos·Perfil', (tester) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      expect(find.text('Gasto'), findsOneWidget);
      expect(find.text('Deuda'), findsOneWidget);
      expect(find.text('Consejos'), findsOneWidget);
      expect(find.text('Perfil'), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);

      final xGasto = tester.getCenter(find.text('Gasto')).dx;
      final xDeuda = tester.getCenter(find.text('Deuda')).dx;
      final xInicio = tester.getCenter(find.byIcon(Icons.home_rounded)).dx;
      final xConsejos = tester.getCenter(find.text('Consejos')).dx;
      final xPerfil = tester.getCenter(find.text('Perfil')).dx;

      expect(xGasto, lessThan(xDeuda));
      expect(xDeuda, lessThan(xInicio));
      expect(xInicio, lessThan(xConsejos));
      expect(xConsejos, lessThan(xPerfil));
    });

    testWidgets('tocar Gasto navega a /transacciones/nueva', (tester) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gasto'));
      await tester.pumpAndSettle();

      expect(find.text('Gasto nuevo'), findsOneWidget);
    });

    testWidgets('tocar Deuda navega a /deudas/nueva', (tester) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deuda'));
      await tester.pumpAndSettle();

      expect(find.text('Deuda nueva'), findsOneWidget);
    });

    testWidgets(
      'tocar Inicio desde una pantalla distinta al dashboard vuelve a él '
      'sin apilar un dashboard duplicado',
      (tester) async {
        final navigatorKey = GlobalKey<NavigatorState>();
        await tester.pumpWidget(_appDePrueba(navigatorKey: navigatorKey));
        await tester.pumpAndSettle();

        // Dashboard -> Consejos -> Perfil: dos niveles de profundidad,
        // igual que si el usuario navegara cruzado entre pestañas.
        await tester.tap(find.text('Consejos'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Perfil'));
        await tester.pumpAndSettle();
        expect(navigatorKey.currentState!.canPop(), isTrue);

        await tester.tap(find.byIcon(Icons.home_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Pantalla: Dashboard'), findsOneWidget);
        // Sin rutas apiladas encima del dashboard: no hay ningún duplicado.
        expect(navigatorKey.currentState!.canPop(), isFalse);
      },
    );

    testWidgets('tocar Inicio ya estando en el dashboard no hace nada', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_appDePrueba(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.home_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Pantalla: Dashboard'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
    });

    testWidgets('el tab activo se resalta en las 5 posiciones', (
      tester,
    ) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      // 1) Dashboard: Inicio activo (anillo), Consejos/Perfil sin resaltar.
      expect(_contenedorInicio(tester).decoration, isA<BoxDecoration>());
      final decoInicioDashboard =
          _contenedorInicio(tester).decoration as BoxDecoration;
      expect(decoInicioDashboard.border, isNotNull);
      expect(
        _estiloEtiqueta(tester, 'Consejos')?.fontWeight,
        FontWeight.normal,
      );
      expect(
        _estiloEtiqueta(tester, 'Perfil')?.fontWeight,
        FontWeight.normal,
      );

      // 2) Consejos: se resalta Consejos, Inicio deja de estar activo.
      await tester.tap(find.text('Consejos'));
      await tester.pumpAndSettle();
      expect(_estiloEtiqueta(tester, 'Consejos')?.fontWeight, FontWeight.bold);
      expect(_estiloEtiqueta(tester, 'Consejos')?.color, colorSuccess);
      expect(
        _estiloEtiqueta(tester, 'Perfil')?.fontWeight,
        FontWeight.normal,
      );
      final decoInicioConsejos =
          _contenedorInicio(tester).decoration as BoxDecoration;
      expect(decoInicioConsejos.border, isNull);

      // 3) Perfil: se resalta Perfil, Consejos vuelve a plano.
      await tester.tap(find.text('Perfil'));
      await tester.pumpAndSettle();
      expect(_estiloEtiqueta(tester, 'Perfil')?.fontWeight, FontWeight.bold);
      expect(_estiloEtiqueta(tester, 'Perfil')?.color, colorSuccess);
      expect(
        _estiloEtiqueta(tester, 'Consejos')?.fontWeight,
        FontWeight.normal,
      );
      final decoInicioPerfil =
          _contenedorInicio(tester).decoration as BoxDecoration;
      expect(decoInicioPerfil.border, isNull);
    });

    testWidgets('Gasto y Deuda nunca se resaltan (son acciones, no destinos)', (
      tester,
    ) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      expect(_estiloEtiqueta(tester, 'Gasto')?.fontWeight, FontWeight.normal);
      expect(_estiloEtiqueta(tester, 'Deuda')?.fontWeight, FontWeight.normal);
    });

    testWidgets(
      'aplica el efecto de vidrio esmerilado acotado a la barra, con '
      'RepaintBoundary propio (rendimiento)',
      (tester) async {
        await tester.pumpWidget(_appDePrueba());
        await tester.pumpAndSettle();

        expect(find.byType(BackdropFilter), findsOneWidget);
        final filtro = tester.widget<BackdropFilter>(
          find.byType(BackdropFilter),
        );
        expect(filtro.filter, isA<ImageFilter>());

        expect(
          find.ancestor(
            of: find.byType(BackdropFilter),
            matching: find.byType(RepaintBoundary),
          ),
          findsWidgets,
        );
      },
    );
  });
}
