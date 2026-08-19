import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'domain/entities/tema_app.dart';
import 'presentation/app.dart';
import 'presentation/screens/dashboard/dashboard_fixtures.dart';
import 'presentation/state/dashboard/dashboard_providers.dart';
import 'presentation/state/providers.dart';

/// Entry point de desarrollo: monta la app con datos fixture en vez de la
/// base de datos real, para poder ver/ajustar la UI del dashboard sin
/// depender de datos previamente registrados. También se salta login y
/// bloqueo (Fase 18) para ir directo al dashboard.
///
/// Ejecutar con: flutter run -t lib/main_dev.dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(
    ProviderScope(
      overrides: [
        cuentasProvider.overrideWith((ref) => cuentasDashboardFixture),
        resumenDashboardProvider.overrideWith((ref) => resumenDashboardFixture),
        onboardingCompletadoProvider.overrideWith((ref) => true),
        nombreUsuarioProvider.overrideWith((ref) => 'Jherson'),
        haySesionActivaProvider.overrideWith((ref) => true),
        bloqueoConfiguradoProvider.overrideWith((ref) async => false),
        bloqueoOmitidoProvider.overrideWith((ref) async => true),
        // `temaProvider` (Fase 31) lee `sharedPreferencesProvider`, que
        // este entry point de desarrollo no inicializa — se fija en
        // oscuro (el look de siempre) en vez de instanciar
        // `SharedPreferences` real solo para esto.
        temaProvider.overrideWithValue(TemaApp.oscuro),
      ],
      child: const FinanzasAutomaticasApp(),
    ),
  );
}
