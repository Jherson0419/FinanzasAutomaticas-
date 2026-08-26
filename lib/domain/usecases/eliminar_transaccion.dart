import '../calculo_saldo.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'sincronizar_deuda_tarjeta.dart';

class EliminarTransaccion {
  final TransaccionRepository _transaccionRepository;
  final CuentaRepository _cuentaRepository;
  final SincronizarDeudaTarjeta _sincronizarDeudaTarjeta;

  EliminarTransaccion({
    required TransaccionRepository transaccionRepository,
    required CuentaRepository cuentaRepository,
    required DeudaRepository deudaRepository,
  }) : _transaccionRepository = transaccionRepository,
       _cuentaRepository = cuentaRepository,
       _sincronizarDeudaTarjeta = SincronizarDeudaTarjeta(
         deudaRepository: deudaRepository,
       );

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
    final cuentaActualizada = cuenta.copyWith(saldoActual: saldoRevertido);
    await _cuentaRepository.actualizar(cuentaActualizada);
    await _sincronizarDeudaTarjeta(cuentaActualizada);

    await _transaccionRepository.eliminar(transaccionId);
  }
}
