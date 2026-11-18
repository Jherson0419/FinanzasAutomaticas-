import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/consejero.dart';
import '../../domain/entities/pago_deuda.dart';
import '../../domain/repositories/preferencias_consejero_repository.dart';
import '../../infrastructure/persistence/preferencias_consejero_repository_shared_prefs.dart';
import 'plan_pago_providers.dart';
import 'providers.dart';

/// Estado del consejero (Fase 86): consejos descartados o pospuestos, en
/// `SharedPreferences`. Sin base de datos.
final preferenciasConsejeroRepositoryProvider =
    Provider<PreferenciasConsejeroRepository>(
      (ref) => PreferenciasConsejeroRepositorySharedPrefs(
        ref.watch(sharedPreferencesProvider),
      ),
    );

class EstadosConsejeroNotifier extends Notifier<Map<String, EstadoConsejo>> {
  @override
  Map<String, EstadoConsejo> build() =>
      ref.watch(preferenciasConsejeroRepositoryProvider).leer();

  Future<void> _guardar(Consejo consejo, TipoEstadoConsejo tipo) async {
    final estado = EstadoConsejo(
      tipo: tipo,
      fecha: DateTime.now(),
      huella: consejo.huella,
    );
    state = {...state, consejo.id: estado};
    await ref
        .read(preferenciasConsejeroRepositoryProvider)
        .guardar(consejo.id, estado);
  }

  Future<void> descartar(Consejo consejo) =>
      _guardar(consejo, TipoEstadoConsejo.descartado);

  Future<void> posponer(Consejo consejo) =>
      _guardar(consejo, TipoEstadoConsejo.pospuesto);
}

final estadosConsejeroProvider =
    NotifierProvider<EstadosConsejeroNotifier, Map<String, EstadoConsejo>>(
      EstadosConsejeroNotifier.new,
    );

/// Pagos de todas las deudas (para la revisión semanal).
final pagosDeTodasLasDeudasProvider = FutureProvider<List<PagoDeuda>>((
  ref,
) async {
  final deudas = await ref.watch(deudasProvider.future);
  final repo = ref.watch(pagoDeudaRepositoryProvider);
  return [for (final d in deudas) ...await repo.obtenerPorDeuda(d.id)];
});

/// "Hoy" del consejero; las pruebas lo fijan.
final ahoraConsejeroProvider = Provider<DateTime>((ref) => DateTime.now());

/// Todo lo que miran las reglas, con datos locales.
final contextoConsejeroProvider = FutureProvider<ContextoConsejero>((
  ref,
) async {
  final config = ref.watch(configPlanPagoProvider);
  final deudas = await ref.watch(deudasProvider.future);
  final cuentas = await ref.watch(cuentasProvider.future);
  final transacciones = await ref.watch(todasLasTransaccionesProvider.future);
  final categorias = await ref.watch(categoriasProvider.future);
  final pagos = await ref.watch(pagosDeTodasLasDeudasProvider.future);
  return ContextoConsejero(
    ahora: ref.watch(ahoraConsejeroProvider),
    deudas: deudas,
    cuentas: cuentas,
    transacciones: transacciones,
    pagosDeuda: pagos,
    extraMensual: config.extraMensual,
    estrategia: config.estrategia,
    nombresCategoria: {for (final c in categorias) c.id: c.nombre},
  );
});

/// Consejos vigentes (todas las reglas, ordenados).
final consejosProvider = FutureProvider<List<Consejo>>((ref) async {
  return generarConsejos(await ref.watch(contextoConsejeroProvider.future));
});

/// Lo que se muestra: sin descartados/pospuestos, 3 + "Ver más".
final consejosVisiblesProvider = FutureProvider<ConsejosVisibles>((ref) async {
  final consejos = await ref.watch(consejosProvider.future);
  return consejosVisibles(
    consejos,
    ref.watch(estadosConsejeroProvider),
    ref.watch(ahoraConsejeroProvider),
  );
});
