import '../entities/cuenta.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';

/// Edita nombre, tipo y moneda de una cuenta. Nunca toca `saldoActual`
/// — se deriva automáticamente de transacciones y pagos.
class EditarCuenta {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final PagoDeudaRepository _pagoDeudaRepository;

  EditarCuenta({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required PagoDeudaRepository pagoDeudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _pagoDeudaRepository = pagoDeudaRepository;

  Future<Cuenta> call({
    required String cuentaId,
    required String nombre,
    required TipoCuenta tipo,
    required Moneda moneda,
  }) async {
    final actual = await _cuentaRepository.obtenerPorId(cuentaId);
    if (actual == null) {
      throw ArgumentError('La cuenta $cuentaId no existe');
    }

    if (moneda != actual.moneda) {
      final transacciones = await _transaccionRepository.obtenerPorCuenta(
        cuentaId,
      );
      final pagos = await _pagoDeudaRepository.obtenerPorCuenta(cuentaId);
      if (transacciones.isNotEmpty || pagos.isNotEmpty) {
        throw StateError(
          'No se puede cambiar la moneda de una cuenta con movimientos registrados',
        );
      }
    }

    final actualizada = actual.copyWith(
      nombre: nombre,
      tipo: tipo,
      moneda: moneda,
    );
    await _cuentaRepository.actualizar(actualizada);
    return actualizada;
  }
}
