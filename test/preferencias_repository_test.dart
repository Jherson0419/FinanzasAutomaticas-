import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_repository_shared_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'guarda y lee la API key de Gemini de forma independiente del nombre',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasRepositorySharedPrefs(prefs);

      expect(await repo.obtenerApiKeyGemini(), isNull);

      await repo.guardarNombre('Jherson');
      await repo.guardarApiKeyGemini('AIzaSyExampleKey123');

      expect(await repo.obtenerNombre(), 'Jherson');
      expect(await repo.obtenerApiKeyGemini(), 'AIzaSyExampleKey123');
    },
  );

  test('sobrescribir la API key reemplaza el valor anterior', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PreferenciasRepositorySharedPrefs(prefs);

    await repo.guardarApiKeyGemini('clave-vieja');
    await repo.guardarApiKeyGemini('clave-nueva');

    expect(await repo.obtenerApiKeyGemini(), 'clave-nueva');
  });

  group('Fase 65 — recordarSesion (B.2)', () {
    test('es true por defecto cuando nunca se guardó nada', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasRepositorySharedPrefs(prefs);

      expect(await repo.recordarSesion(), isTrue);
    });

    test('guarda y lee false', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasRepositorySharedPrefs(prefs);

      await repo.guardarRecordarSesion(false);

      expect(await repo.recordarSesion(), isFalse);
    });

    test('volver a guardar true revierte un false guardado antes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasRepositorySharedPrefs(prefs);

      await repo.guardarRecordarSesion(false);
      await repo.guardarRecordarSesion(true);

      expect(await repo.recordarSesion(), isTrue);
    });

    test('limpiarTodo borra la preferencia guardada (vuelve al default true)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasRepositorySharedPrefs(prefs);

      await repo.guardarRecordarSesion(false);
      await repo.limpiarTodo();

      expect(await repo.recordarSesion(), isTrue);
    });
  });
}
