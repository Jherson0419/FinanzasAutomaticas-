import '../repositories/notificacion_repository.dart';
import '../repositories/preferencias_repository.dart';
import '../urgencia_deuda.dart';
import 'dto/notificacion_vencimiento_pendiente.dart';
import 'dto/resumen_dashboard.dart';

/// Genera notificaciones de "cuota por vencer"/"cuota vencida" (Fase 70) a
/// partir de `ResumenDashboard.deudasActivas`, que `resumenDashboardProvider`
/// ya calcula en cada carga del dashboard — reutiliza ese mismo resultado
/// en vez de volver a pedirlo, así esta llamada nunca implica una consulta
/// extra a `DeudaRepository`/`CuentaRepository`.
///
/// Idempotente del lado del servidor (el RPC `generar_notificaciones_
/// vencimiento` decide qué ya existe), pero además se limita a como mucho
/// una vez por día del lado del cliente (`PreferenciasRepository.
/// ultimaGeneracionNotificacionesVencimiento`) para no llamar al RPC en
/// cada apertura del dashboard sin necesidad — la fecha de vencimiento de
/// una deuda no cambia entre una apertura y la siguiente el mismo día.
class GenerarNotificacionesVencimiento {
  final NotificacionRepository _notificacionRepository;
  final PreferenciasRepository _preferenciasRepository;

  GenerarNotificacionesVencimiento({
    required NotificacionRepository notificacionRepository,
    required PreferenciasRepository preferenciasRepository,
  }) : _notificacionRepository = notificacionRepository,
       _preferenciasRepository = preferenciasRepository;

  Future<void> call(List<DeudaActivaResumen> deudasActivas, {DateTime? ahora}) async {
    final hoy = ahora ?? DateTime.now();

    final ultimaGeneracion = await _preferenciasRepository
        .ultimaGeneracionNotificacionesVencimiento();
    if (ultimaGeneracion != null && _esMismoDia(ultimaGeneracion, hoy)) return;

    final items = <NotificacionVencimientoPendiente>[
      for (final deuda in deudasActivas)
        if (_tipoNotificacion(deuda, hoy) case final tipo?)
          NotificacionVencimientoPendiente(
            deudaId: deuda.id,
            fecha: DateTime(
              deuda.fechaVencimientoReal!.year,
              deuda.fechaVencimientoReal!.month,
              deuda.fechaVencimientoReal!.day,
            ),
            tipo: tipo,
          ),
    ];

    if (items.isNotEmpty) {
      await _notificacionRepository.generarNotificacionesVencimiento(items);
    }
    await _preferenciasRepository.guardarUltimaGeneracionNotificacionesVencimiento(
      hoy,
    );
  }

  /// `null` si la deuda no debe notificarse: normal, o sin
  /// `fechaVencimientoReal` (una `pagoLibre` sin cuenta vinculada, o una
  /// `enMora` sin fecha real — mismo límite ya documentado en la Fase 68
  /// para el orden/color de "Deudas activas").
  String? _tipoNotificacion(DeudaActivaResumen deuda, DateTime ahora) {
    if (deuda.fechaVencimientoReal == null) return null;
    return switch (urgenciaDeuda(deuda, ahora)) {
      UrgenciaDeuda.vencida => 'cuota_vencida',
      UrgenciaDeuda.porVencer => 'cuota_por_vencer',
      UrgenciaDeuda.normal => null,
    };
  }

  bool _esMismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
