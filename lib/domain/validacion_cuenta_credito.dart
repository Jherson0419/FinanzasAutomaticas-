import 'entities/cuenta.dart';

/// Compartida por `RegistrarCuenta` y `EditarCuenta` (Fase 29; `fechaCorte`/
/// `fechaPago` reemplazan a `diaCorte`/`diaPago` en la Fase 62):
/// `lineaCredito`/`fechaCorte`/`fechaPago` son obligatorios cuando
/// `tipo == credito` y deben quedar en `null` para cualquier otro tipo.
/// `pagoMinimo` (Fase 65) sigue la misma regla de "solo crédito", pero a
/// diferencia de los otros 3 es opcional incluso ahí — no se exige, para no
/// forzar un dato que muchas cuentas (sobre todo las ya existentes antes de
/// esta fase) todavía no tienen.
void validarCamposDeCredito({
  required TipoCuenta tipo,
  required double? lineaCredito,
  required DateTime? fechaCorte,
  required DateTime? fechaPago,
  required double? pagoMinimo,
}) {
  if (tipo == TipoCuenta.credito) {
    if (lineaCredito == null) {
      throw ArgumentError(
        'lineaCredito es obligatorio para cuentas de crédito',
      );
    }
    if (fechaCorte == null) {
      throw ArgumentError('fechaCorte es obligatorio para cuentas de crédito');
    }
    if (fechaPago == null) {
      throw ArgumentError('fechaPago es obligatorio para cuentas de crédito');
    }
  } else {
    if (lineaCredito != null ||
        fechaCorte != null ||
        fechaPago != null ||
        pagoMinimo != null) {
      throw ArgumentError(
        'lineaCredito/fechaCorte/fechaPago/pagoMinimo solo aplican a cuentas '
        'de crédito',
      );
    }
  }
}
