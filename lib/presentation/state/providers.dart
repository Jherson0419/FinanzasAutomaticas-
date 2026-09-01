import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/amistad.dart';
import '../../domain/entities/categoria.dart';
import '../../domain/entities/cuenta.dart';
import '../../domain/entities/deuda.dart';
import '../../domain/entities/mensaje_consejo.dart';
import '../../domain/entities/mensaje_push.dart';
import '../../domain/entities/notificacion.dart';
import '../../domain/entities/pago_deuda.dart';
import '../../domain/entities/perfil.dart';
import '../../domain/entities/tema_app.dart';
import '../../domain/entities/transaccion.dart';
import '../../domain/repositories/amistad_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/automatizacion_repository.dart';
import '../../domain/repositories/categoria_repository.dart';
import '../../domain/repositories/chat_consejos_repository.dart';
import '../../domain/repositories/cuenta_repository.dart';
import '../../domain/repositories/deuda_repository.dart';
import '../../domain/repositories/notificacion_repository.dart';
import '../../domain/repositories/pago_deuda_repository.dart';
import '../../domain/repositories/perfil_repository.dart';
import '../../domain/repositories/preferencias_repository.dart';
import '../../domain/repositories/push_notification_repository.dart';
import '../../domain/repositories/token_dispositivo_repository.dart';
import '../../domain/repositories/transaccion_repository.dart';
import '../../domain/usecases/actualizar_estado_mora.dart';
import '../../domain/usecases/ajustar_saldo_cuenta.dart';
import '../../domain/usecases/armar_resumen_para_consejos.dart';
import '../../domain/usecases/crear_categoria.dart';
import '../../domain/usecases/editar_categoria.dart';
import '../../domain/usecases/editar_cuenta.dart';
import '../../domain/usecases/editar_deuda.dart';
import '../../domain/usecases/editar_transaccion.dart';
import '../../domain/usecases/eliminar_categoria.dart';
import '../../domain/usecases/eliminar_cuenta.dart';
import '../../domain/usecases/eliminar_cuenta_de_usuario.dart';
import '../../domain/usecases/eliminar_deuda.dart';
import '../../domain/usecases/eliminar_token_dispositivo_actual.dart';
import '../../domain/usecases/eliminar_transaccion.dart';
import '../../domain/usecases/generar_notificaciones_vencimiento.dart';
import '../../domain/usecases/migrar_datos_a_la_nube.dart';
import '../../domain/usecases/obtener_alertas_tarjetas_credito.dart';
import '../../domain/usecases/obtener_resumen_dashboard.dart';
import '../../domain/usecases/registrar_cuenta.dart';
import '../../domain/usecases/registrar_deuda.dart';
import '../../domain/usecases/registrar_gasto.dart';
import '../../domain/usecases/registrar_ingreso.dart';
import '../../domain/usecases/registrar_pago_deuda.dart';
import '../../domain/usecases/registrar_token_dispositivo.dart';
import '../../infrastructure/auth/supabase_auth_repository.dart';
import '../../infrastructure/consejos/edge_function_consejos_repository.dart';
import '../../infrastructure/notificaciones_push/firebase_push_notification_repository.dart';
import '../../infrastructure/persistence/drift/app_database.dart';
import '../../infrastructure/persistence/drift/categoria_repository_drift.dart';
import '../../infrastructure/persistence/drift/cuenta_repository_drift.dart';
import '../../infrastructure/persistence/drift/deuda_repository_drift.dart';
import '../../infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import '../../infrastructure/persistence/drift/transaccion_repository_drift.dart';
import '../../infrastructure/persistence/preferencias_repository_shared_prefs.dart';
import '../../infrastructure/persistence/supabase/amistad_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/automatizacion_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/categoria_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/cuenta_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/deuda_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/notificacion_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/pago_deuda_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/perfil_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/token_dispositivo_repository_supabase.dart';
import '../../infrastructure/persistence/supabase/transaccion_repository_supabase.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Lectura síncrona de la misma preferencia que expone
/// `PreferenciasRepository.datosEnLaNube()` (Fase 21). Necesaria porque los
/// providers de repositorios de datos financieros de abajo son `Provider`
/// (síncronos) y no pueden esperar un `Future` para decidir a qué adapter
/// resolver. `shared_preferences` ya está cargado en memoria de forma
/// síncrona para cuando se arma el árbol de providers (ver
/// `sharedPreferencesProvider`), así que esto nunca hace I/O real.
///
/// Se invalida explícitamente (`ref.invalidate`) justo después de marcar la
/// migración como completada (`MigrarDatosScreen`) o de saltarla por no
/// haber datos locales que migrar (`RootScreen`), para que los providers de
/// abajo recalculen y empiecen a resolver a Supabase en el resto de la
/// sesión.
final datosEnLaNubeProvider = Provider<bool>((ref) {
  return ref
          .watch(sharedPreferencesProvider)
          .getBool(PreferenciasRepositorySharedPrefs.claveDatosEnLaNube) ??
      false;
});

