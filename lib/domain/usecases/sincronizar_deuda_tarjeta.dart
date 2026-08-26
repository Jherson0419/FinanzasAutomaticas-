import '../entities/cuenta.dart';
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
        deuda.copyWith(montoTotal: lineaTotal, montoPagado: lineaTotal - montoUsado),
      );
      return;
    }
  }
}
