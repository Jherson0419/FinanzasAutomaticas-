import '../entities/cuenta.dart';
import '../proxima_ocurrencia_mensual.dart';
import '../repositories/cuenta_repository.dart';
import '../umbral_alerta_vencimiento.dart';
import 'dto/alerta_tarjeta_credito.dart';

/// Recorre las cuentas tipo `credito` y marca una alerta cuando la próxima
/// fecha de corte o de pago está a 3 días o menos (Fase 29; `fechaCorte`/
/// `fechaPago` completas en vez de solo el día del mes desde la Fase 62).
/// Se ejecuta automáticamente al cargar el dashboard, mismo patrón que
/// `ActualizarEstadoMora` (`resumenDashboardProvider`). El umbral
/// (`umbralDiasAlertaVencimiento`) es compartido con el orden/color de
/// "Deudas activas" por vencimiento (Fase 68) — un solo lugar donde vive el
/// criterio de "3 días o menos".
class ObtenerAlertasTarjetasCredito {
  final CuentaRepository _cuentaRepository;

  ObtenerAlertasTarjetasCredito({required CuentaRepository cuentaRepository})
    : _cuentaRepository = cuentaRepository;

  Future<List<AlertaTarjetaCredito>> call() async {
    final cuentas = await _cuentaRepository.obtenerTodas();
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    final alertas = <AlertaTarjetaCredito>[];
    for (final cuenta in cuentas) {
      if (cuenta.tipo != TipoCuenta.credito) continue;

      final fechaCorte = cuenta.fechaCorte;
      if (fechaCorte != null) {
        final alerta = _alertaSiAplica(
          cuenta,
          TipoAlertaTarjeta.corte,
          fechaCorte,
          hoy,
        );
        if (alerta != null) alertas.add(alerta);
      }

      final fechaPago = cuenta.fechaPago;
      if (fechaPago != null) {
        final alerta = _alertaSiAplica(
          cuenta,
          TipoAlertaTarjeta.pago,
          fechaPago,
          hoy,
        );
        if (alerta != null) alertas.add(alerta);
      }
    }
    return alertas;
  }

  AlertaTarjetaCredito? _alertaSiAplica(
    Cuenta cuenta,
    TipoAlertaTarjeta tipo,
    DateTime ancla,
    DateTime hoy,
  ) {
    final fecha = proximaOcurrenciaMensual(ancla, hoy);
    final diasRestantes = fecha.difference(hoy).inDays;
    if (diasRestantes > umbralDiasAlertaVencimiento) return null;
    return AlertaTarjetaCredito(
      cuentaId: cuenta.id,
      nombreCuenta: cuenta.nombre,
      tipo: tipo,
      fecha: fecha,
      diasRestantes: diasRestantes,
    );
  }
}
