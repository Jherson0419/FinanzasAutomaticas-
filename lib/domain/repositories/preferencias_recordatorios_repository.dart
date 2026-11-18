import '../recordatorios.dart';

/// Puerto de la configuración de recordatorios (Fase 87). Solo
/// preferencias locales del dispositivo, como el plan y el consejero.
abstract class PreferenciasRecordatoriosRepository {
  /// Lectura síncrona: la pantalla la necesita al construirse.
  ConfigRecordatorios leer();

  Future<void> guardar(ConfigRecordatorios config);
}
