import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/presentation/shared/app_bottom_bar.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

/// Pantalla mínima que reproduce cómo cada destino monta [AppBottomBar]
/// para probar la barra con un `Navigator` real, sin depender de las
/// pantallas completas ni de sus providers.
///
/// Fase 80: reescrita junto con la barra (5 botones Gasto·Deuda·Inicio·
/// Consejos·Perfil → 4 destinos Inicio·Movimientos·[+]·Deudas·Consejos).
/// Se conservan las mismas garantías que antes cubría esta prueba (orden,
/// navegación, no duplicar el dashboard, resaltado del activo, acciones que
/// nunca se resaltan, vidrio + RepaintBoundary) adaptadas al diseño nuevo.
Widget _pantalla(String titulo, AppBottomTab? tab) {
  return Scaffold(
    body: Center(child: Text(titulo)),
    bottomNavigationBar: AppBottomBar(actual: tab),
  );
}

Widget _appDePrueba({
  GlobalKey<NavigatorState>? navigatorKey,
  ThemeData? tema,
  double escalaTexto = 1.0,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    theme: tema ?? appThemeOscuro(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(escalaTexto)),
      child: child!,
    ),
    initialRoute: '/',
    routes: {
      '/': (_) => _pantalla('Pantalla: Inicio', AppBottomTab.inicio),
      '/transacciones/todas': (_) =>
          _pantalla('Pantalla: Movimientos', AppBottomTab.movimientos),
      '/deudas': (_) => _pantalla('Pantalla: Deudas', AppBottomTab.deudas),
      '/consejos': (_) =>
          _pantalla('Pantalla: Consejos', AppBottomTab.consejos),
      '/perfil': (_) => _pantalla('Pantalla: Perfil', null),
    },
    onGenerateRoute: (settings) {
      if (settings.name == '/deudas/nueva') {
        final direccion = settings.arguments as DireccionDeuda;
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Deuda nueva: ${direccion.name}')),
          ),
        );
      }
      if (settings.name == '/transferencias/nueva') {
        return MaterialPageRoute(
          builder: (_) =>
              Scaffold(appBar: AppBar(title: const Text('Transferencia nueva'))),
        );
      }
      if (settings.name == '/transacciones/nueva') {
        final tipo = settings.arguments as TipoTransaccion;
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('Transacción nueva: ${tipo.name}')),
          ),
        );
      }
      return null;
    },
  );
}

Finder _destino(String etiqueta) => find.bySemanticsLabel(etiqueta);

SemanticsData _semantica(WidgetTester tester, String etiqueta) =>
    tester.getSemantics(_destino(etiqueta)).getSemanticsData();

TextStyle? _estiloEtiqueta(WidgetTester tester, String etiqueta) {
  return tester.widget<Text>(find.text(etiqueta)).style;
}

