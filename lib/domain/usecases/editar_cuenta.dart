import '../entities/cuenta.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import '../validacion_cuenta_credito.dart';
import 'sincronizar_deuda_tarjeta.dart';

/// Edita nombre, tipo, moneda y los campos de tarjeta de crédito
/// (`lineaCredito`/`fechaCorte`/`fechaPago`, Fase 29/62) de una cuenta.
/// Nunca toca `saldoActual` — se deriva automáticamente de transacciones y
/// pagos.
class EditarCuenta {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final PagoDeudaRepository _pagoDeudaRepository;
  final DeudaRepository _deudaRepository;

  EditarCuenta({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required PagoDeudaRepository pagoDeudaRepository,
    required DeudaRepository deudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _pagoDeudaRepository = pagoDeudaRepository,
       _deudaRepository = deudaRepository;

  Future<Cuenta> call({
    required String cuentaId,
    required String nombre,
    required TipoCuenta tipo,
    required Moneda moneda,
    double? lineaCredito,
    DateTime? fechaCorte,
    DateTime? fechaPago,
    String? ultimosDigitos,
    double? pagoMinimo,
    // Fase 83 — fracción anual; `null` = sin TCEA (se borra si había).
    double? tcea,
  }) async {
    if (tcea != null && tcea < 0) {
      throw ArgumentError('La TCEA no puede ser negativa.');
    }
    validarCamposDeCredito(
      tipo: tipo,
      lineaCredito: lineaCredito,
      fechaCorte: fechaCorte,
      fechaPago: fechaPago,
      pagoMinimo: pagoMinimo,
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
    // `lineaCredito`/`fechaCorte`/`fechaPago` deben volver a `null`, y el
    // patrón `campo ?? this.campo` de `copyWith` no permite anular un
    // campo — mismo tema documentado en `Deuda.copyWith`.
    final actualizada = Cuenta(
      id: actual.id,
      nombre: nombre,
      tipo: tipo,
      moneda: moneda,
      saldoActual: actual.saldoActual,
      lineaCredito: lineaCredito,
      fechaCorte: fechaCorte,
      fechaPago: fechaPago,
      ultimosDigitos: ultimosDigitos,
      pagoMinimo: pagoMinimo,
      tcea: tipo == TipoCuenta.credito ? tcea : null,
    );
    await _cuentaRepository.actualizar(actualizada);

    // Fase 62: si cambió la línea de crédito o el nombre, sincroniza esos
    // mismos cambios en la `Deuda` vinculada (`montoTotal`/`nombreDeuda`) —
    // `montoPagado` (el crédito disponible) se recalcula con el mismo
    // `saldoActual` de siempre, nunca tocado aquí, para no desalinearlo del
    // nuevo `montoTotal`.
    if (tipo == TipoCuenta.credito &&
        (actual.lineaCredito != lineaCredito ||
            actual.nombre != nombre ||
            actual.tcea != actualizada.tcea ||
            actual.pagoMinimo != actualizada.pagoMinimo)) {
      final deudas = await _deudaRepository.obtenerTodas();
      for (final deuda in deudas) {
        if (deuda.cuentaId != cuentaId) continue;
        final montoUsado = actual.saldoActual < 0
            ? actual.saldoActual.abs()
            : 0.0;
        final lineaTotal = lineaCredito ?? 0.0;
        await _deudaRepository.actualizar(
          // Fase 83: también la TCEA (tasaInteres/tieneInteres).
          deudaConTceaDeTarjeta(
            deuda.copyWith(
              nombreDeuda: nombre,
              montoTotal: lineaTotal,
              montoPagado: lineaTotal - montoUsado,
            ),
            actualizada.tcea,
            pagoMinimo: actualizada.pagoMinimo,
          ),
        );
        break;
      }
    }

    return actualizada;
  }
}
