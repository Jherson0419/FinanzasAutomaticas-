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
    final pagos = await _pagoDeudaRepository.obtenerPorDeuda(deudaId);
    if (pagos.isNotEmpty) {
      throw StateError('No se puede eliminar una deuda con pagos registrados');
    }

    await _deudaRepository.eliminar(deudaId);
  }
}
