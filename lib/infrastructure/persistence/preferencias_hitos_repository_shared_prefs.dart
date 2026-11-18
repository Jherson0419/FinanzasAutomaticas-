import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/hitos.dart';
import '../../domain/repositories/preferencias_hitos_repository.dart';

/// `PreferenciasHitosRepository` sobre `SharedPreferences` (Fase 87): un
/// JSON `{hito: {fecha, celebrado}}` bajo [clave]. Un valor ilegible se
/// ignora (no borra nada: solo se vuelve a evaluar).
class PreferenciasHitosRepositorySharedPrefs
    implements PreferenciasHitosRepository {
  static const clave = 'avance.hitos';

  final SharedPreferences _prefs;

  PreferenciasHitosRepositorySharedPrefs(this._prefs);

  @override
  Map<Hito, HitoLogrado> leer() {
    final texto = _prefs.getString(clave);
    if (texto == null) return {};
    try {
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      final r = <Hito, HitoLogrado>{};
      for (final MapEntry(:key, :value) in mapa.entries) {
        final hito = Hito.values.where((h) => h.name == key).firstOrNull;
        final v = value as Map<String, dynamic>;
        final fecha = DateTime.tryParse(v['fecha'] as String? ?? '');
        if (hito == null || fecha == null) continue;
        r[hito] = HitoLogrado(
          hito: hito,
          fecha: fecha,
          celebrado: v['celebrado'] == true,
        );
      }
      return r;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> guardar(Iterable<HitoLogrado> hitos) async {
    final todos = leer();
    for (final h in hitos) {
      todos[h.hito] = h;
    }
    await _prefs.setString(
      clave,
      jsonEncode({
        for (final h in todos.values)
          h.hito.name: {
            'fecha': h.fecha.toIso8601String(),
            'celebrado': h.celebrado,
          },
      }),
    );
  }
}
