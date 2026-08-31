import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/deuda.dart';
import '../../../domain/usecases/dto/alerta_tarjeta_credito.dart';
import '../../../domain/usecases/dto/resumen_dashboard.dart';
import '../providers.dart';

final resumenDashboardProvider = FutureProvider<ResumenDashboard>((ref) async {
  final actualizarEstadoMora = ref.watch(actualizarEstadoMoraProvider);
  try {
    await actualizarEstadoMora();
  } catch (error) {
    // No bloquea el dashboard si falla: el usuario prefiere ver el
    // dashboard sin la mora recién actualizada que no ver nada.
    debugPrint('ActualizarEstadoMora falló: $error');
  }

  final obtenerResumenDashboard = ref.watch(obtenerResumenDashboardProvider);
  final resumen = await obtenerResumenDashboard();

  // Fase 70 — reutiliza `resumen.deudasActivas` (ya calculado arriba, con
  // `fechaVencimientoReal`/`enMora` incluidos desde la Fase 68) para
  // generar notificaciones de cuota por vencer/vencida, como mucho una vez
  // por día (`GenerarNotificacionesVencimiento` se encarga de esa
  // condición). No bloquea el dashboard si falla, mismo criterio que
  // `ActualizarEstadoMora` arriba.
  try {
    final generarNotificacionesVencimiento = ref.watch(
      generarNotificacionesVencimientoProvider,
    );
    await generarNotificacionesVencimiento(resumen.deudasActivas);
  } catch (error) {
    // `ref.watch(generarNotificacionesVencimientoProvider)` va DENTRO del
    // `try` a propósito, no solo la llamada: construye
    // `NotificacionRepositorySupabase(Supabase.instance.client)`, que
    // lanza un `AssertionError` síncrono sin `Supabase.initialize()` real
    // (tests de widgets que montan `DashboardScreen` sin haber
    // overriden este provider) — mismo motivo que ya documentó la Fase 63
    // para `notificacionesNoLeidasProvider`.
    debugPrint('GenerarNotificacionesVencimiento falló: $error');
  }

  return resumen;
});

/// Alertas de corte/pago de tarjetas de crédito (Fase 29) — mismo patrón
/// que `resumenDashboardProvider`/`ActualizarEstadoMora`: se dispara solo
/// con que `DashboardScreen` lo observe, sin acción del usuario. Es un
/// `FutureProvider` propio (no un campo más de `ResumenDashboard`) porque,
/// a diferencia de `ActualizarEstadoMora`, no escribe nada — es una lectura
/// derivada de las cuentas que puede cachearse/invalidarse por separado.
final alertasTarjetasCreditoProvider =
    FutureProvider<List<AlertaTarjetaCredito>>((ref) {
      final obtenerAlertas = ref.watch(obtenerAlertasTarjetasCreditoProvider);
      return obtenerAlertas();
    });

/// "Te deben" (Fase 68) — deudas de otros usuarios vinculadas a mí como
/// amigo. `TeDebenSection` resuelve el nick del deudor por su cuenta (vía
/// `amigosProvider`, ya cargado para la propia lista de amigos) en vez de
/// que este provider dependa de `AmistadRepository` — el deudor siempre es
/// alguien con quien ya soy amigo aceptado (si no, la fila no podría tener
/// mi `usuario_id` en `amigo_usuario_id`), así que ya está en esa lista.
final deudasQueMeDebenProvider = FutureProvider<List<DeudaDeAmigo>>((ref) {
  return ref.watch(deudaRepositoryProvider).obtenerDeudasDondeSoyElAmigo();
});
