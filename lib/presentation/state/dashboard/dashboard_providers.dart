import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
