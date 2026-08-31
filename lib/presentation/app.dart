import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/entities/mensaje_push.dart';
import '../domain/entities/tema_app.dart';
import '../domain/parsear_deep_link_agregar_amigo.dart';
import 'theme/app_theme.dart';
import 'screens/agregar_amigo_screen.dart';
import 'screens/automatizacion_screen.dart';
import 'screens/categoria_nueva_screen.dart';
import 'screens/consejos_financieros_screen.dart';
import 'screens/cuenta_nueva_screen.dart';
import 'screens/deuda_detalle_screen.dart';
import 'screens/historial_pagos_deuda_screen.dart';
import 'screens/mi_perfil_screen.dart';
import 'screens/mis_amigos_screen.dart';
import 'screens/mis_categorias_screen.dart';
import 'screens/mis_cuentas_screen.dart';
import 'screens/movimientos_cuenta_screen.dart';
import 'screens/notificaciones_screen.dart';
import 'screens/nueva_contrasena_screen.dart';
import 'screens/pago_deuda_nuevo_screen.dart';
import 'screens/placeholders/deuda_nueva_screen.dart';
import 'screens/placeholders/transaccion_nueva_screen.dart';
import 'screens/root_screen.dart';
import 'screens/todos_los_movimientos_screen.dart';
import 'state/providers.dart';

/// Fase 31: `themeMode` sigue la preferencia guardada (`temaProvider`) en
/// vez del `ThemeMode.dark` fijo de la Fase 19 — claro/oscuro/según el
/// sistema, elegible desde "Mi perfil → Apariencia".
ThemeMode _aThemeMode(TemaApp tema) {
  switch (tema) {
    case TemaApp.claro:
      return ThemeMode.light;
    case TemaApp.oscuro:
      return ThemeMode.dark;
    case TemaApp.sistema:
      return ThemeMode.system;
  }
}

class FinanzasAutomaticasApp extends ConsumerStatefulWidget {
  const FinanzasAutomaticasApp({super.key});

  @override
  ConsumerState<FinanzasAutomaticasApp> createState() =>
      _FinanzasAutomaticasAppState();
}

