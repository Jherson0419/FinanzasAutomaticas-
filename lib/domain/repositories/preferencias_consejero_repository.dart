import '../consejero.dart';

/// Puerto del estado del consejero (Fase 86): qué consejos descartaste o
/// pospusiste, por id de consejo. Solo preferencias locales del
/// dispositivo; no toca el esquema ni la nube (como el del plan).
abstract class PreferenciasConsejeroRepository {
  /// Lectura síncrona: la pantalla la necesita al construirse.
  Map<String, EstadoConsejo> leer();

  Future<void> guardar(String consejoId, EstadoConsejo estado);
}