/// Tema de la app (Fase 31) — lectura síncrona por el mismo motivo que
/// `datosEnLaNubeProvider`: `MaterialApp.themeMode` no puede esperar un
/// `Future`. Se invalida manualmente tras guardar una preferencia nueva
/// desde "Mi perfil → Apariencia".
final temaProvider = Provider<TemaApp>((ref) {
  final valor = ref
      .watch(sharedPreferencesProvider)
      .getString(PreferenciasRepositorySharedPrefs.claveTema);
  if (valor == null) return TemaApp.oscuro;
  return TemaApp.values.byName(valor);
});

/// Los 5 providers de repositorios de datos financieros bifurcan aquí
/// (Fase 21): mientras `datosEnLaNubeProvider` sea `false`, Drift (para
/// poder leer lo que se va a migrar); en cuanto sea `true`, Supabase, para
/// siempre. `PreferenciasRepository` en sí (más abajo) nunca bifurca —
/// siempre es local.
final cuentaRepositoryProvider = Provider<CuentaRepository>((ref) {
  return ref.watch(datosEnLaNubeProvider)
      ? CuentaRepositorySupabase(Supabase.instance.client)
      : CuentaRepositoryDrift(ref.watch(appDatabaseProvider));
});

final categoriaRepositoryProvider = Provider<CategoriaRepository>((ref) {
  return ref.watch(datosEnLaNubeProvider)
      ? CategoriaRepositorySupabase(Supabase.instance.client)
      : CategoriaRepositoryDrift(ref.watch(appDatabaseProvider));
});

final transaccionRepositoryProvider = Provider<TransaccionRepository>((ref) {
  return ref.watch(datosEnLaNubeProvider)
      ? TransaccionRepositorySupabase(Supabase.instance.client)
      : TransaccionRepositoryDrift(ref.watch(appDatabaseProvider));
});

final deudaRepositoryProvider = Provider<DeudaRepository>((ref) {
  return ref.watch(datosEnLaNubeProvider)
      ? DeudaRepositorySupabase(Supabase.instance.client)
      : DeudaRepositoryDrift(ref.watch(appDatabaseProvider));
});

final pagoDeudaRepositoryProvider = Provider<PagoDeudaRepository>((ref) {
  return ref.watch(datosEnLaNubeProvider)
      ? PagoDeudaRepositorySupabase(Supabase.instance.client)
      : PagoDeudaRepositoryDrift(ref.watch(appDatabaseProvider));
});

/// Se sobreescribe en `main()` (y en `main_dev.dart`/tests) con la instancia
/// ya resuelta de `SharedPreferences.getInstance()` — no depende de Drift.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobreescribirse antes de usarse',
  );
});

final preferenciasRepositoryProvider = Provider<PreferenciasRepository>((ref) {
  return PreferenciasRepositorySharedPrefs(
    ref.watch(sharedPreferencesProvider),
  );
});

