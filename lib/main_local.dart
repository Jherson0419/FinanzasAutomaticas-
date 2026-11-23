import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'infrastructure/persistence/local/amistad_repository_local.dart';
import 'infrastructure/persistence/local/auth_repository_local.dart';
import 'infrastructure/persistence/local/notificacion_repository_local.dart';
import 'infrastructure/persistence/local/perfil_repository_local.dart';
import 'infrastructure/persistence/local/servicios_nube_local.dart';
import 'presentation/app.dart';
import 'presentation/localizacion.dart';
import 'presentation/state/dashboard/dashboard_providers.dart';
import 'presentation/state/providers.dart';

/// Entry point del modo local (Fase 78) — solo para pruebas.
///
/// Corre la app completa SIN red, SIN login y SIN Firebase: no llama
/// `Supabase.initialize` ni `Firebase.initializeApp`. Los datos financieros
/// van a Drift y el perfil/notificaciones a `SharedPreferences` (claves
/// `modo_local.*`). Producción (`main.dart`) no cambia en nada.
///
/// Ejecutar con: flutter run -t lib/main_local.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fase 89: datos de fecha de `intl` en español (widgets del framework).
  await inicializarIdioma();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: overridesModoLocal(prefs),
      child: const FinanzasAutomaticasApp(),
    ),
  );
}

/// Público para poder montar exactamente el mismo árbol en pruebas.
List<Override> overridesModoLocal(SharedPreferences prefs) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  modoLocalProvider.overrideWithValue(true),

  // Datos financieros → Drift, aunque `datos_en_la_nube` esté en `true`
  // (p. ej. si la app de producción comparte almacenamiento).
  datosEnLaNubeProvider.overrideWithValue(false),
  // Sin nube no hay nada a qué migrar. Sin este override,
  // `necesitaMigracionProvider` mandaría a `MigrarDatosScreen` en cuanto
  // existan datos en Drift, o marcaría `datos_en_la_nube` en `true` si no
  // los hay.
  necesitaMigracionProvider.overrideWith((ref) async => false),

  // Sesión siempre activa — `haySesionActivaProvider` por defecto también
  // escucha `onAuthStateChange` de Supabase, por eso se fija directo.
  authRepositoryProvider.overrideWithValue(const AuthRepositoryLocal()),
  haySesionActivaProvider.overrideWithValue(true),
  eventoRecuperacionContrasenaProvider.overrideWith(
    (ref) => const Stream.empty(),
  ),

  perfilRepositoryProvider.overrideWith((ref) => PerfilRepositoryLocal(prefs)),
  amistadRepositoryProvider.overrideWithValue(const AmistadRepositoryLocal()),
  notificacionRepositoryProvider.overrideWith(
    (ref) => NotificacionRepositoryLocal(
      prefs,
      nombreDeuda: (id) async =>
          (await ref.read(deudaRepositoryProvider).obtenerPorId(id))
              ?.nombreDeuda,
    ),
  ),
  // El badge de la campana en producción sale de Supabase Realtime. Aquí
  // se recalcula cuando el dashboard termina de cargar (ahí se generan las
  // notificaciones de vencimiento) o cuando `NotificacionesScreen`
  // invalida `notificacionesProvider` al marcar una como leída.
  notificacionesNoLeidasProvider.overrideWith(_notificacionesNoLeidasLocal),

  automatizacionRepositoryProvider.overrideWithValue(
    const AutomatizacionRepositoryLocal(),
  ),
  tokenDispositivoRepositoryProvider.overrideWithValue(
    const TokenDispositivoRepositoryLocal(),
  ),
  pushNotificationRepositoryProvider.overrideWithValue(
    const PushNotificationRepositoryLocal(),
  ),
  chatConsejosRepositoryProvider.overrideWith(
    (ref) => ChatConsejosRepositoryLocal(),
  ),
];

Stream<List<Map<String, dynamic>>> _notificacionesNoLeidasLocal(
  Ref ref,
) async* {
  final resumen = ref.watch(resumenDashboardProvider.future);
  ref.watch(notificacionesProvider);
  final repo = ref.watch(notificacionRepositoryProvider);
  try {
    await resumen;
  } catch (_) {
    // Sin resumen igual se muestran las notificaciones que ya existían.
  }
  final todas = await repo.obtenerTodas();
  yield [
    for (final n in todas)
      if (!n.leida) {'id': n.id},
  ];
}
