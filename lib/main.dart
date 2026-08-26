import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'infrastructure/persistence/preferencias_repository_shared_prefs.dart';
import 'presentation/app.dart';
import 'presentation/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  final prefs = await SharedPreferences.getInstance();

  await _cerrarSesionSiNoDebeRecordarse(prefs);

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const FinanzasAutomaticasApp(),
    ),
  );
}

/// "Recuérdame" del login (Fase 65) — si `LoginScreen` guardó
/// `recordarSesion: false` la última vez, una sesión de Supabase restaurada
/// en este arranque en frío se cierra de inmediato, antes de que
/// `RootScreen` llegue a verla, forzando el login de nuevo. Con
/// `recordarSesion: true` (o si nunca se tocó el checkbox) no hace nada —
/// la sesión persiste normalmente, como ya ocurría antes de esta fase.
Future<void> _cerrarSesionSiNoDebeRecordarse(SharedPreferences prefs) async {
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) return;

  final preferencias = PreferenciasRepositorySharedPrefs(prefs);
  if (await preferencias.recordarSesion()) return;

  await client.auth.signOut();
}
