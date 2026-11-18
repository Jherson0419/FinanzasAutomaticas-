import '../calculo_saldo.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'registrar_transferencia.dart';
import 'sincronizar_deuda_tarjeta.dart';

class EliminarTransaccion {
  final TransaccionRepository _transaccionRepository;
  final CuentaRepository _cuentaRepository;
  final SincronizarDeudaTarjeta _sincronizarDeudaTarjeta;
  final DeudaRepository _deudaRepository;

  EliminarTransaccion({
    required TransaccionRepository transaccionRepository,
    required CuentaRepository cuentaRepository,
    required DeudaRepository deudaRepository,
  }) : _transaccionRepository = transaccionRepository,
       _cuentaRepository = cuentaRepository,
       _deudaRepository = deudaRepository,
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
    // Fase 85: borrar una cara de una transferencia borra las dos.
    final transferenciaId = transaccion.transferenciaId;
    if (transferenciaId != null) {
      await EliminarTransferencia(
        cuentaRepository: _cuentaRepository,
        transaccionRepository: _transaccionRepository,
        deudaRepository: _deudaRepository,
      )(transferenciaId: transferenciaId);
      return;
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
