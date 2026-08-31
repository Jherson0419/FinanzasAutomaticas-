import 'umbral_alerta_vencimiento.dart';
import 'usecases/dto/resumen_dashboard.dart';

/// Urgencia de una deuda activa según su próximo vencimiento (Fase 68) —
/// determina tanto el orden como el color en "Deudas activas". Solo aplica
/// a deudas con una fecha de vencimiento real (`DeudaActivaResumen.
/// fechaVencimientoReal` no nulo) además de `enMora`; una `pagoLibre` sin
/// cuenta vinculada nunca sale de `normal`.
enum UrgenciaDeuda { vencida, porVencer, normal }

UrgenciaDeuda urgenciaDeuda(DeudaActivaResumen deuda, DateTime ahora) {
  if (deuda.enMora) return UrgenciaDeuda.vencida;
  final fecha = deuda.fechaVencimientoReal;
  if (fecha == null) return UrgenciaDeuda.normal;
  final diasRestantes = fecha.difference(ahora).inDays;
  if (diasRestantes <= umbralDiasAlertaVencimiento) return UrgenciaDeuda.porVencer;
  return UrgenciaDeuda.normal;
}

/// Reordena "Deudas activas" (Fase 68): vencidas primero, luego por vencer
/// (≤3 días), luego el resto en su orden original. Partición estable en 3
/// grupos en vez de `List.sort` (que no garantiza estabilidad en Dart) —
/// así el orden relativo dentro de cada grupo nunca cambia.
List<DeudaActivaResumen> ordenarDeudasActivasPorVencimiento(
  List<DeudaActivaResumen> deudas,
  DateTime ahora,
) {
  final vencidas = <DeudaActivaResumen>[];
  final porVencer = <DeudaActivaResumen>[];
  final normales = <DeudaActivaResumen>[];
  for (final deuda in deudas) {
    switch (urgenciaDeuda(deuda, ahora)) {
      case UrgenciaDeuda.vencida:
        vencidas.add(deuda);
      case UrgenciaDeuda.porVencer:
        porVencer.add(deuda);
      case UrgenciaDeuda.normal:
        normales.add(deuda);
    }
  }
  return [...vencidas, ...porVencer, ...normales];
}
