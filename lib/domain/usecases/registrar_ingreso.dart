import 'package:uuid/uuid.dart';

import '../calculo_saldo.dart';
import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/transaccion_repository.dart';

class RegistrarIngreso {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final Uuid _uuid;

  RegistrarIngreso({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    Uuid? uuid,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
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
      tipo: TipoTransaccion.ingreso,
      concepto: concepto,
      metodoPago: metodoPago,
      esRecurrente: esRecurrente,
      comprobanteUrl: comprobanteUrl,
      fuenteCaptura: FuenteCaptura.manual,
      dataRaw: null,
      fecha: fecha ?? DateTime.now(),
    );

    await _transaccionRepository.crear(transaccion);
    await _cuentaRepository.actualizar(
      cuenta.copyWith(
        saldoActual: aplicarEfectoTransaccion(
          cuenta.saldoActual,
          TipoTransaccion.ingreso,
          monto,
        ),
      ),
    );

    return transaccion;
  }
}
