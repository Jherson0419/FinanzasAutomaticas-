import '../calculo_saldo.dart';
import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'sincronizar_deuda_tarjeta.dart';

class EditarTransaccion {
  final TransaccionRepository _transaccionRepository;
  final CuentaRepository _cuentaRepository;
  final SincronizarDeudaTarjeta _sincronizarDeudaTarjeta;

  EditarTransaccion({
    required TransaccionRepository transaccionRepository,
    required CuentaRepository cuentaRepository,
    required DeudaRepository deudaRepository,
  }) : _transaccionRepository = transaccionRepository,
       _cuentaRepository = cuentaRepository,
       _sincronizarDeudaTarjeta = SincronizarDeudaTarjeta(
         deudaRepository: deudaRepository,
       );

  Future<Transaccion> call({
    required String transaccionId,
    required String cuentaId,
    required String categoriaId,
    required double monto,
    required Moneda moneda,
    required TipoTransaccion tipo,
    required String concepto,
    required MetodoPago metodoPago,
    bool esRecurrente = false,
    String? comprobanteUrl,
    DateTime? fecha,
  }) async {
    final anterior = await _transaccionRepository.obtenerPorId(transaccionId);
    if (anterior == null) {
      throw ArgumentError('La transacción $transaccionId no existe');
    }

    final cuentaAnterior = await _cuentaRepository.obtenerPorId(
      anterior.cuentaId,
    );
    if (cuentaAnterior == null) {
      throw ArgumentError('La cuenta ${anterior.cuentaId} no existe');
    }
    final saldoRevertido = revertirEfectoTransaccion(
      cuentaAnterior.saldoActual,
      anterior.tipo,
      anterior.monto,
    );

    if (cuentaId == anterior.cuentaId) {
      final saldoFinal = aplicarEfectoTransaccion(saldoRevertido, tipo, monto);
      final cuentaActualizada = cuentaAnterior.copyWith(
        saldoActual: saldoFinal,
      );
      await _cuentaRepository.actualizar(cuentaActualizada);
      await _sincronizarDeudaTarjeta(cuentaActualizada);
    } else {
      final cuentaAnteriorActualizada = cuentaAnterior.copyWith(
        saldoActual: saldoRevertido,
      );
      await _cuentaRepository.actualizar(cuentaAnteriorActualizada);
      await _sincronizarDeudaTarjeta(cuentaAnteriorActualizada);

      final cuentaNueva = await _cuentaRepository.obtenerPorId(cuentaId);
      if (cuentaNueva == null) {
        throw ArgumentError('La cuenta $cuentaId no existe');
      }
      final saldoNuevoFinal = aplicarEfectoTransaccion(
        cuentaNueva.saldoActual,
        tipo,
        monto,
      );
      final cuentaNuevaActualizada = cuentaNueva.copyWith(
        saldoActual: saldoNuevoFinal,
      );
      await _cuentaRepository.actualizar(cuentaNuevaActualizada);
      await _sincronizarDeudaTarjeta(cuentaNuevaActualizada);
    }

    final actualizada = Transaccion(
      id: transaccionId,
      cuentaId: cuentaId,
      categoriaId: categoriaId,
      monto: monto,
      moneda: moneda,
      tipo: tipo,
      concepto: concepto,
      metodoPago: metodoPago,
      esRecurrente: esRecurrente,
      comprobanteUrl: comprobanteUrl,
      fuenteCaptura: anterior.fuenteCaptura,
      dataRaw: anterior.dataRaw,
      fecha: fecha ?? anterior.fecha,
    );

    await _transaccionRepository.actualizar(actualizada);
    return actualizada;
  }
}
