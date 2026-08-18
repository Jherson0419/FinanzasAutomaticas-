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

  test(
    'guarda y lee el hash del PIN, el bloqueo biométrico y si se omitió — todo independiente entre sí',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = PreferenciasRepositorySharedPrefs(prefs);

      expect(await repo.obtenerPinHash(), isNull);
      expect(await repo.obtenerBloqueoBiometricoActivo(), isFalse);
      expect(await repo.bloqueoOmitido(), isFalse);

      await repo.guardarPinHash('hash-de-prueba');
      await repo.guardarBloqueoBiometricoActivo(true);
      await repo.marcarBloqueoOmitido();

      expect(await repo.obtenerPinHash(), 'hash-de-prueba');
      expect(await repo.obtenerBloqueoBiometricoActivo(), isTrue);
      expect(await repo.bloqueoOmitido(), isTrue);
      // No se pisan entre sí ni con la API key/nombre.
      expect(await repo.obtenerApiKeyGemini(), isNull);
    },
  );
}
