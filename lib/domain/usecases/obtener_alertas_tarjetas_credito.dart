import '../entities/cuenta.dart';
import '../proxima_fecha_dia_mes.dart';
import '../repositories/cuenta_repository.dart';
import 'dto/alerta_tarjeta_credito.dart';

/// Recorre las cuentas tipo `credito` y marca una alerta cuando la próxima
/// fecha de corte o de pago está a 3 días o menos (Fase 29). Se ejecuta
/// automáticamente al cargar el dashboard, mismo patrón que
/// `ActualizarEstadoMora` (`resumenDashboardProvider`).
class ObtenerAlertasTarjetasCredito {
  static const _umbralDias = 3;

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

      final diaCorte = cuenta.diaCorte;
      if (diaCorte != null) {
        final alerta = _alertaSiAplica(
          cuenta,
          TipoAlertaTarjeta.corte,
          diaCorte,
          hoy,
        );
        if (alerta != null) alertas.add(alerta);
      }

      final diaPago = cuenta.diaPago;
      if (diaPago != null) {
        final alerta = _alertaSiAplica(
          cuenta,
          TipoAlertaTarjeta.pago,
          diaPago,
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
    int diaDelMes,
    DateTime hoy,
  ) {
    final fecha = proximaFecha(diaDelMes, hoy);
    final diasRestantes = fecha.difference(hoy).inDays;
    if (diasRestantes > _umbralDias) return null;
    return AlertaTarjetaCredito(
      cuentaId: cuenta.id,
      nombreCuenta: cuenta.nombre,
      tipo: tipo,
      fecha: fecha,
      diasRestantes: diasRestantes,
    );
  }
}
