import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/cuenta.dart';
import '../../domain/plan_pago.dart';
import '../../domain/repositories/preferencias_plan_repository.dart';
import '../../infrastructure/persistence/preferencias_plan_repository_shared_prefs.dart';
import 'providers.dart';

/// Preferencias del plan de pago (Fase 83): presupuesto extra y estrategia
/// elegida, en `SharedPreferences`. Sin base de datos.
final preferenciasPlanRepositoryProvider = Provider<PreferenciasPlanRepository>(
  (ref) => PreferenciasPlanRepositorySharedPrefs(
    ref.watch(sharedPreferencesProvider),
  ),
);

class ConfigPlanPagoNotifier extends Notifier<ConfigPlanPago> {
  @override
  ConfigPlanPago build() =>
      ref.watch(preferenciasPlanRepositoryProvider).leer();

  Future<void> cambiarExtra(double extra) async {
    state = state.conExtra(extra);
    await ref.read(preferenciasPlanRepositoryProvider).guardar(state);
  }

  Future<void> cambiarEstrategia(EstrategiaPago? estrategia) async {
    state = state.conEstrategia(estrategia);
    await ref.read(preferenciasPlanRepositoryProvider).guardar(state);
  }
}

/// Configuración vigente del plan (se guarda al cambiarla).
final configPlanPagoProvider =
    NotifierProvider<ConfigPlanPagoNotifier, ConfigPlanPago>(
      ConfigPlanPagoNotifier.new,
    );

/// Fecha estimada en que quedo libre de deudas (moneda principal, con la
/// estrategia elegida o la recomendada y el extra guardado), para la
/// tarjeta del Inicio. `null` si no hay estimación posible (sin deudas,
/// a este ritmo no se termina, o los datos aún no cargan / fallan): en ese
/// caso el Inicio no muestra la parte del plan.
final fechaLibrePlanProvider = Provider<DateTime?>((ref) {
  try {
    final comparaciones = ref.watch(comparacionesPlanProvider).valueOrNull;
    if (comparaciones == null || comparaciones.isEmpty) return null;
    final principal = comparaciones.values.first;
    final elegida = ref.watch(configPlanPagoProvider).estrategia;
    final meses = principal
        .plan(elegida ?? principal.recomendacion.estrategia)
        .meses;
    return meses == null ? null : fechaDelMes(DateTime.now(), meses);
  } catch (_) {
    // Sin preferencias/datos disponibles (p. ej. pruebas sin
    // SharedPreferences): simplemente no hay estimación.
    return null;
  }
});

/// Planes por moneda con el extra elegido. SOLO cálculo: no modifica nada.
/// Se recalcula cuando cambian las deudas o el presupuesto extra.
final comparacionesPlanProvider =
    FutureProvider<Map<Moneda, ComparacionPlanes>>((ref) async {
      final deudas = await ref.watch(deudasProvider.future);
      final extra = ref.watch(
        configPlanPagoProvider.select((c) => c.extraMensual),
      );
      return compararPlanes(deudas, extraMensual: extra);
    });
