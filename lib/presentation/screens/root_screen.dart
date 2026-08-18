import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'configurar_bloqueo_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'desbloqueo_screen.dart';
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
/// 3. ¿Ya configuró PIN/biométrico, u optó por omitirlo? Ninguna de las
///    dos → `ConfigurarBloqueoScreen` (se ofrece una sola vez, Fase 18).
/// 4. ¿Ya se desbloqueó en esta apertura en frío? No (y hay bloqueo
///    configurado) → `DesbloqueoScreen` (Fase 18).
/// 5. `onboardingCompletado` (Fase 9, sin cambios) → `DashboardScreen` o
///    `OnboardingFlowScreen`.
class RootScreen extends ConsumerWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          : const _PuertaBloqueo(),
    );
  }
}

class _PuertaBloqueo extends ConsumerWidget {
  const _PuertaBloqueo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bloqueoConfiguradoAsync = ref.watch(bloqueoConfiguradoProvider);

    return bloqueoConfiguradoAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => _ErrorScaffold(error: error),
      data: (bloqueoConfigurado) {
        if (!bloqueoConfigurado) {
          final bloqueoOmitidoAsync = ref.watch(bloqueoOmitidoProvider);
          return bloqueoOmitidoAsync.when(
            loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stackTrace) => _ErrorScaffold(error: error),
            data: (omitido) => omitido
                ? const _PuertaOnboarding()
                : const ConfigurarBloqueoScreen(),
          );
        }

        final desbloqueado = ref.watch(desbloqueadoEnEstaSesionProvider);
        if (!desbloqueado) {
          return const DesbloqueoScreen();
        }
        return const _PuertaOnboarding();
      },
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