void main() {
  group('AppBottomBar (Fase 80)', () {
    testWidgets('4 destinos con etiqueta + botón "+" en el orden '
        'Inicio·Movimientos·+·Deudas·Consejos', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      for (final etiqueta in ['Inicio', 'Movimientos', 'Deudas', 'Consejos']) {
        expect(_destino(etiqueta), findsOneWidget, reason: etiqueta);
        expect(_semantica(tester, etiqueta).flagsCollection.isButton, isTrue);
      }
      expect(_destino('Agregar'), findsOneWidget);
      expect(find.text('Perfil'), findsNothing);
      expect(find.text('Gasto'), findsNothing);

      final x = [
        'Inicio',
        'Movimientos',
        'Agregar',
        'Deudas',
        'Consejos',
      ].map((e) => tester.getCenter(_destino(e)).dx).toList();
      for (var i = 0; i < x.length - 1; i++) {
        expect(x[i], lessThan(x[i + 1]));
      }
      // El "+" queda en el centro exacto de la barra.
      expect(
        x[2],
        closeTo(tester.getSize(find.byType(MaterialApp)).width / 2, 1),
      );
      semantics.dispose();
    });

    testWidgets('el "+" abre una hoja con exactamente Gasto, Ingreso, '
        'Transferencia (Fase 85), Deuda y Me deben (Fase 82)', (tester) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      final opciones = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(ListTile),
      );
      expect(opciones, findsNWidgets(5));
      for (final t in [
        'Gasto',
        'Ingreso',
        'Transferencia',
        'Deuda',
        'Me deben',
      ]) {
        expect(
          find.descendant(of: opciones, matching: find.text(t)),
          findsOneWidget,
        );
      }
    });

    for (final (opcion, destino) in [
      ('Gasto', 'Transacción nueva: gasto'),
      ('Ingreso', 'Transacción nueva: ingreso'),
      ('Deuda', 'Deuda nueva: debo'),
      ('Me deben', 'Deuda nueva: meDeben'),
      ('Transferencia', 'Transferencia nueva'),
    ]) {
      testWidgets('"$opcion" de la hoja abre la pantalla existente', (
        tester,
      ) async {
        await tester.pumpWidget(_appDePrueba());
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();

        await tester.tap(find.text(opcion));
        await tester.pumpAndSettle();

        expect(find.text(destino), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
      });
    }

    testWidgets('Movimientos, Deudas y Consejos navegan a su destino', (
      tester,
    ) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      for (final (etiqueta, pantalla) in [
        ('Movimientos', 'Pantalla: Movimientos'),
        ('Deudas', 'Pantalla: Deudas'),
        ('Consejos', 'Pantalla: Consejos'),
      ]) {
        await tester.tap(_destino(etiqueta));
        await tester.pumpAndSettle();
        expect(find.text(pantalla), findsOneWidget);
      }
    });

    testWidgets('cambiar de destino no apila destinos y tocar Inicio vuelve al '
        'dashboard sin duplicarlo', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_appDePrueba(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      await tester.tap(_destino('Movimientos'));
      await tester.pumpAndSettle();
      await tester.tap(_destino('Deudas'));
      await tester.pumpAndSettle();
      await tester.tap(_destino('Consejos'));
      await tester.pumpAndSettle();

      // Solo el destino actual encima del Inicio.
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Pantalla: Inicio'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);

      await tester.tap(_destino('Deudas'));
      await tester.pumpAndSettle();
      await tester.tap(_destino('Inicio'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla: Inicio'), findsOneWidget);
      expect(navigatorKey.currentState!.canPop(), isFalse);
    });

    testWidgets('tocar el destino actual no hace nada', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_appDePrueba(navigatorKey: navigatorKey));
      await tester.pumpAndSettle();

      await tester.tap(_destino('Inicio'));
      await tester.pumpAndSettle();
      expect(navigatorKey.currentState!.canPop(), isFalse);
    });

    testWidgets('el destino activo se marca seleccionado (semántica, '
        'negrita y color de texto accesible); el "+" nunca', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      void verificarActivo(String activo) {
        for (final e in ['Inicio', 'Movimientos', 'Deudas', 'Consejos']) {
          final esActivo = e == activo;
          expect(
            _semantica(tester, e).flagsCollection.isSelected == Tristate.isTrue,
            esActivo,
            reason: '$e seleccionado',
          );
          expect(
            _estiloEtiqueta(tester, e)?.fontWeight,
            esActivo ? FontWeight.bold : FontWeight.normal,
          );
        }
        expect(
          _semantica(tester, 'Agregar').flagsCollection.isSelected ==
              Tristate.isTrue,
          isFalse,
        );
      }

      verificarActivo('Inicio');
      expect(_estiloEtiqueta(tester, 'Inicio')?.color, colorSuccess);

      await tester.tap(_destino('Deudas'));
      await tester.pumpAndSettle();
      verificarActivo('Deudas');

      await tester.tap(_destino('Movimientos'));
      await tester.pumpAndSettle();
      verificarActivo('Movimientos');
      semantics.dispose();
    });

    testWidgets('en tema claro el activo usa successText (≥ 4.5:1), no '
        'colorSuccess', (tester) async {
      await tester.pumpWidget(_appDePrueba(tema: appThemeClaro()));
      await tester.pumpAndSettle();
      expect(
        _estiloEtiqueta(tester, 'Inicio')?.color,
        AppColorTokens.claro.successText,
      );
    });

    testWidgets('objetivos táctiles de al menos 44 × 44 dp', (tester) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      for (final e in [
        'Inicio',
        'Movimientos',
        'Agregar',
        'Deudas',
        'Consejos',
      ]) {
        final size = tester.getSize(_destino(e));
        expect(size.width, greaterThanOrEqualTo(44), reason: '$e ancho');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$e alto');
      }
    });

    for (final ancho in [320.0, 390.0]) {
      testWidgets('textScale 1.3 sin overflow a ${ancho.toInt()} dp', (
        tester,
      ) async {
        tester.view.physicalSize = Size(ancho, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_appDePrueba(escalaTexto: 1.3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.byIcon(Icons.add_rounded));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('aplica el efecto de vidrio esmerilado acotado a la barra, con '
        'RepaintBoundary propio (rendimiento)', (tester) async {
      await tester.pumpWidget(_appDePrueba());
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsOneWidget);
      final filtro = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(filtro.filter, isA<ImageFilter>());

      expect(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });
}