/// Fase 64 — escucha el deep link `finzo://agregar-amigo?nick=` mientras la
/// app está abierta (`uriLinkStream`) y también al abrirla recién por ese
/// link (`getInitialLink`). No es lo mismo que `finzo://login-callback`
/// (Fase 54): ese lo intercepta `supabase_flutter` internamente porque
/// tiene forma de callback de autenticación — este host no, así que esta
/// suscripción a `app_links` es propia de la app (ver
/// `config/supabase_config.dart`).
class _FinanzasAutomaticasAppState extends ConsumerState<FinanzasAutomaticasApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Uri>? _deepLinkSub;

  @override
  void initState() {
    super.initState();
    _escucharDeepLinks();
    _revisarMensajePushInicial();
  }

  /// Fase 71 — la notificación que abrió la app desde cerrada (cold
  /// start), si la hubo. `try/catch`: sin `Firebase.initializeApp()` real
  /// (tests que montan esta app completa), `PushNotificationRepository.
  /// mensajeInicial()` lanza al leer `FirebaseMessaging.instance` — mismo
  /// criterio defensivo que `_escucharDeepLinks`.
  Future<void> _revisarMensajePushInicial() async {
    try {
      final mensaje = await ref
          .read(pushNotificationRepositoryProvider)
          .mensajeInicial();
      if (mensaje != null) _abrirNotificaciones();
    } catch (_) {}
  }

  void _abrirNotificaciones() {
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const NotificacionesScreen()),
    );
  }

  // `onError`/`try-catch` defensivos: sin un plugin nativo registrado (p.
  // ej. en `app_theme_mode_test.dart`, que monta `FinanzasAutomaticasApp`
  // completa en un test de widgets) `app_links` no tiene ningún canal de
  // plataforma que responder — no hay deep link real que resolver ahí, se
  // ignora en vez de tumbar la app/el test.
  Future<void> _escucharDeepLinks() async {
    final appLinks = AppLinks();
    _deepLinkSub = appLinks.uriLinkStream.listen(
      _manejarDeepLink,
      onError: (_) {},
    );
    try {
      final linkInicial = await appLinks.getInitialLink();
      if (linkInicial != null) _manejarDeepLink(linkInicial);
    } catch (_) {}
  }

  void _manejarDeepLink(Uri uri) {
    final nick = parsearNickDesdeLinkAgregarAmigo(uri);
    if (nick == null) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AgregarAmigoScreen(nickInicial: nick),
      ),
    );
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    super.dispose();
  }

  /// Fase 65 (B.3) — cuando llega `finzo://reset-password`,
  /// `supabase_flutter` arma sola una sesión de recuperación y emite
  /// `AuthChangeEvent.passwordRecovery` por `onAuthStateChange`
  /// (`eventoRecuperacionContrasenaProvider` lo expone ya envuelto en
  /// `try/catch` para no requerir Supabase inicializado en tests). Se
  /// escucha con `ref.listen` (no `ref.watch`): es un evento único que
  /// dispara una navegación imperativa, no algo que la UI deba reconstruir
  /// en cada build.
  void _alCambiarEstadoAuth(
    AsyncValue<AuthChangeEvent>? previous,
    AsyncValue<AuthChangeEvent> next,
  ) {
    if (next.value != AuthChangeEvent.passwordRecovery) return;
    _navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (context) => const NuevaContrasenaScreen()),
    );
  }

  /// Fase 71 — push recibido con la app en primer plano: el sistema
  /// operativo nunca muestra su propia notificación en este caso, así que
  /// la app avisa con un `SnackBar` simple. No reemplaza el sistema de
  /// notificaciones dentro de la app (Fase 63) — sigue siendo la fuente de
  /// verdad; esto es solo un aviso adicional, sin marcar nada como leído
  /// ni tocar `notificacionesProvider`.
  void _alRecibirMensajePushPrimerPlano(
    AsyncValue<MensajePush>? previous,
    AsyncValue<MensajePush> next,
  ) {
    final mensaje = next.value;
    if (mensaje == null) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          mensaje.cuerpo ?? mensaje.titulo ?? 'Tienes una notificación nueva',
        ),
      ),
    );
  }

  /// Fase 71 — el usuario tocó la notificación del sistema con la app en
  /// segundo plano: navega a `NotificacionesScreen`, la misma pantalla que
  /// ya lista todo (Fase 63) — sin enrutamiento más específico por `data`
  /// todavía, no hace falta más detalle para esta fase.
  void _alAbrirMensajePush(
    AsyncValue<MensajePush>? previous,
    AsyncValue<MensajePush> next,
  ) {
    if (next.value == null) return;
    _abrirNotificaciones();
  }

  @override
  Widget build(BuildContext context) {
    final tema = ref.watch(temaProvider);
    ref.listen(eventoRecuperacionContrasenaProvider, _alCambiarEstadoAuth);
    ref.listen(mensajePushPrimerPlanoProvider, _alRecibirMensajePushPrimerPlano);
    ref.listen(mensajePushAbiertoProvider, _alAbrirMensajePush);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Finzo',
      debugShowCheckedModeBanner: false,
      themeMode: _aThemeMode(tema),
      theme: appThemeClaro(),
      darkTheme: appThemeOscuro(),
      initialRoute: '/',
      routes: {
        '/': (context) => const RootScreen(),
        '/cuentas': (context) => const MisCuentasScreen(),
        '/categorias': (context) => const MisCategoriasScreen(),
        '/automatizacion': (context) => const AutomatizacionScreen(),
        '/consejos': (context) => const ConsejosFinancierosScreen(),
        '/perfil': (context) => const MiPerfilScreen(),
        '/amigos': (context) => const MisAmigosScreen(),
        '/notificaciones': (context) => const NotificacionesScreen(),
        '/transacciones/todas': (context) => const TodosLosMovimientosScreen(),
      },
      // Estas rutas necesitan leer `settings.arguments` (un id opcional para
      // entrar en modo edición), algo que la tabla `routes` estática no
      // soporta: sus builders solo reciben `BuildContext`.
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/deudas/pago':
            final args = settings.arguments;
            if (args is PagoDeudaRouteArgs) {
              return MaterialPageRoute(
                builder: (context) => PagoDeudaNuevoScreen(
                  deudaId: args.deudaId,
                  numeroCuotaInicial: args.numeroCuotaInicial,
                  montoEsperadoInicial: args.montoEsperadoInicial,
                ),
              );
            }
            final deudaId = args as String;
            return MaterialPageRoute(
              builder: (context) => PagoDeudaNuevoScreen(deudaId: deudaId),
            );
          case '/deudas/detalle':
            final deudaId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => DeudaDetalleScreen(deudaId: deudaId),
            );
          case '/deudas/historial':
            final deudaId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => HistorialPagosDeudaScreen(deudaId: deudaId),
            );
          case '/transacciones/nueva':
            final transaccionId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) =>
                  TransaccionNuevaScreen(transaccionId: transaccionId),
            );
          case '/deudas/nueva':
            final deudaId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) => DeudaNuevaScreen(deudaId: deudaId),
            );
          case '/cuentas/nueva':
            final cuentaId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) => CuentaNuevaScreen(cuentaId: cuentaId),
            );
          case '/categorias/nueva':
            final categoriaId = settings.arguments as String?;
            return MaterialPageRoute(
              builder: (context) =>
                  CategoriaNuevaScreen(categoriaId: categoriaId),
            );
          case '/cuentas/movimientos':
            final cuentaId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (context) => MovimientosCuentaScreen(cuentaId: cuentaId),
            );
        }
        return null;
      },
    );
  }
}
