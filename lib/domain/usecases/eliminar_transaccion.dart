import '../calculo_saldo.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/transaccion_repository.dart';

class EliminarTransaccion {
  final TransaccionRepository _transaccionRepository;
  final CuentaRepository _cuentaRepository;

  EliminarTransaccion({
    required TransaccionRepository transaccionRepository,
    required CuentaRepository cuentaRepository,
  }) : _transaccionRepository = transaccionRepository,
       _cuentaRepository = cuentaRepository;

  Future<void> call({required String transaccionId}) async {
    final transaccion = await _transaccionRepository.obtenerPorId(
      transaccionId,
    );
    if (transaccion == null) {
      throw ArgumentError('La transacción $transaccionId no existe');
    }

    final cuenta = await _cuentaRepository.obtenerPorId(transaccion.cuentaId);
    if (cuenta == null) {
      throw ArgumentError('La cuenta ${transaccion.cuentaId} no existe');
    }

    final saldoRevertido = revertirEfectoTransaccion(
      cuenta.saldoActual,
      transaccion.tipo,
      transaccion.monto,
    );
    await _cuentaRepository.actualizar(
      cuenta.copyWith(saldoActual: saldoRevertido),
    );

    await _transaccionRepository.eliminar(transaccionId);
  }
}
