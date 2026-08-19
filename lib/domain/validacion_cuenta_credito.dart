import 'entities/cuenta.dart';

/// Compartida por `RegistrarCuenta` y `EditarCuenta` (Fase 29):
/// `lineaCredito`/`diaCorte`/`diaPago` son obligatorios cuando
/// `tipo == credito` y deben quedar en `null` para cualquier otro tipo.
void validarCamposDeCredito({
  required TipoCuenta tipo,
  required double? lineaCredito,
  required int? diaCorte,
  required int? diaPago,
}) {
  if (tipo == TipoCuenta.credito) {
    if (lineaCredito == null) {
      throw ArgumentError(
        'lineaCredito es obligatorio para cuentas de crédito',
      );
    }
    if (diaCorte == null) {
      throw ArgumentError('diaCorte es obligatorio para cuentas de crédito');
    }
    if (diaPago == null) {
      throw ArgumentError('diaPago es obligatorio para cuentas de crédito');
    }
    if (diaCorte < 1 || diaCorte > 31) {
      throw ArgumentError('diaCorte debe estar entre 1 y 31');
    }
    if (diaPago < 1 || diaPago > 31) {
      throw ArgumentError('diaPago debe estar entre 1 y 31');
    }
  } else {
    if (lineaCredito != null || diaCorte != null || diaPago != null) {
      throw ArgumentError(
        'lineaCredito/diaCorte/diaPago solo aplican a cuentas de crédito',
      );
    }
  }
}
