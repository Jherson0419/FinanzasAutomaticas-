import '../entities/cuenta.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import '../validacion_cuenta_credito.dart';

/// Edita nombre, tipo, moneda y los campos de tarjeta de crédito
/// (`lineaCredito`/`diaCorte`/`diaPago`, Fase 29) de una cuenta. Nunca toca
/// `saldoActual` — se deriva automáticamente de transacciones y pagos.
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
    double? lineaCredito,
    int? diaCorte,
    int? diaPago,
    String? ultimosDigitos,
  }) async {
    validarCamposDeCredito(
      tipo: tipo,
      lineaCredito: lineaCredito,
      diaCorte: diaCorte,
      diaPago: diaPago,
    );

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

    // Reconstrucción directa (no `copyWith`): al dejar de ser `credito`,
    // `lineaCredito`/`diaCorte`/`diaPago` deben volver a `null`, y el
    // patrón `campo ?? this.campo` de `copyWith` no permite anular un
    // campo — mismo tema documentado en `Deuda.copyWith`.
    final actualizada = Cuenta(
      id: actual.id,
      nombre: nombre,
      tipo: tipo,
      moneda: moneda,
      saldoActual: actual.saldoActual,
      lineaCredito: lineaCredito,
      diaCorte: diaCorte,
      diaPago: diaPago,
      ultimosDigitos: ultimosDigitos,
    );
    await _cuentaRepository.actualizar(actualizada);
    return actualizada;
  }
}
