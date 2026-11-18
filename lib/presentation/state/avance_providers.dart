import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/avance.dart';
import '../../domain/entities/pago_deuda.dart';
import '../../domain/hitos.dart';
import '../../domain/recordatorios.dart';
import '../../domain/repositories/notificaciones_locales_repository.dart';
import '../../domain/repositories/preferencias_hitos_repository.dart';
import '../../domain/repositories/preferencias_recordatorios_repository.dart';
import '../../domain/usecases/sincronizar_recordatorios.dart';
import '../../infrastructure/notificaciones_locales/notificaciones_locales_plugin.dart';
import '../../infrastructure/persistence/preferencias_hitos_repository_shared_prefs.dart';
import '../../infrastructure/persistence/preferencias_recordatorios_repository_shared_prefs.dart';
import 'consejero_providers.dart';
import 'providers.dart';

/// "Hoy" de avance, hitos y recordatorios; las pruebas lo fijan.
final ahoraAvanceProvider = Provider<DateTime>((ref) => DateTime.now());

/// Pagos agrupados por deuda (de [pagosDeTodasLasDeudasProvider]).
final pagosPorDeudaProvider = FutureProvider<Map<String, List<PagoDeuda>>>((
  ref,
) async {
  final pagos = await ref.watch(pagosDeTodasLasDeudasProvider.future);
  final mapa = <String, List<PagoDeuda>>{};
  for (final p in pagos) {
    mapa.putIfAbsent(p.deudaId, () => []).add(p);
  }
  return mapa;
});

/// "Mi avance" (Fase 87).
final avanceProvider = FutureProvider<Avance>((ref) async {
  return calcularAvance(
    deudas: await ref.watch(deudasProvider.future),
    pagosPorDeuda: await ref.watch(pagosPorDeudaProvider.future),
    cuentas: await ref.watch(cuentasProvider.future),
    ahora: ref.watch(ahoraAvanceProvider),
  );
});

// ---------------------------------------------------------------------
// Hitos
// ---------------------------------------------------------------------

final preferenciasHitosRepositoryProvider =
    Provider<PreferenciasHitosRepository>(
      (ref) => PreferenciasHitosRepositorySharedPrefs(
        ref.watch(sharedPreferencesProvider),
      ),
    );

class HitosNotifier extends Notifier<Map<Hito, HitoLogrado>> {
  /// Sin preferencias disponibles (p. ej. pruebas que no las configuran)
  /// no se guarda nada: sin preferencias tampoco se evalúa (ver
  /// [evaluar]), así no se "celebra" algo que no se pudo guardar.
  bool _disponible = true;

  @override
  Map<Hito, HitoLogrado> build() {
    try {
      _disponible = true;
      return ref.watch(preferenciasHitosRepositoryProvider).leer();
    } catch (_) {
      _disponible = false;
      return const {};
    }
  }

  /// Guarda los hitos nuevos (idempotente).
  Future<List<HitoLogrado>> evaluar(ContextoHitos contexto) async {
    if (!_disponible) return const [];
    final nuevos = hitosNuevos(contexto, state);
    if (nuevos.isEmpty) return nuevos;
    state = {...state, for (final h in nuevos) h.hito: h};
    await ref.read(preferenciasHitosRepositoryProvider).guardar(nuevos);
    return nuevos;
  }

  Future<void> marcarCelebrado(Hito hito) async {
    final h = state[hito];
    if (h == null || h.celebrado || !_disponible) return;
    final celebrado = h.comoCelebrado();
    state = {...state, hito: celebrado};
    await ref.read(preferenciasHitosRepositoryProvider).guardar([celebrado]);
  }
}

final hitosProvider = NotifierProvider<HitosNotifier, Map<Hito, HitoLogrado>>(
  HitosNotifier.new,
);

/// Evalúa los hitos con los datos actuales. Se recalcula cuando cambian
/// deudas, pagos, cuentas o movimientos — es decir, al abrir la app y tras
/// registrar un pago, abono o transferencia (esas pantallas invalidan esos
/// providers).
final evaluacionHitosProvider = FutureProvider<void>((ref) async {
  final contexto = ContextoHitos(
    ahora: ref.watch(ahoraAvanceProvider),
    deudas: await ref.watch(deudasProvider.future),
    pagosPorDeuda: await ref.watch(pagosPorDeudaProvider.future),
    cuentas: await ref.watch(cuentasProvider.future),
    transacciones: await ref.watch(todasLasTransaccionesProvider.future),
  );
  await ref.read(hitosProvider.notifier).evaluar(contexto);
});

// ---------------------------------------------------------------------
// Recordatorios
// ---------------------------------------------------------------------

final preferenciasRecordatoriosRepositoryProvider =
    Provider<PreferenciasRecordatoriosRepository>(
      (ref) => PreferenciasRecordatoriosRepositorySharedPrefs(
        ref.watch(sharedPreferencesProvider),
      ),
    );

/// Adaptador del plugin; se inicializa solo al primer uso (sin tocar
/// `main`). Las pruebas lo reemplazan por un fake.
final notificacionesLocalesRepositoryProvider =
    Provider<NotificacionesLocalesRepository>(
      (ref) => NotificacionesLocalesPlugin(),
    );

class ConfigRecordatoriosNotifier extends Notifier<ConfigRecordatorios> {
  @override
  ConfigRecordatorios build() {
    try {
      return ref.watch(preferenciasRecordatoriosRepositoryProvider).leer();
    } catch (_) {
      // Sin preferencias disponibles: todo apagado (el valor por defecto).
      return const ConfigRecordatorios();
    }
  }

  Future<void> guardar(ConfigRecordatorios config) async {
    state = config;
    await ref.read(preferenciasRecordatoriosRepositoryProvider).guardar(config);
  }
}

final configRecordatoriosProvider =
    NotifierProvider<ConfigRecordatoriosNotifier, ConfigRecordatorios>(
      ConfigRecordatoriosNotifier.new,
    );

/// Deja programados los recordatorios que corresponden (Fase 87). Corre al
/// abrir la app (lo observa el Inicio) y cada vez que cambian las deudas,
/// las cuentas o la configuración. Con TODO apagado no toca el sistema
/// (al apagar desde Mi perfil, la sección cancela explícitamente).
final sincronizacionRecordatoriosProvider =
    FutureProvider<ResultadoSincronizacion?>((ref) async {
      final config = ref.watch(configRecordatoriosProvider);
      if (!config.algoActivo) return null;
      return SincronizarRecordatorios(
        ref.watch(notificacionesLocalesRepositoryProvider),
      )(
        deudas: await ref.watch(deudasProvider.future),
        cuentas: await ref.watch(cuentasProvider.future),
        ahora: ref.watch(ahoraAvanceProvider),
        config: config,
      );
    });
