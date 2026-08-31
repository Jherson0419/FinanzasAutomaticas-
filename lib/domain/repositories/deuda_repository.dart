import '../entities/deuda.dart';

abstract class DeudaRepository {
  Future<List<Deuda>> obtenerTodas();
  Future<List<Deuda>> obtenerActivas();
  Future<Deuda?> obtenerPorId(String id);
  Future<void> crear(Deuda deuda);
  Future<void> actualizar(Deuda deuda);
  Future<void> eliminar(String id);

  /// Deudas de OTROS usuarios vinculadas a mí como amigo (Fase 68,
  /// `amigo_usuario_id = auth.uid()`) — solo lectura, nunca las creo ni
  /// las edito yo. El adapter de Drift siempre devuelve `[]`: el
  /// almacenamiento local de este dispositivo nunca tiene filas de otro
  /// usuario, por diseño.
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo();
}
