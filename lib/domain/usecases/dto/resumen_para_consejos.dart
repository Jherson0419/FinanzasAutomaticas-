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

/// Resumen financiero **agregado y anonimizado**: sin nombres de cuentas,
/// sin `nombreDeuda`/`nombreAcreedor`. Es lo único que sale de este
/// dispositivo al pedir consejos financieros a Gemini.
class ResumenParaConsejos {
  final List<DeudaParaConsejos> deudasActivas;
  final List<CategoriaMontoConsejo> ingresosPorCategoriaMes;
  final List<CategoriaMontoConsejo> gastosPorCategoriaMes;
  final Map<Moneda, double> saldoTotalPorMoneda;

  const ResumenParaConsejos({
    required this.deudasActivas,
    required this.ingresosPorCategoriaMes,
    required this.gastosPorCategoriaMes,
    required this.saldoTotalPorMoneda,
  });
}
