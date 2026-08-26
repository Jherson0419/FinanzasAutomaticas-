import 'package:uuid/uuid.dart';

import '../calculo_saldo.dart';
import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'sincronizar_deuda_tarjeta.dart';

class RegistrarGasto {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final SincronizarDeudaTarjeta _sincronizarDeudaTarjeta;
  final Uuid _uuid;

  RegistrarGasto({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required DeudaRepository deudaRepository,
    Uuid? uuid,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _sincronizarDeudaTarjeta = SincronizarDeudaTarjeta(
         deudaRepository: deudaRepository,
       ),
       _uuid = uuid ?? const Uuid();

  Future<Transaccion> call({
    required String cuentaId,
    required String categoriaId,
    required double monto,
    required Moneda moneda,
    required String concepto,
    required MetodoPago metodoPago,
    bool esRecurrente = false,
    String? comprobanteUrl,
    DateTime? fecha,
  }) async {
    final cuenta = await _cuentaRepository.obtenerPorId(cuentaId);
    if (cuenta == null) {
      throw ArgumentError('La cuenta $cuentaId no existe');
    }

    final transaccion = Transaccion(
      id: _uuid.v4(),
      cuentaId: cuentaId,
      categoriaId: categoriaId,
      monto: monto,
      moneda: moneda,
      tipo: TipoTransaccion.gasto,
      concepto: concepto,
      metodoPago: metodoPago,
      esRecurrente: esRecurrente,
      comprobanteUrl: comprobanteUrl,
      fuenteCaptura: FuenteCaptura.manual,
      dataRaw: null,
      fecha: fecha ?? DateTime.now(),
    );

    await _transaccionRepository.crear(transaccion);
    final cuentaActualizada = cuenta.copyWith(
      saldoActual: aplicarEfectoTransaccion(
        cuenta.saldoActual,
        TipoTransaccion.gasto,
        monto,
      ),
    );
    await _cuentaRepository.actualizar(cuentaActualizada);
    await _sincronizarDeudaTarjeta(cuentaActualizada);

    return transaccion;
  }
}
