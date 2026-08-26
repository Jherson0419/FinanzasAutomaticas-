import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';

class EliminarDeuda {
  final DeudaRepository _deudaRepository;
  final PagoDeudaRepository _pagoDeudaRepository;

  EliminarDeuda({
    required DeudaRepository deudaRepository,
    required PagoDeudaRepository pagoDeudaRepository,
  }) : _deudaRepository = deudaRepository,
       _pagoDeudaRepository = pagoDeudaRepository;

  Future<void> call({required String deudaId}) async {
    final actual = await _deudaRepository.obtenerPorId(deudaId);
    if (actual == null) {
      throw ArgumentError('La deuda $deudaId no existe');
    }
    if (actual.cuentaId != null) {
      throw StateError(
        'Edita o elimina la cuenta de crédito directamente, esta deuda se '
        'sincroniza sola.',
      );
    }

    final pagos = await _pagoDeudaRepository.obtenerPorDeuda(deudaId);
    if (pagos.isNotEmpty) {
      throw StateError('No se puede eliminar una deuda con pagos registrados');
    }

    await _deudaRepository.eliminar(deudaId);
  }
}
