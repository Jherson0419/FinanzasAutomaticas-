import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../repositories/deuda_repository.dart';

/// Mantiene sincronizada la `Deuda` auto-generada y vinculada 1:1 a una
/// cuenta de crédito (Fase 62, ver `RegistrarCuenta`) cada vez que cambia
/// `saldoActual` de esa cuenta por una transacción — gasto, ingreso, ajuste
/// de saldo, edición o eliminación de una transacción. Punto central
/// reutilizado por los 5 casos de uso que tocan `saldoActual`
/// (`calculo_saldo.dart`), para no duplicar este recálculo en cada uno.
///
/// No hace nada si [cuenta] no es de tipo crédito, o si no tiene ninguna
/// `Deuda` vinculada (nunca debería pasar para una cuenta de crédito creada
/// por `RegistrarCuenta`, pero no es asunto de este caso de uso crearla —
/// solo sincroniza la que ya existe).
/// Fase 83 — copia la TCEA de la tarjeta (`Cuenta.tcea`, fracción anual) a
/// la deuda vinculada: `tasaInteres` en PORCENTAJE (así lo guarda `Deuda`
/// y lo lee `tasaEfectivaAnual`) y `tieneInteres`. Sin TCEA, la deuda
/// queda sin tasa (`tasaEfectivaAnual` → null, "Falta la tasa").
///
/// Aproximación (documentada en CONTEXTO.md): la TCEA se aplica al saldo
/// usado completo, aunque la tarjeta solo cobre interés sobre lo que no se
/// paga completo en la fecha de pago.
///
/// Fase 84: también copia [pagoMinimo] de la cuenta (si lo tiene), para que
/// el plan de pago use el mínimo real de la tarjeta en vez de 0.
Deuda deudaConTceaDeTarjeta(Deuda deuda, double? tcea, {double? pagoMinimo}) {
  final conMinimo = deuda.copyWith(pagoMinimo: pagoMinimo);
  return tcea == null
      ? conMinimo.copyWith(tieneInteres: false, sinTasaInteres: true)
      : conMinimo.copyWith(tieneInteres: tcea > 0, tasaInteres: tcea * 100);
}

class SincronizarDeudaTarjeta {
  final DeudaRepository _deudaRepository;

  SincronizarDeudaTarjeta({required DeudaRepository deudaRepository})
    : _deudaRepository = deudaRepository;

  Future<void> call(Cuenta cuenta) async {
    if (cuenta.tipo != TipoCuenta.credito) return;

    final deudas = await _deudaRepository.obtenerTodas();
    for (final deuda in deudas) {
      if (deuda.cuentaId != cuenta.id) continue;

      final montoUsado = cuenta.saldoActual < 0
          ? cuenta.saldoActual.abs()
          : 0.0;
      final lineaTotal = cuenta.lineaCredito ?? 0.0;
      await _deudaRepository.actualizar(
        deudaConTceaDeTarjeta(
          deuda.copyWith(
            montoTotal: lineaTotal,
            montoPagado: lineaTotal - montoUsado,
          ),
          cuenta.tcea,
          pagoMinimo: cuenta.pagoMinimo,
        ),
      );
      return;
    }
  }
}
