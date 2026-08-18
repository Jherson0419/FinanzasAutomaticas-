import '../calculo_saldo.dart';
import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/transaccion_repository.dart';

class EditarTransaccion {
  final TransaccionRepository _transaccionRepository;
  final CuentaRepository _cuentaRepository;

  EditarTransaccion({
    required TransaccionRepository transaccionRepository,
    required CuentaRepository cuentaRepository,
  }) : _transaccionRepository = transaccionRepository,
       _cuentaRepository = cuentaRepository;

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
      await _cuentaRepository.actualizar(
        cuentaAnterior.copyWith(saldoActual: saldoFinal),
      );
    } else {
      await _cuentaRepository.actualizar(
        cuentaAnterior.copyWith(saldoActual: saldoRevertido),
      );
      final cuentaNueva = await _cuentaRepository.obtenerPorId(cuentaId);
      if (cuentaNueva == null) {
        throw ArgumentError('La cuenta $cuentaId no existe');
      }
      final saldoNuevoFinal = aplicarEfectoTransaccion(
        cuentaNueva.saldoActual,
        tipo,
        monto,
      );
      await _cuentaRepository.actualizar(
        cuentaNueva.copyWith(saldoActual: saldoNuevoFinal),
      );
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
