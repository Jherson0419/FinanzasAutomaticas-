import '../hitos.dart';

/// Puerto de los hitos logrados (Fase 87): id, fecha y si ya se celebró.
/// Solo preferencias locales del dispositivo (como el plan y el consejero).
abstract class PreferenciasHitosRepository {
  /// Lectura síncrona: las pantallas la necesitan al construirse.
  Map<Hito, HitoLogrado> leer();

  /// Guarda (o reemplaza) los hitos dados.
  Future<void> guardar(Iterable<HitoLogrado> hitos);
}
