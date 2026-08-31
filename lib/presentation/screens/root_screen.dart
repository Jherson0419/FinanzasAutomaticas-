import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'dashboard/dashboard_screen.dart';
import 'login_screen.dart';
import 'migrar_datos_screen.dart';
import 'onboarding/onboarding_flow_screen.dart';

/// Punto de entrada de la app. Orden de las puertas, cada una condición
/// para pasar a la siguiente:
/// 1. ¿Hay sesión de Supabase activa? No → `LoginScreen` (Fase 18).
/// 2. ¿Hay datos financieros locales sin migrar a Supabase? Sí →
///    `MigrarDatosScreen` (Fase 21); si no hay ningún dato local que
///    migrar, se marca la migración como completada sin mostrar nada y se
///    sigue de largo (cuenta nueva, Fase 21.4).
/// 3. `onboardingCompletado` (Fase 9, sin cambios) → `DashboardScreen` o
///    `OnboardingFlowScreen`.
///
/// El bloqueo local por PIN/biométrico (Fase 18, puertas 3-4 de esta
/// pantalla en su momento) se eliminó por completo en la Fase 55 — la
/// sesión de Supabase Auth es la única puerta de entrada, sin ningún
/// desbloqueo adicional después del login.
///
/// Fase 76 — también es el único lugar que pide permiso de notificaciones
/// y registra el token del dispositivo (Fase 71) tras un login exitoso:
/// se dispara con cualquier transición de `haySesionActivaProvider` de
/// `false` a `true`, sin importar el camino (correo/contraseña, Google —
/// Fase 56 — o una cuenta nueva que recién confirma su correo — Fase 54).
/// Antes esto solo vivía en `LoginScreen._iniciarSesion`, así que alguien
/// que solo usaba "Continuar con Google" nunca lo veía: ese método no deja
/// una sesión activa al terminar (solo abre el navegador), la sesión real
/// llega después, sola, por el deep link — igual que la confirmación de
/// correo. `haySesionActivaProvider` ya normaliza esos dos caminos
/// asíncronos junto con el síncrono en un solo booleano, así que
/// centralizar aquí cubre los tres sin que cada pantalla tenga que saberlo.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  Future<void> _registrarTokenTrasIniciarSesion(WidgetRef ref) async {
    try {
      await ref.read(registrarTokenDispositivoProvider).call();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(haySesionActivaProvider, (previous, next) {
      if (previous == false && next == true) {
        _registrarTokenTrasIniciarSesion(ref);
      }
    });

    final haySesion = ref.watch(haySesionActivaProvider);
    if (!haySesion) {
      return const LoginScreen();
    }

    final necesitaMigracionAsync = ref.watch(necesitaMigracionProvider);
    return necesitaMigracionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _ErrorScaffold(error: error),
      data: (necesitaMigracion) => necesitaMigracion
          ? const MigrarDatosScreen()
          : const _PuertaOnboarding(),
    );
  }
}

class _PuertaOnboarding extends ConsumerWidget {
  const _PuertaOnboarding();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingCompletadoProvider);

    return onboardingAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _ErrorScaffold(error: error),
      data: (completado) =>
          completado ? const DashboardScreen() : const OnboardingFlowScreen(),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No se pudo iniciar la app.\n$error',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
