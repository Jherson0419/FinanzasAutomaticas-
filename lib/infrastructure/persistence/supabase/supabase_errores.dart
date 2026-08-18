import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Envuelve la ejecución de [accion] traduciendo errores de red/Postgrest a
/// `StateError` con un mensaje en español, accionable — mismo criterio que
/// `SupabaseAuthRepository` (Fase 18) para los errores de autenticación,
/// aplicado ahora a los adapters de datos financieros (Fase 21).
Future<T> conManejoDeErroresSupabase<T>(
  String contexto,
  Future<T> Function() accion,
) async {
  try {
    return await accion();
  } on PostgrestException catch (error) {
    debugPrint('Supabase ($contexto): ${error.message}');
    throw StateError('No se pudo guardar, intenta de nuevo.');
  } catch (error) {
    debugPrint('Supabase ($contexto): $error');
    final texto = error.toString().toLowerCase();
    final pareceProblemaDeRed =
        texto.contains('socket') ||
        texto.contains('network') ||
        texto.contains('failed host lookup') ||
        texto.contains('connection') ||
        texto.contains('timeout');
    throw StateError(
      pareceProblemaDeRed
          ? 'Sin conexión a internet. Intenta de nuevo.'
          : 'No se pudo guardar, intenta de nuevo.',
    );
  }
}
