import '../../entities/cuenta.dart';
import '../../entities/deuda.dart';

/// Una deuda activa, reducida a los campos relevantes para pedir consejos
/// financieros — deliberadamente sin `nombreDeuda` ni `nombreAcreedor`: ese
/// resumen puede salir de este dispositivo (hacia la API de Gemini) y no
/// debe llevar nada que identifique al acreedor ni el nombre que el usuario
/// le puso a la deuda.
class DeudaParaConsejos {
  final TipoDeuda tipoDeuda;
  final double montoTotal;
  final double montoPagado;
  final double? interesTotal;
  final Moneda moneda;

  const DeudaParaConsejos({
    required this.tipoDeuda,
    required this.montoTotal,
    required this.montoPagado,
    required this.interesTotal,
    required this.moneda,
  });
}

/// Un monto agregado por categoría (nombre de categoría, no identifica a
/// nadie) y moneda — usado tanto para ingresos como para gastos del mes.
class CategoriaMontoConsejo {
  final String categoriaNombre;
  final double monto;
  final Moneda moneda;

  const CategoriaMontoConsejo({
    required this.categoriaNombre,
    required this.monto,
    required this.moneda,
  });
}

/// Una tarjeta de crédito, reducida a lo relevante para consejos (Fase 60):
/// lo ya usado de la línea es una **deuda propia**, nunca dinero disponible
/// — ver la nota de `saldoTotalPorMoneda` más abajo. Sin identificar la
/// cuenta (mismo criterio de anonimización que `DeudaParaConsejos`).
class TarjetaCreditoParaConsejos {
  final double montoUsado;
  final double lineaTotal;
  final double creditoDisponible;
  final Moneda moneda;

  const TarjetaCreditoParaConsejos({
    required this.montoUsado,
    required this.lineaTotal,
    required this.creditoDisponible,
    required this.moneda,
  });
}

/// Resumen financiero **agregado y anonimizado**: sin nombres de cuentas,
/// sin `nombreDeuda`/`nombreAcreedor`. Es lo único que sale de este
/// dispositivo al pedir consejos financieros a Gemini.
class ResumenParaConsejos {
  final List<DeudaParaConsejos> deudasActivas;
  final List<CategoriaMontoConsejo> ingresosPorCategoriaMes;
  final List<CategoriaMontoConsejo> gastosPorCategoriaMes;

  /// Solo cuentas de débito/efectivo/billetera (Fase 60) — el `saldoActual`
  /// de una tarjeta de crédito NUNCA se suma aquí, aunque sea positivo:
  /// una tarjeta no es una fuente de fondos propios, es una línea prestada
  /// por el banco. Su información va aparte, en [tarjetasCredito].
  final Map<Moneda, double> saldoTotalPorMoneda;

  /// Tarjetas de crédito con línea configurada (Fase 29/60), como
  /// obligación pendiente — nunca como saldo disponible para gastar o para
  /// pagar otras deudas.
  final List<TarjetaCreditoParaConsejos> tarjetasCredito;

  const ResumenParaConsejos({
    required this.deudasActivas,
    required this.ingresosPorCategoriaMes,
    required this.gastosPorCategoriaMes,
    required this.saldoTotalPorMoneda,
    this.tarjetasCredito = const [],
  });
}
