import '../repositories/cuenta_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';

class EliminarCuenta {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final PagoDeudaRepository _pagoDeudaRepository;

  EliminarCuenta({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required PagoDeudaRepository pagoDeudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _pagoDeudaRepository = pagoDeudaRepository;

  Future<void> call({required String cuentaId}) async {
    final transacciones = await _transaccionRepository.obtenerPorCuenta(
      cuentaId,
    );
    final pagos = await _pagoDeudaRepository.obtenerPorCuenta(cuentaId);
    if (transacciones.isNotEmpty || pagos.isNotEmpty) {
      throw StateError(
        'No se puede eliminar una cuenta con movimientos registrados',
      );
    }

    await _cuentaRepository.eliminar(cuentaId);
  }
}
