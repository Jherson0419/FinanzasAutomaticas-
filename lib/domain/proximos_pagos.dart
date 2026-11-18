import 'entities/cuenta.dart';
import 'urgencia_deuda.dart';
import 'usecases/dto/resumen_dashboard.dart';

/// Orden de las deudas activas para "Próximos pagos" (Inicio) y el hub de
/// Deudas (Fase 81): primero por urgencia (`ordenarDeudasActivasPorVencimiento`,
/// vencidas → por vencer → resto) y, dentro de cada grupo, por fecha de
/// vencimiento real ascendente con las deudas sin fecha al final. Estable:
/// a igual urgencia y fecha se conserva el orden de entrada.
List<DeudaActivaResumen> ordenarPorUrgenciaYFecha(
  List<DeudaActivaResumen> deudas,
  DateTime ahora,
) {
  final porUrgencia = ordenarDeudasActivasPorVencimiento(deudas, ahora);
  final indexada = [
    for (var i = 0; i < porUrgencia.length; i++) (i, porUrgencia[i]),
  ];
  int rango(DeudaActivaResumen d) => switch (urgenciaDeuda(d, ahora)) {
    UrgenciaDeuda.vencida => 0,
    UrgenciaDeuda.porVencer => 1,
    UrgenciaDeuda.normal => 2,
  };
  indexada.sort((a, b) {
    final porRango = rango(a.$2).compareTo(rango(b.$2));
    if (porRango != 0) return porRango;
    final fa = a.$2.fechaVencimientoReal;
    final fb = b.$2.fechaVencimientoReal;
    if (fa != null && fb != null) {
      final porFecha = fa.compareTo(fb);
      if (porFecha != 0) return porFecha;
    } else if (fa != null) {
      return -1;
    } else if (fb != null) {
      return 1;
    }
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, d) in indexada) d];
}

/// Las [limite] deudas más urgentes (Fase 81, "Próximos pagos").
List<DeudaActivaResumen> proximosPagos(
  List<DeudaActivaResumen> deudas,
  DateTime ahora, {
  int limite = 3,
}) => ordenarPorUrgenciaYFecha(deudas, ahora).take(limite).toList();

/// Progreso de pago de un conjunto de deudas en una moneda (Fase 81).
class ProgresoDeudas {
  final double pagado;
  final double totalAPagar;

  const ProgresoDeudas({required this.pagado, required this.totalAPagar});

  /// Entre 0 y 1; 0 si no hay nada que pagar.
  double get fraccion =>
      totalAPagar <= 0 ? 0 : (pagado / totalAPagar).clamp(0.0, 1.0);

  /// Porcentaje entero para mostrar (redondeo hacia abajo: nunca muestra
  /// "100%" mientras quede algo pendiente).
  int get porcentaje => (fraccion * 100).floor();
}

/// Suma `montoPagado` / `totalAPagar` (Fase 79) de las deudas activas en
/// [moneda]. Excluye la deuda automática de tarjeta de crédito
/// (`cuentaId != null`): ahí `montoPagado` es el crédito disponible, no
/// dinero devuelto, y distorsionaría el porcentaje. No mezcla monedas.
ProgresoDeudas progresoDeudas(List<DeudaActivaResumen> deudas, Moneda moneda) {
  var pagado = 0.0;
  var total = 0.0;
  for (final d in deudas) {
    if (d.moneda != moneda || d.cuentaId != null) continue;
    pagado += d.montoPagado.clamp(0, d.totalAPagar);
    total += d.totalAPagar;
  }
  return ProgresoDeudas(pagado: pagado, totalAPagar: total);
}
