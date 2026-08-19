import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return obtenerResumenDashboard();
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
