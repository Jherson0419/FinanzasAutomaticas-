import '../plan_pago.dart';

/// Configuración del plan de pago elegida por el usuario (Fase 83).
class ConfigPlanPago {
  /// Cuánto puede pagar de más cada mes (≥ 0), en la moneda principal.
  final double extraMensual;

  /// Estrategia elegida a mano; `null` = la recomendada.
  final EstrategiaPago? estrategia;

  const ConfigPlanPago({this.extraMensual = 0, this.estrategia});

  ConfigPlanPago conExtra(double extra) => ConfigPlanPago(
    extraMensual: extra < 0 ? 0 : extra,
    estrategia: estrategia,
  );

  ConfigPlanPago conEstrategia(EstrategiaPago? e) =>
      ConfigPlanPago(extraMensual: extraMensual, estrategia: e);
}

/// Puerto de preferencias del plan (Fase 83). Solo preferencias locales del
/// dispositivo: no toca el esquema de datos ni la nube. Aparte de
/// `PreferenciasRepository` a propósito, para no obligar a todas sus
/// implementaciones a conocer el plan.
abstract class PreferenciasPlanRepository {
  /// Lectura síncrona: la pantalla la necesita al construirse.
  ConfigPlanPago leer();

  Future<void> guardar(ConfigPlanPago config);
}
