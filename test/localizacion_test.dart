import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/infrastructure/notificaciones_locales/notificaciones_locales_plugin.dart';
import 'package:finanzas_automaticas/presentation/localizacion.dart';
import 'package:finanzas_automaticas/presentation/shared/formatters.dart';

/// Fase 89 (C y D) — idioma del framework y ajustes del sistema.
void main() {
  setUpAll(inicializarIdioma);

  Widget app(Widget home) => MaterialApp(
    locale: localeApp,
    supportedLocales: localesSoportados,
    localizationsDelegates: delegadosDeLocalizacion,
    home: home,
  );

  testWidgets('el selector de fecha sale en español', (tester) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDatePicker(
                context: context,
                initialDate: DateTime(2026, 11, 17),
                firstDate: DateTime(2000),
                lastDate: DateTime(2030),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp('noviembre', caseSensitive: false)),
      findsWidgets,
    );
    expect(
      find.textContaining(RegExp('cancelar', caseSensitive: false)),
      findsOneWidget,
    );
    expect(find.textContaining('November'), findsNothing);
    expect(
      find.textContaining(RegExp('^cancel\$', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('el selector de hora y los textos del sistema en español', (
    tester,
  ) async {
    late MaterialLocalizations l10n;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            l10n = MaterialLocalizations.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(l10n.cancelButtonLabel.toLowerCase(), 'cancelar');
    expect(l10n.backButtonTooltip, 'Atrás');
    // 24 h en español (el selector de hora de Mi perfil › Notificaciones).
    expect(l10n.formatTimeOfDay(const TimeOfDay(hour: 19, minute: 0)), '19:00');
  });

  testWidgets('los montos y fechas de Finzo no cambian de formato', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Column(
            children: [
              Text(formatearMonto(1200, Moneda.pen)),
              Text(formatearFecha(DateTime(2026, 11, 7))),
              Text(formatearMesAnio(DateTime(2026, 11, 7))),
            ],
          ),
        ),
      ),
    );
    expect(find.text('S/ 1,200.00'), findsOneWidget);
    expect(find.text('07/11/2026'), findsOneWidget);
    expect(find.text(formatearMesAnio(DateTime(2026, 11, 7))), findsOneWidget);
  });

  test('ni siquiera con Intl.defaultLocale = es cambian los montos', () {
    final antes = (
      formatearMonto(1234567.891, Moneda.pen),
      formatearMonto(0.5, Moneda.usd),
      formatearMontoConSigno(18, Moneda.pen, positivo: false),
      formatearFecha(DateTime(2026, 1, 5)),
      formatearFechaLarga(DateTime(2026, 11, 16)),
    );
    final previo = Intl.defaultLocale;
    Intl.defaultLocale = 'es';
    try {
      expect((
        formatearMonto(1234567.891, Moneda.pen),
        formatearMonto(0.5, Moneda.usd),
        formatearMontoConSigno(18, Moneda.pen, positivo: false),
        formatearFecha(DateTime(2026, 1, 5)),
        formatearFechaLarga(DateTime(2026, 11, 16)),
      ), antes);
      expect(antes.$1, 'S/ 1,234,567.89');
      expect(antes.$2, r'US$ 0.50');
      expect(antes.$5, 'Lunes 16 de noviembre');
    } finally {
      Intl.defaultLocale = previo;
    }
  });

  group('Ajustes del sistema (sin permission_handler)', () {
    test('iOS: abre app-settings:', () async {
      Uri? abierta;
      final ok = await abrirAjustesDelSistema(
        plataforma: TargetPlatform.iOS,
        abrirUrl: (u) async {
          abierta = u;
          return true;
        },
      );
      expect(ok, isTrue);
      expect(abierta.toString(), 'app-settings:');
    });

    testWidgets('Android: canal finzo/ajustes', (tester) async {
      final llamadas = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        canalAjustesAndroid,
        (call) async {
          llamadas.add(call.method);
          return true;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          canalAjustesAndroid,
          null,
        ),
      );
      expect(
        await abrirAjustesDelSistema(plataforma: TargetPlatform.android),
        isTrue,
      );
      expect(llamadas, ['abrirAjustesNotificaciones']);
    });

    testWidgets('Android sin el canal nativo: false, sin excepción', (
      tester,
    ) async {
      // En tiempo real: sin handler, el mensaje se resuelve fuera del
      // reloj simulado de testWidgets (si no, la prueba se cuelga).
      final ok = await tester.runAsync(
        () => abrirAjustesDelSistema(
          plataforma: TargetPlatform.android,
          canal: const MethodChannel('finzo/no-existe'),
        ),
      );
      expect(ok, isFalse);
    });

    test('otras plataformas: false', () async {
      expect(
        await abrirAjustesDelSistema(plataforma: TargetPlatform.windows),
        isFalse,
      );
    });
  });
}
