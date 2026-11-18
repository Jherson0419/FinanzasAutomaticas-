import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/repositories/datos_locales_repository.dart';
import '../drift/app_database.dart';
import 'modo_local.dart';

/// `DatosLocalesRepository` (Fase 78): borra Drift y las claves
/// `modo_local.*` de `SharedPreferences`.
///
/// Reutiliza `AppDatabase.limpiarTrasMigracion()` — hace exactamente lo
/// mismo que se necesita aquí (todas las tablas financieras + categorías
/// propias, conservando las predeterminadas).
///
/// Deliberadamente NO llama `PreferenciasRepository.limpiarTodo()`: eso
/// borraría `datos_en_la_nube`/`tema_app`/`recordar_sesion`, que comparte
/// la app de producción si está instalada con el mismo bundle id. Solo se
/// borra además la marca de "notificaciones ya generadas hoy", para que
/// vuelvan a generarse sobre los datos nuevos.
class DatosLocalesRepositoryLocal implements DatosLocalesRepository {
  static const claveUltimaGeneracionNotificaciones =
      'ultima_generacion_notificaciones_vencimiento';

  final AppDatabase _db;
  final SharedPreferences _prefs;

  DatosLocalesRepositoryLocal(this._db, this._prefs);

  @override
  Future<void> borrarTodo() async {
    await _db.transaction(_db.limpiarTrasMigracion);
    final claves = _prefs
        .getKeys()
        .where((clave) => clave.startsWith(prefijoModoLocal))
        .toList();
    for (final clave in claves) {
      await _prefs.remove(clave);
    }
    await _prefs.remove(claveUltimaGeneracionNotificaciones);
  }
}
