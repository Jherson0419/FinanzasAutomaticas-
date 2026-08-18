import '../repositories/auth_repository.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';

/// Borra permanentemente la cuenta del usuario (Fase 22, requisito de
/// Apple — Guideline 5.1.1(v)): primero todos sus datos financieros en
/// Supabase, y solo si eso termina sin errores, la cuenta de
/// autenticación. `MiPerfilScreen` es responsable de limpiar después las
/// preferencias locales (`PreferenciasRepository.limpiarTodo`) y navegar al
/// login — este caso de uso no toca nada local a propósito, igual que
/// `MigrarDatosALaNube` no toca nada de Drift.
///
/// Orden de borrado: el inverso exacto de `MigrarDatosALaNube` (que sube
/// cuentas → categorías propias → deudas → transacciones → pagos), para
/// respetar las mismas dependencias por FK: pagos de deuda → transacciones
/// → deudas → categorías propias → cuentas. Recién al final, la cuenta de
/// auth.
///
/// Diseño idempotente a propósito: si un paso falla a mitad de camino, no
/// hay ningún "deshacer" — un reintento simplemente vuelve a listar lo que
/// quede (ya sin lo que se alcanzó a borrar) y continúa. Así nunca hace
/// falta lógica de compensación, y nunca se llega a borrar la cuenta de
/// auth mientras todavía queden datos financieros sin borrar.
class EliminarCuentaDeUsuario {
  final CuentaRepository _cuentaRepository;
  final CategoriaRepository _categoriaRepository;
  final DeudaRepository _deudaRepository;
  final TransaccionRepository _transaccionRepository;
  final PagoDeudaRepository _pagoDeudaRepository;
  final AuthRepository _authRepository;

  EliminarCuentaDeUsuario({
    required CuentaRepository cuentaRepository,
    required CategoriaRepository categoriaRepository,
    required DeudaRepository deudaRepository,
    required TransaccionRepository transaccionRepository,
    required PagoDeudaRepository pagoDeudaRepository,
    required AuthRepository authRepository,
  }) : _cuentaRepository = cuentaRepository,
       _categoriaRepository = categoriaRepository,
       _deudaRepository = deudaRepository,
       _transaccionRepository = transaccionRepository,
       _pagoDeudaRepository = pagoDeudaRepository,
       _authRepository = authRepository;

  Future<void> call({void Function(String etapa)? onProgreso}) async {
    onProgreso?.call('Borrando pagos de deuda...');
    final deudas = await _deudaRepository.obtenerTodas();
    for (final deuda in deudas) {
      final pagos = await _pagoDeudaRepository.obtenerPorDeuda(deuda.id);
      for (final pago in pagos) {
        await _pagoDeudaRepository.eliminar(pago.id);
      }
    }

    onProgreso?.call('Borrando transacciones...');
    final transacciones = await _transaccionRepository.obtenerTodas();
    for (final transaccion in transacciones) {
      await _transaccionRepository.eliminar(transaccion.id);
    }

    onProgreso?.call('Borrando deudas...');
    for (final deuda in deudas) {
      await _deudaRepository.eliminar(deuda.id);
    }

    onProgreso?.call('Borrando categorías...');
    final categoriasPropias = (await _categoriaRepository.obtenerTodas())
        .where((c) => !c.esPredeterminada)
        .toList();
    for (final categoria in categoriasPropias) {
      await _categoriaRepository.eliminar(categoria.id);
    }

    onProgreso?.call('Borrando cuentas...');
    final cuentas = await _cuentaRepository.obtenerTodas();
    for (final cuenta in cuentas) {
      await _cuentaRepository.eliminar(cuenta.id);
    }

    onProgreso?.call('Eliminando la cuenta...');
    await _authRepository.eliminarCuenta();
  }
}
