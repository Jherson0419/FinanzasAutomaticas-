import '../cronograma_cuotas.dart';
import '../entities/deuda.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';

class ActualizarEstadoMora {
  final DeudaRepository _deudaRepository;
  final PagoDeudaRepository _pagoDeudaRepository;

  ActualizarEstadoMora({
    required DeudaRepository deudaRepository,
    required PagoDeudaRepository pagoDeudaRepository,
  }) : _deudaRepository = deudaRepository,
       _pagoDeudaRepository = pagoDeudaRepository;

  Future<void> call({List<Deuda>? deudas}) async {
    final activas = deudas ?? await _deudaRepository.obtenerActivas();
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    for (final deuda in activas) {
      final actualizada = await _recalcular(deuda, hoy);
      if (actualizada != null) await _deudaRepository.actualizar(actualizada);
    }
  }

  Future<Deuda?> _recalcular(Deuda deuda, DateTime hoy) async {
    if (deuda.estructuraPago != EstructuraPago.cuotasFijas) return null;

    final pagos = await _pagoDeudaRepository.obtenerPorDeuda(deuda.id);
    final cronograma = generarCronogramaCuotas(deuda, pagos);
    final proximaFechaPago = proximaFechaPagoDesdeCronograma(cronograma);
    if (proximaFechaPago == null) return null;

    final vencida = proximaFechaPago.isBefore(hoy);
    if (vencida) {
      final diasMora = hoy.difference(proximaFechaPago).inDays;
      final sinCambios =
          deuda.enMora &&
          deuda.diasMora == diasMora &&
          deuda.estado == EstadoDeuda.enMora;
      if (sinCambios) return null;
      return deuda.copyWith(
        enMora: true,
        diasMora: diasMora,
        estado: EstadoDeuda.enMora,
      );
    }
    if (!deuda.enMora) return null;
    return deuda.copyWith(
      enMora: false,
      diasMora: 0,
      estado: EstadoDeuda.activa,
    );
  }
}
