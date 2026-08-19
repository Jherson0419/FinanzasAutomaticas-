import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/config/supabase_config.dart';
import 'package:finanzas_automaticas/domain/repositories/automatizacion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/automatizacion_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAutomatizacionRepository implements AutomatizacionRepository {
  String token;
  int vecesRegenerado = 0;
  _FakeAutomatizacionRepository(this.token);

  @override
  Future<String> obtenerTokenWebhook() async => token;

  @override
  Future<String> regenerarTokenWebhook() async {
    vecesRegenerado++;
    token = 'token-nuevo-$vecesRegenerado';
    return token;
  }
}

Future<_FakeAutomatizacionRepository> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeAutomatizacionRepository('token-original');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [automatizacionRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: AutomatizacionScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  // `Clipboard.setData` (usado por el botón "Copiar") nunca resuelve
  // dentro de un `testWidgets` sin este mock — a diferencia de un `test()`
  // plano, el binding de test no responde sola la llamada al canal de
  // plataforma `SystemChannels.platform`.
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);

  testWidgets('muestra la URL del webhook con el token del usuario', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(
      find.text(
        '$supabaseUrl/functions/v1/capturar-transaccion?token=token-original',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el botón Copiar copia el enlace y muestra confirmación', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Copiar'));
    // Ni un `pump()` a secas (no alcanza a resolver el round-trip async de
    // `Clipboard.setData` antes de comprobar) ni `pumpAndSettle` de una
    // (dejaría avanzar también el auto-cierre del SnackBar) — unos pocos
    // pumps con duración acotada sí alcanzan para ambas cosas.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Enlace copiado'), findsOneWidget);
  });

  testWidgets(
    '"Generar nuevo enlace" pide confirmación y, al confirmar, regenera el '
    'token y actualiza la URL mostrada',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Generar nuevo enlace'),
      );
      await tester.pumpAndSettle();

      // Solo se abrió el diálogo de confirmación — todavía no se regeneró.
      expect(fake.vecesRegenerado, 0);
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Generar nuevo enlace'),
        ),
      );
      // Sin `pumpAndSettle` todavía — dejaría avanzar también el
      // auto-cierre del SnackBar antes de poder comprobar que apareció.
      await tester.pump();
      await tester.pump();

      expect(fake.vecesRegenerado, 1);
      expect(find.text('Enlace regenerado'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(
        find.text(
          '$supabaseUrl/functions/v1/capturar-transaccion?token=token-nuevo-1',
        ),
        findsOneWidget,
      );
    },
  );
}