/// Migración de datos financieros a Supabase (Fase 21) — a diferencia de
/// los casos de uso de arriba, este siempre construye explícitamente el
/// lado Drift (origen) y el lado Supabase (destino) directo, sin pasar por
/// los providers bifurcados: mientras la migración corre,
/// `datosEnLaNubeProvider` todavía es `false`, así que
/// `cuentaRepositoryProvider` (y compañía) siguen apuntando a Drift en
/// ambos lados si se usaran por error.
final migrarDatosALaNubeProvider = Provider<MigrarDatosALaNube>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final client = Supabase.instance.client;
  return MigrarDatosALaNube(
    cuentaRepositoryLocal: CuentaRepositoryDrift(db),
    categoriaRepositoryLocal: CategoriaRepositoryDrift(db),
    deudaRepositoryLocal: DeudaRepositoryDrift(db),
    transaccionRepositoryLocal: TransaccionRepositoryDrift(db),
    pagoDeudaRepositoryLocal: PagoDeudaRepositoryDrift(db),
    cuentaRepositoryNube: CuentaRepositorySupabase(client),
    categoriaRepositoryNube: CategoriaRepositorySupabase(client),
    deudaRepositoryNube: DeudaRepositorySupabase(client),
    transaccionRepositoryNube: TransaccionRepositorySupabase(client),
    pagoDeudaRepositoryNube: PagoDeudaRepositorySupabase(client),
  );
});

/// Puerta de `RootScreen` (Fase 21.3/21.4): decide si hace falta mostrar
/// `MigrarDatosScreen`. `false` de entrada (ya migrado) resuelve sin tocar
/// Drift. Si nunca se migró pero tampoco hay ningún dato financiero local
/// (cuenta creada de cero, nunca usó la app en modo local), se marca
/// `datosEnLaNube` como completada sin subir nada y sin mostrar la
/// pantalla — el onboarding que sigue ya escribe directo en Supabase.
final necesitaMigracionProvider = FutureProvider<bool>((ref) async {
  final preferencias = ref.watch(preferenciasRepositoryProvider);
  if (await preferencias.datosEnLaNube()) return false;

  final db = ref.watch(appDatabaseProvider);
  final hayCuentas = (await CuentaRepositoryDrift(
    db,
  ).obtenerTodas()).isNotEmpty;
  final hayDeudas =
      hayCuentas || (await DeudaRepositoryDrift(db).obtenerTodas()).isNotEmpty;
  final hayTransacciones =
      hayDeudas ||
      (await TransaccionRepositoryDrift(db).obtenerTodas()).isNotEmpty;

  if (hayTransacciones) return true;

  await preferencias.marcarDatosEnLaNube();
  ref.invalidate(datosEnLaNubeProvider);
  return false;
});

/// Fase 25.5: escucha `transacciones` en tiempo real (Supabase Realtime)
/// para que las capturas de la Edge Function `capturar-transaccion`
/// (Atajo de iOS, correo) aparezcan en el dashboard sin que el usuario
/// tenga que salir y volver a entrar. Solo se activa cuando los datos ya
/// viven en la nube — mientras estén en Drift no hay tabla remota que
/// escuchar. Deliberadamente NO reconstruye el resumen él mismo: emite el
/// payload crudo de cada evento, y es `DashboardScreen` quien lo escucha
/// con `ref.listen` para invalidar `resumenDashboardProvider` — así sigue
/// habiendo un solo lugar (`ObtenerResumenDashboard`) que sabe armarlo, y
/// este provider es fácil de sobreescribir en tests con un stream falso.
final transaccionesEnVivoProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  if (!ref.watch(datosEnLaNubeProvider)) return const Stream.empty();
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();
  return Supabase.instance.client
      .from('transacciones')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId);
});

