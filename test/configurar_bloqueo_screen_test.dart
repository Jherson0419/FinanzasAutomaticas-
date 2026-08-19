import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/pin_hash.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/configurar_bloqueo_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakePreferenciasRepository implements PreferenciasRepository {
  String? pinHashGuardado;
  bool bloqueoBiometricoActivo = false;
  bool omitido = false;

  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<bool> onboardingCompletado() async => true;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
  @override
  Future<String?> obtenerPinHash() async => pinHashGuardado;
  @override
  Future<void> guardarPinHash(String hash) async => pinHashGuardado = hash;
  @override
  Future<bool> obtenerBloqueoBiometricoActivo() async =>
      bloqueoBiometricoActivo;
  @override
  Future<void> guardarBloqueoBiometricoActivo(bool activo) async =>
      bloqueoBiometricoActivo = activo;
  @override
  Future<bool> bloqueoOmitido() async => omitido;
  @override
  Future<void> marcarBloqueoOmitido() async => omitido = true;
  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<void> limpiarTodo() async {}
}

Future<_FakePreferenciasRepository> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakePreferenciasRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferenciasRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: ConfigurarBloqueoScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets(
    'guardar un PIN válido lo guarda hasheado, nunca en texto plano',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nuevo PIN'),
        '1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar PIN'),
        '1234',
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Guardar PIN'));
      await tester.pumpAndSettle();

      expect(fake.pinHashGuardado, isNotNull);
      expect(fake.pinHashGuardado, isNot(equals('1234')));
      expect(fake.pinHashGuardado, hashPin('1234'));
    },
  );

  testWidgets(
    'si el PIN y su confirmación no coinciden, "Guardar PIN" queda deshabilitado',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nuevo PIN'),
        '1234',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar PIN'),
        '4321',
      );
      await tester.pump();

      final boton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Guardar PIN'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets(
    'el botón Continuar está deshabilitado hasta configurar PIN o biométrico',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets('"Omitir por ahora" marca el bloqueo como omitido', (
    WidgetTester tester,
  ) async {
    final fake = await _pumpScreen(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Omitir por ahora'));
    await tester.pumpAndSettle();

    expect(fake.omitido, isTrue);
  });
}
