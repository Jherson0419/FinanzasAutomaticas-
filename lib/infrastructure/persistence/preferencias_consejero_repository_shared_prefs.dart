import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/consejero.dart';
import '../../domain/repositories/preferencias_consejero_repository.dart';

/// `PreferenciasConsejeroRepository` sobre `SharedPreferences` (Fase 86):
/// un JSON `{consejoId: {tipo, fecha, huella}}` bajo [clave]. Un valor
/// ilegible se ignora (el consejo simplemente se vuelve a mostrar).
class PreferenciasConsejeroRepositorySharedPrefs
    implements PreferenciasConsejeroRepository {
  static const clave = 'consejero.estados';

  final SharedPreferences _prefs;

  PreferenciasConsejeroRepositorySharedPrefs(this._prefs);

  @override
  Map<String, EstadoConsejo> leer() {
    final texto = _prefs.getString(clave);
    if (texto == null) return {};
    try {
      final mapa = jsonDecode(texto) as Map<String, dynamic>;
      final resultado = <String, EstadoConsejo>{};
      for (final MapEntry(:key, :value) in mapa.entries) {
        final v = value as Map<String, dynamic>;
        final tipo = TipoEstadoConsejo.values
            .where((t) => t.name == v['tipo'])
            .firstOrNull;
        final fecha = DateTime.tryParse(v['fecha'] as String? ?? '');
        final huella = v['huella'] as String?;
        if (tipo == null || fecha == null || huella == null) continue;
        resultado[key] = EstadoConsejo(
          tipo: tipo,
          fecha: fecha,
          huella: huella,
        );
      }
      return resultado;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> guardar(String consejoId, EstadoConsejo estado) async {
    final todos = leer()..[consejoId] = estado;
    await _prefs.setString(
      clave,
      jsonEncode({
        for (final MapEntry(:key, :value) in todos.entries)
          key: {
            'tipo': value.tipo.name,
            'fecha': value.fecha.toIso8601String(),
            'huella': value.huella,
          },
      }),
    );
  }
}
