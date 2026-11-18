import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/plan_pago.dart';
import '../../domain/repositories/preferencias_plan_repository.dart';

/// `PreferenciasPlanRepository` sobre `SharedPreferences` (Fase 83).
class PreferenciasPlanRepositorySharedPrefs
    implements PreferenciasPlanRepository {
  static const claveExtra = 'plan_pago.extra_mensual';
  static const claveEstrategia = 'plan_pago.estrategia';

  final SharedPreferences _prefs;

  PreferenciasPlanRepositorySharedPrefs(this._prefs);

  @override
  ConfigPlanPago leer() {
    final extra = _prefs.getDouble(claveExtra) ?? 0;
    final nombre = _prefs.getString(claveEstrategia);
    final estrategia = EstrategiaPago.values
        .where((e) => e.name == nombre && e != EstrategiaPago.base)
        .firstOrNull;
    return ConfigPlanPago(
      extraMensual: extra < 0 ? 0 : extra,
      estrategia: estrategia,
    );
  }

  @override
  Future<void> guardar(ConfigPlanPago config) async {
    await _prefs.setDouble(claveExtra, config.extraMensual);
    final estrategia = config.estrategia;
    if (estrategia == null) {
      await _prefs.remove(claveEstrategia);
    } else {
      await _prefs.setString(claveEstrategia, estrategia.name);
    }
  }
}
