import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_plan_repository.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_plan_repository_shared_prefs.dart';
import 'package:finanzas_automaticas/presentation/state/plan_pago_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

/// Fase 83 (D) — preferencias del plan en SharedPreferences.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('por defecto: extra 0 y estrategia recomendada (null)', () {
    final c = PreferenciasPlanRepositorySharedPrefs(prefs).leer();
    expect(c.extraMensual, 0);
    expect(c.estrategia, isNull);
  });

  test('guarda y vuelve a leer extra y estrategia', () async {
    final repo = PreferenciasPlanRepositorySharedPrefs(prefs);
    await repo.guardar(
      const ConfigPlanPago(
        extraMensual: 400,
        estrategia: EstrategiaPago.bolaDeNieve,
      ),
    );
    final c = PreferenciasPlanRepositorySharedPrefs(prefs).leer();
    expect(c.extraMensual, 400);
    expect(c.estrategia, EstrategiaPago.bolaDeNieve);

    await repo.guardar(const ConfigPlanPago(extraMensual: 100));
    expect(repo.leer().estrategia, isNull);
  });

  test('valores inválidos guardados a mano se ignoran', () async {
    await prefs.setDouble(PreferenciasPlanRepositorySharedPrefs.claveExtra, -5);
    await prefs.setString(
      PreferenciasPlanRepositorySharedPrefs.claveEstrategia,
      'base',
    );
    final c = PreferenciasPlanRepositorySharedPrefs(prefs).leer();
    expect(c.extraMensual, 0);
    expect(c.estrategia, isNull);
  });

  test('el notifier persiste los cambios', () async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await container.read(configPlanPagoProvider.notifier).cambiarExtra(200);
    await container
        .read(configPlanPagoProvider.notifier)
        .cambiarEstrategia(EstrategiaPago.avalancha);
    expect(container.read(configPlanPagoProvider).extraMensual, 200);

    final otra = PreferenciasPlanRepositorySharedPrefs(prefs).leer();
    expect(otra.extraMensual, 200);
    expect(otra.estrategia, EstrategiaPago.avalancha);
    // El esquema de datos no se toca: solo dos claves de preferencias.
    expect(prefs.getKeys(), {
      PreferenciasPlanRepositorySharedPrefs.claveExtra,
      PreferenciasPlanRepositorySharedPrefs.claveEstrategia,
    });
  });
}
