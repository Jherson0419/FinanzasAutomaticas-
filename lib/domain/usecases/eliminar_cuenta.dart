import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';

class EliminarCuenta {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final PagoDeudaRepository _pagoDeudaRepository;
  final DeudaRepository _deudaRepository;

  EliminarCuenta({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required PagoDeudaRepository pagoDeudaRepository,
    required DeudaRepository deudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _pagoDeudaRepository = pagoDeudaRepository,
       _deudaRepository = deudaRepository;

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

    // Fase 62: una cuenta de crédito trae su propia `Deuda` vinculada
    // (`cuentaId`) — se elimina junto con la cuenta, en la misma
    // operación, para no dejarla huérfana.
    final deudas = await _deudaRepository.obtenerTodas();
    for (final deuda in deudas) {
      if (deuda.cuentaId == cuentaId) {
        await _deudaRepository.eliminar(deuda.id);
        break;
      }
    }
  }
}
