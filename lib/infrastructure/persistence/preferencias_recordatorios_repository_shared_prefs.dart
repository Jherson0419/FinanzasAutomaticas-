import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/recordatorios.dart';
import '../../domain/repositories/preferencias_recordatorios_repository.dart';

/// `PreferenciasRecordatoriosRepository` sobre `SharedPreferences`
/// (Fase 87). Sin valor guardado → todo apagado (los defaults de
/// [ConfigRecordatorios]).
class PreferenciasRecordatoriosRepositorySharedPrefs
    implements PreferenciasRecordatoriosRepository {
  static const prefijo = 'recordatorios.';

  final SharedPreferences _prefs;

  PreferenciasRecordatoriosRepositorySharedPrefs(this._prefs);

  @override
  ConfigRecordatorios leer() {
    const d = ConfigRecordatorios();
    bool b(String k, bool def) => _prefs.getBool('$prefijo$k') ?? def;
    int i(String k, int def, int min, int max) {
      final v = _prefs.getInt('$prefijo$k') ?? def;
      return v < min || v > max ? def : v;
    }

    return ConfigRecordatorios(
      vencimientos: b('vencimientos', d.vencimientos),
      cobros: b('cobros', d.cobros),
      revisionSemanal: b('revision_semanal', d.revisionSemanal),
      diaRevision: i('dia_revision', d.diaRevision, 1, 7),
      horaRevision: i('hora_revision', d.horaRevision, 0, 23),
      minutoRevision: i('minuto_revision', d.minutoRevision, 0, 59),
      mostrarMontos: b('mostrar_montos', d.mostrarMontos),
      ofrecimientoHecho: b('ofrecimiento_hecho', d.ofrecimientoHecho),
    );
  }

  @override
  Future<void> guardar(ConfigRecordatorios c) async {
    await _prefs.setBool('${prefijo}vencimientos', c.vencimientos);
    await _prefs.setBool('${prefijo}cobros', c.cobros);
    await _prefs.setBool('${prefijo}revision_semanal', c.revisionSemanal);
    await _prefs.setInt('${prefijo}dia_revision', c.diaRevision);
    await _prefs.setInt('${prefijo}hora_revision', c.horaRevision);
    await _prefs.setInt('${prefijo}minuto_revision', c.minutoRevision);
    await _prefs.setBool('${prefijo}mostrar_montos', c.mostrarMontos);
    await _prefs.setBool('${prefijo}ofrecimiento_hecho', c.ofrecimientoHecho);
  }
}