final obtenerResumenDashboardProvider = Provider<ObtenerResumenDashboard>((
  ref,
) {
  return ObtenerResumenDashboard(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final registrarGastoProvider = Provider<RegistrarGasto>((ref) {
  return RegistrarGasto(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final registrarIngresoProvider = Provider<RegistrarIngreso>((ref) {
  return RegistrarIngreso(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final registrarCuentaProvider = Provider<RegistrarCuenta>((ref) {
  return RegistrarCuenta(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final registrarDeudaProvider = Provider<RegistrarDeuda>((ref) {
  return RegistrarDeuda(deudaRepository: ref.watch(deudaRepositoryProvider));
});

final registrarPagoDeudaProvider = Provider<RegistrarPagoDeuda>((ref) {
  return RegistrarPagoDeuda(
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    amistadRepository: ref.watch(amistadRepositoryProvider),
  );
});

/// Recalcula `enMora` de las deudas activas; se invoca automáticamente al
/// cargar el dashboard (ver `resumenDashboardProvider`).
final actualizarEstadoMoraProvider = Provider<ActualizarEstadoMora>((ref) {
  return ActualizarEstadoMora(
    deudaRepository: ref.watch(deudaRepositoryProvider),
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
  );
});

/// Alertas de corte/pago de tarjetas de crédito (Fase 29); se invoca
/// automáticamente al cargar el dashboard (ver
/// `alertasTarjetasCreditoProvider` en `dashboard_providers.dart`).
final obtenerAlertasTarjetasCreditoProvider =
    Provider<ObtenerAlertasTarjetasCredito>((ref) {
      return ObtenerAlertasTarjetasCredito(
        cuentaRepository: ref.watch(cuentaRepositoryProvider),
      );
    });

final editarTransaccionProvider = Provider<EditarTransaccion>((ref) {
  return EditarTransaccion(
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final eliminarTransaccionProvider = Provider<EliminarTransaccion>((ref) {
  return EliminarTransaccion(
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final editarDeudaProvider = Provider<EditarDeuda>((ref) {
  return EditarDeuda(
    deudaRepository: ref.watch(deudaRepositoryProvider),
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
  );
});

final eliminarDeudaProvider = Provider<EliminarDeuda>((ref) {
  return EliminarDeuda(
    deudaRepository: ref.watch(deudaRepositoryProvider),
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
  );
});

final editarCuentaProvider = Provider<EditarCuenta>((ref) {
  return EditarCuenta(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final eliminarCuentaProvider = Provider<EliminarCuenta>((ref) {
  return EliminarCuenta(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

final crearCategoriaProvider = Provider<CrearCategoria>((ref) {
  return CrearCategoria(
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
  );
});

final editarCategoriaProvider = Provider<EditarCategoria>((ref) {
  return EditarCategoria(
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
  );
});

final eliminarCategoriaProvider = Provider<EliminarCategoria>((ref) {
  return EliminarCategoria(
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
  );
});

final ajustarSaldoCuentaProvider = Provider<AjustarSaldoCuenta>((ref) {
  return AjustarSaldoCuenta(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
  );
});

/// Fase 24: la API key de Gemini ya no la pone cada usuario — es del
/// distribuidor de la app y vive solo como secreto de la Edge Function
/// `generar-consejos`. `GeminiConsejosRepository` (Fase 17, modelo de key
/// personal, puerto `ConsejosFinancierosRepository` de un solo turno)
/// sigue en el repo por si se quiere volver a ese modelo más adelante,
/// pero queda desconectado de aquí.
///
/// Fase 30: Consejos pasó de "un botón que genera una lista una vez" a un
/// chat persistente — `EdgeFunctionConsejosRepository` ahora implementa
/// `ChatConsejosRepository` en vez del puerto de un solo turno.
final chatConsejosRepositoryProvider = Provider<ChatConsejosRepository>((ref) {
  return EdgeFunctionConsejosRepository(Supabase.instance.client);
});

/// Arma el `ResumenParaConsejos` (agregado y anonimizado) usado como primer
/// mensaje del chat cuando el usuario no tiene historial todavía.
final armarResumenParaConsejosProvider = Provider<ArmarResumenParaConsejos>((
  ref,
) {
  return ArmarResumenParaConsejos(
    deudaRepository: ref.watch(deudaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
  );
});

/// Historial del chat de consejos del usuario actual — lectura simple
/// contra `mensajes_consejos`, mismo patrón que `cuentasProvider`/
/// `categoriasProvider`.
final historialConsejosProvider = FutureProvider<List<MensajeConsejo>>((ref) {
  return ref.watch(chatConsejosRepositoryProvider).obtenerHistorial();
});

/// Catálogos usados por los formularios de registro (cuentas y categorías).
final cuentasProvider = FutureProvider<List<Cuenta>>((ref) {
  return ref.watch(cuentaRepositoryProvider).obtenerTodas();
});

final categoriasProvider = FutureProvider<List<Categoria>>((ref) {
  return ref.watch(categoriaRepositoryProvider).obtenerTodas();
});

/// Deuda puntual usada por la pantalla de registrar pago de deuda y por
/// `DeudaFormulario` en modo edición.
final deudaPorIdProvider = FutureProvider.family<Deuda?, String>((ref, id) {
  return ref.watch(deudaRepositoryProvider).obtenerPorId(id);
});

/// Cuenta puntual usada por `CuentaFormulario` en modo edición.
final cuentaPorIdProvider = FutureProvider.family<Cuenta?, String>((ref, id) {
  return ref.watch(cuentaRepositoryProvider).obtenerPorId(id);
});

/// Categoría puntual usada por `CategoriaFormulario` en modo edición.
final categoriaPorIdProvider = FutureProvider.family<Categoria?, String>((
  ref,
  id,
) {
  return ref.watch(categoriaRepositoryProvider).obtenerPorId(id);
});

/// Transacción puntual usada por `TransaccionNuevaScreen` en modo edición.
final transaccionPorIdProvider = FutureProvider.family<Transaccion?, String>((
  ref,
  id,
) {
  return ref.watch(transaccionRepositoryProvider).obtenerPorId(id);
});

/// Todas las deudas registradas (paso de deudas y resumen del onboarding).
final deudasProvider = FutureProvider<List<Deuda>>((ref) {
  return ref.watch(deudaRepositoryProvider).obtenerTodas();
});

/// Pagos registrados de una deuda puntual, usados por la pantalla de
/// historial de pagos. Lectura simple sin lógica de negocio — va directo
/// al repositorio, igual que `cuentasProvider`/`categoriasProvider`.
final pagosPorDeudaProvider = FutureProvider.family<List<PagoDeuda>, String>((
  ref,
  deudaId,
) {
  return ref.watch(pagoDeudaRepositoryProvider).obtenerPorDeuda(deudaId);
});

/// Transacciones de una cuenta puntual, usadas por
/// `movimientos_cuenta_screen.dart` y para decidir si la moneda de una
/// cuenta puede seguir editándose. Lectura simple sin lógica de negocio.
final transaccionesPorCuentaProvider =
    FutureProvider.family<List<Transaccion>, String>((ref, cuentaId) {
      return ref
          .watch(transaccionRepositoryProvider)
          .obtenerPorCuenta(cuentaId);
    });

/// Transacciones de una categoría puntual — junto con `categoriaPorIdProvider`,
/// determina si `CategoriaFormulario` puede seguir dejando cambiar el tipo.
final transaccionesPorCategoriaProvider =
    FutureProvider.family<List<Transaccion>, String>((ref, categoriaId) {
      return ref
          .watch(transaccionRepositoryProvider)
          .obtenerPorCategoria(categoriaId);
    });

/// Pagos de deuda hechos desde una cuenta puntual — junto con
/// `transaccionesPorCuentaProvider`, determina si ya tiene movimientos
/// registrados (y por lo tanto si su moneda ya no puede cambiarse).
final pagosPorCuentaProvider = FutureProvider.family<List<PagoDeuda>, String>((
  ref,
  cuentaId,
) {
  return ref.watch(pagoDeudaRepositoryProvider).obtenerPorCuenta(cuentaId);
});

/// Todas las transacciones registradas, usadas por
/// `todos_los_movimientos_screen.dart`. Lectura simple sin lógica de
/// negocio, igual que `cuentasProvider`/`categoriasProvider`.
final todasLasTransaccionesProvider = FutureProvider<List<Transaccion>>((ref) {
  return ref.watch(transaccionRepositoryProvider).obtenerTodas();
});

/// Autenticación (Fase 18) — separada de los datos financieros, que siguen
/// siendo 100% locales. `SupabaseAuthRepository` es el único punto donde se
/// toca `Supabase.instance`; el resto de la app depende de `AuthRepository`.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(Supabase.instance.client);
});

/// Emite cada vez que cambia el estado de auth de Supabase — login,
/// logout, sesión restaurada al abrir la app, o (Fase 54) una sesión que
/// aparece sola cuando el usuario confirma su correo desde el deep link
/// `finzo://login-callback` y `supabase_flutter` la resuelve en segundo
/// plano (ver `SupabaseAuth._handleDeeplink` en el paquete). Ese último
/// caso puede ocurrir con la app ya abierta en `LoginScreen`, sin que
/// ninguna pantalla llame `ref.invalidate` — de ahí la necesidad de un
/// provider reactivo en vez de depender solo de invalidación manual.
final _authStateChangeProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// `true` si hay una sesión de Supabase activa. Sigue invalidándose
/// manualmente tras iniciar sesión/crear cuenta/cerrar sesión (mismo
/// patrón que el resto de la app), pero además se recalcula solo ante
/// cualquier evento de `_authStateChangeProvider` — así cubre el caso de
/// la Fase 54 sin que cada pantalla tenga que saber del deep link.
final haySesionActivaProvider = Provider<bool>((ref) {
  ref.watch(_authStateChangeProvider);
  return ref.watch(authRepositoryProvider).haySesionActiva;
});

/// Fase 65 — emite cuando `supabase_flutter` arma sola una sesión de
/// recuperación a partir del deep link `finzo://reset-password`
/// (`AuthChangeEvent.passwordRecovery`, ver `config/supabase_config.dart`).
/// `FinanzasAutomaticasApp` lo escucha con `ref.listen` para navegar a
/// `NuevaContrasenaScreen`. Envuelto en `try/catch`: sin `Supabase.
/// initialize()` real (tests de widgets que montan `FinanzasAutomaticasApp`
/// completa, como `app_theme_mode_test.dart`), `Supabase.instance` lanza un
/// `AssertionError` síncrono al leerlo — se degrada a un stream vacío en
/// vez de tumbar esos tests, mismo criterio que
/// `notificacionesNoLeidasProvider` (Fase 63).
final eventoRecuperacionContrasenaProvider = StreamProvider<AuthChangeEvent>((
  ref,
) {
  try {
    return Supabase.instance.client.auth.onAuthStateChange.map(
      (state) => state.event,
    );
  } catch (_) {
    return const Stream.empty();
  }
});

/// Token de webhook por usuario (Fase 25) — igual que `authRepositoryProvider`,
/// siempre apunta a Supabase directo (no bifurca Drift/Supabase: el token
/// solo existe una vez que hay una cuenta en la nube).
final automatizacionRepositoryProvider = Provider<AutomatizacionRepository>((
  ref,
) {
  return AutomatizacionRepositorySupabase(Supabase.instance.client);
});

/// Token actual del usuario, leído por `AutomatizacionScreen` para armar la
/// URL del webhook. Se invalida manualmente tras "Generar nuevo enlace".
final tokenWebhookProvider = FutureProvider<String>((ref) {
  return ref.watch(automatizacionRepositoryProvider).obtenerTokenWebhook();
});

/// Perfil social (nick/avatar/Instagram, Fase 31) — igual que
/// `automatizacionRepositoryProvider`, siempre apunta a Supabase directo:
/// estos campos solo existen una vez que hay una cuenta en la nube.
final perfilRepositoryProvider = Provider<PerfilRepository>((ref) {
  return PerfilRepositorySupabase(Supabase.instance.client);
});

/// Perfil actual, leído por `OnboardingResumenStep` y `MiPerfilScreen`. Se
/// invalida manualmente tras guardar el nick/avatar/Instagram.
final perfilProvider = FutureProvider<Perfil>((ref) {
  return ref.watch(perfilRepositoryProvider).obtenerPerfil();
});

/// Amigos por nick (Fase 63) — igual que `perfilRepositoryProvider`,
/// siempre apunta a Supabase directo: es una tabla que solo existe en la
/// nube, no bifurca Drift/Supabase.
final amistadRepositoryProvider = Provider<AmistadRepository>((ref) {
  return AmistadRepositorySupabase(Supabase.instance.client);
});

/// Solicitudes de amistad pendientes recibidas, leído por `MisAmigosScreen`.
/// Se invalida manualmente tras aceptar/rechazar una.
final solicitudesRecibidasProvider = FutureProvider<List<SolicitudRecibida>>((
  ref,
) {
  return ref.watch(amistadRepositoryProvider).obtenerSolicitudesRecibidas();
});

/// Amigos ya aceptados, leído por `MisAmigosScreen`. Se invalida
/// manualmente tras aceptar una solicitud nueva.
final amigosProvider = FutureProvider<List<PerfilPublico>>((ref) {
  return ref.watch(amistadRepositoryProvider).obtenerAmigos();
});

/// Notificaciones dentro de la app (Fase 63) — mismo criterio que
/// `amistadRepositoryProvider`, siempre Supabase directo.
final notificacionRepositoryProvider = Provider<NotificacionRepository>((
  ref,
) {
  return NotificacionRepositorySupabase(Supabase.instance.client);
});

/// Lista completa (leídas y no leídas) para `NotificacionesScreen`. Se
/// invalida manualmente al marcar una como leída.
final notificacionesProvider = FutureProvider<List<Notificacion>>((ref) {
  return ref.watch(notificacionRepositoryProvider).obtenerTodas();
});

/// Fase 70 — llamado desde `resumenDashboardProvider` con las
/// `deudasActivas` ya calculadas, como mucho una vez por día.
final generarNotificacionesVencimientoProvider =
    Provider<GenerarNotificacionesVencimiento>((ref) {
      return GenerarNotificacionesVencimiento(
        notificacionRepository: ref.watch(notificacionRepositoryProvider),
        preferenciasRepository: ref.watch(preferenciasRepositoryProvider),
      );
    });

/// Escucha `notificaciones` en tiempo real (Supabase Realtime, mismo
/// patrón que `transaccionesEnVivoProvider` de la Fase 25.5) filtrada a
/// las no leídas del usuario actual — el dashboard solo necesita el
/// conteo para el badge de la campana, así que expone la lista cruda en
/// vez de duplicar lógica de agregación en un provider aparte. Solo se
/// activa con datos en la nube: notificaciones es una tabla que no existe
/// en Drift, no tiene sentido en modo local.
final notificacionesNoLeidasProvider = StreamProvider<List<Map<String, dynamic>>>((
  ref,
) {
  if (!ref.watch(datosEnLaNubeProvider)) return const Stream.empty();
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();
  return Supabase.instance.client
      .from('notificaciones')
      .stream(primaryKey: ['id'])
      .eq('usuario_id', userId)
      .eq('leida', false);
});

/// Borrado de cuenta (Fase 22, requisito de Apple — Guideline 5.1.1(v)).
/// Igual que `migrarDatosALaNubeProvider`, se construye aparte de los
/// providers de datos financieros bifurcados de arriba porque siempre debe
/// apuntar a Supabase (para cuando se llama, `datosEnLaNubeProvider` ya es
/// `true` — no tendría sentido borrar una cuenta con datos todavía en
/// Drift sin migrar).
final eliminarCuentaDeUsuarioProvider = Provider<EliminarCuentaDeUsuario>((
  ref,
) {
  return EliminarCuentaDeUsuario(
    cuentaRepository: ref.watch(cuentaRepositoryProvider),
    categoriaRepository: ref.watch(categoriaRepositoryProvider),
    deudaRepository: ref.watch(deudaRepositoryProvider),
    transaccionRepository: ref.watch(transaccionRepositoryProvider),
    pagoDeudaRepository: ref.watch(pagoDeudaRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
  );
});

/// Gate de entrada: decide onboarding vs. dashboard en `RootScreen`.
///
/// Fase 75 — contra `usuarios.nick` en Supabase (vía `perfilProvider`, ya
/// cargado para `OnboardingResumenStep`/`MiPerfilScreen`), no una bandera
/// local: antes era `PreferenciasRepository.onboardingCompletado()`
/// (`SharedPreferences`), así que alguien que ya había completado el
/// onboarding en otro dispositivo (o reinstalaba la app) volvía a verlo,
/// porque esa bandera nunca salía del dispositivo donde se puso en `true`.
/// Se usa `nick` en vez de `nombreCompleto` a propósito: `nick` se fija una
/// sola vez en el onboarding y ninguna pantalla lo deja editar después
/// (`OnboardingNickStep`: "No se puede cambiar después de este paso"), así
/// que nunca puede volver a `null` por su cuenta. `nombreCompleto` en
/// cambio es opcional y editable/borrable en cualquier momento desde "Mi
/// perfil" — gatear con él haría reaparecer el onboarding si alguien lo
/// borra ahí, y esa persona quedaría atascada: `nickDisponible` no excluye
/// al usuario dueño del nick, así que no podría volver a "elegir" el nick
/// que ya tiene.
final onboardingCompletadoProvider = FutureProvider<bool>((ref) async {
  final perfil = await ref.watch(perfilProvider.future);
  return (perfil.nick ?? '').trim().isNotEmpty;
});

/// Nombre guardado por el usuario, leído por el encabezado del dashboard.
final nombreUsuarioProvider = FutureProvider<String?>((ref) {
  return ref.watch(preferenciasRepositoryProvider).obtenerNombre();
});

/// Notificaciones push (Fase 71) — construir esta clase nunca falla, ni
/// siquiera sin `Firebase.initializeApp()` real (`FirebaseMessaging.
/// instance` se resuelve perezosamente dentro de cada método, ver
/// `FirebasePushNotificationRepository`).
final pushNotificationRepositoryProvider = Provider<PushNotificationRepository>((
  ref,
) {
  return FirebasePushNotificationRepository();
});

/// Token de push por dispositivo (Fase 71) — mismo criterio que
/// `automatizacionRepositoryProvider`: siempre Supabase directo, sin
/// bifurcar Drift/Supabase.
final tokenDispositivoRepositoryProvider = Provider<TokenDispositivoRepository>((
  ref,
) {
  return TokenDispositivoRepositorySupabase(Supabase.instance.client);
});

/// Se llama desde `RootScreen` (Fase 76) tras cualquier transición de
/// `haySesionActivaProvider` de `false` a `true` — cubre login con
/// correo/contraseña, Google y confirmación de correo por igual.
final registrarTokenDispositivoProvider = Provider<RegistrarTokenDispositivo>((
  ref,
) {
  return RegistrarTokenDispositivo(
    pushNotificationRepository: ref.watch(pushNotificationRepositoryProvider),
    tokenDispositivoRepository: ref.watch(tokenDispositivoRepositoryProvider),
  );
});

/// Se llama desde `MiPerfilScreen._cerrarSesion()`, antes de cerrar la
/// sesión de Supabase (mientras la RLS todavía deja borrar la fila propia).
final eliminarTokenDispositivoActualProvider =
    Provider<EliminarTokenDispositivoActual>((ref) {
      return EliminarTokenDispositivoActual(
        pushNotificationRepository: ref.watch(
          pushNotificationRepositoryProvider,
        ),
        tokenDispositivoRepository: ref.watch(
          tokenDispositivoRepositoryProvider,
        ),
      );
    });

/// Emite cada vez que Firebase rota el token de push de este dispositivo.
/// Envuelto en `try/catch`: sin `Firebase.initializeApp()` real (tests que
/// montan `FinanzasAutomaticasApp` completa), acceder a `onTokenRefresh`
/// lanza un error síncrono al leer `FirebaseMessaging.instance` — se
/// degrada a un stream vacío en vez de tumbar esos tests, mismo criterio
/// que `eventoRecuperacionContrasenaProvider` (Fase 65).
final tokenPushActualizadoProvider = StreamProvider<String>((ref) {
  try {
    return ref.watch(pushNotificationRepositoryProvider).onTokenRefresh;
  } catch (_) {
    return const Stream.empty();
  }
});

/// Mensaje push recibido con la app en primer plano — `FinanzasAutomaticasApp`
/// lo escucha para mostrar un `SnackBar` (Fase 71). Mismo `try/catch`
/// defensivo que `tokenPushActualizadoProvider`.
final mensajePushPrimerPlanoProvider = StreamProvider<MensajePush>((ref) {
  try {
    return ref.watch(pushNotificationRepositoryProvider).onMensajePrimerPlano;
  } catch (_) {
    return const Stream.empty();
  }
});

/// El usuario tocó una notificación push con la app en segundo plano —
/// `FinanzasAutomaticasApp` lo escucha para navegar a `NotificacionesScreen`
/// (Fase 71). Mismo `try/catch` defensivo que `tokenPushActualizadoProvider`.
final mensajePushAbiertoProvider = StreamProvider<MensajePush>((ref) {
  try {
    return ref.watch(pushNotificationRepositoryProvider).onMensajeAbierto;
  } catch (_) {
    return const Stream.empty();
  }
});
