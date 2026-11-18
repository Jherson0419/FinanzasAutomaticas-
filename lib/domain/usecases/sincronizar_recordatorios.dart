import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../recordatorios.dart';
import '../repositories/notificaciones_locales_repository.dart';

/// Resultado de una sincronización.
enum ResultadoSincronizacion {
  /// Programados según la configuración.
  programados,

  /// Nada activo: se cancelaron los que hubiera.
  nadaActivo,

  /// Hay opciones activas pero el permiso no está concedido: no se
  /// programa nada (y se cancelan los que quedaran).
  sinPermiso,
}

/// Deja programados exactamente los recordatorios que corresponden HOY
/// (Fase 87). Se llama al abrir la app y cada vez que cambian las deudas o
/// la configuración: lo que ya no corresponde (p. ej. la cuota que
/// acabas de pagar) se cancela. Nunca pide permiso: eso solo ocurre cuando
/// el usuario activa una opción.
class SincronizarRecordatorios {
  final NotificacionesLocalesRepository _notificaciones;

  SincronizarRecordatorios(this._notificaciones);

  Future<ResultadoSincronizacion> call({
    required List<Deuda> deudas,
    required List<Cuenta> cuentas,
    required DateTime ahora,
    required ConfigRecordatorios config,
  }) async {
    final pendientes = await _notificaciones.pendientes();
    Future<void> cancelarTodo() async {
      for (final id in pendientes) {
        await _notificaciones.cancelar(id);
      }
    }

    if (!config.algoActivo) {
      await cancelarTodo();
      return ResultadoSincronizacion.nadaActivo;
    }
    if (await _notificaciones.estadoPermiso() !=
        EstadoPermisoNotificaciones.concedido) {
      await cancelarTodo();
      return ResultadoSincronizacion.sinPermiso;
    }
    final plan = planSincronizacion(
      pendientes,
      calcularRecordatorios(
        deudas: deudas,
        cuentas: cuentas,
        ahora: ahora,
        config: config,
      ),
    );
    for (final id in plan.cancelar) {
      await _notificaciones.cancelar(id);
    }
    for (final r in plan.programar) {
      await _notificaciones.programar(r);
    }
    return ResultadoSincronizacion.programados;
  }
}
