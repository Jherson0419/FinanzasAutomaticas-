import '../../entities/cuenta.dart';
import '../../entities/deuda.dart';
import '../../entities/transaccion.dart';

class SaldoCuenta {
  final String id;
  final String nombre;
  final Moneda moneda;
  final double saldoActual;

  const SaldoCuenta({
    required this.id,
    required this.nombre,
    required this.moneda,
    required this.saldoActual,
  });
}

class GastoPorCategoria {
  final String categoriaId;
  final String nombre;
  final String iconName;
  final Moneda moneda;
  final double monto;
  final double porcentajeDelTotal;

  const GastoPorCategoria({
    required this.categoriaId,
    required this.nombre,
    required this.iconName,
    required this.moneda,
    required this.monto,
    required this.porcentajeDelTotal,
  });
}

class DeudaActivaResumen {
  final String id;
  final String nombreDeuda;
  final EstructuraPago estructuraPago;
  final DateTime? proximaFechaPago;
  final bool enMora;
  final int? diasMora;
  final double montoPagado;
  final double montoTotal;
  final double? montoCuota;
  final Moneda moneda;

  const DeudaActivaResumen({
    required this.id,
    required this.nombreDeuda,
    required this.estructuraPago,
    required this.proximaFechaPago,
    required this.enMora,
    required this.diasMora,
    required this.montoPagado,
    required this.montoTotal,
    required this.montoCuota,
    required this.moneda,
  });

  double get progreso => montoTotal == 0
      ? 0
      : (montoPagado / montoTotal).clamp(0.0, 1.0).toDouble();
}

class MovimientoReciente {
  final String id;
  final String concepto;
  final double monto;
  final Moneda moneda;
  final TipoTransaccion tipo;
  final String categoriaNombre;
  final String categoriaIconName;
  final FuenteCaptura fuenteCaptura;
  final DateTime fecha;

  const MovimientoReciente({
    required this.id,
    required this.concepto,
    required this.monto,
    required this.moneda,
    required this.tipo,
    required this.categoriaNombre,
    required this.categoriaIconName,
    required this.fuenteCaptura,
    required this.fecha,
  });
}

class ResumenDashboard {
  final List<SaldoCuenta> saldosPorCuenta;
  final Map<Moneda, double> saldoTotalPorMoneda;
  final Map<Moneda, double> ingresosMesPorMoneda;
  final Map<Moneda, double> gastosMesPorMoneda;
  final List<GastoPorCategoria> gastoPorCategoriaMes;
  final List<DeudaActivaResumen> deudasActivas;
  final Map<Moneda, double> totalAdeudadoPorMoneda;
  final List<MovimientoReciente> movimientosRecientes;

  const ResumenDashboard({
    required this.saldosPorCuenta,
    required this.saldoTotalPorMoneda,
    required this.ingresosMesPorMoneda,
    required this.gastosMesPorMoneda,
    required this.gastoPorCategoriaMes,
    required this.deudasActivas,
    required this.totalAdeudadoPorMoneda,
    required this.movimientosRecientes,
  });

  int get deudasEnMoraCount => deudasActivas.where((d) => d.enMora).length;

  int get deudasPorVencerEstaSemanaCount {
    final ahora = DateTime.now();
    final limite = ahora.add(const Duration(days: 7));
    return deudasActivas.where((d) {
      if (d.enMora) return false;
      final fecha = d.proximaFechaPago;
      if (fecha == null) return false;
      return !fecha.isBefore(ahora) && !fecha.isAfter(limite);
    }).length;
  }

  bool get estaVacio =>
      saldosPorCuenta.isEmpty &&
      movimientosRecientes.isEmpty &&
      deudasActivas.isEmpty;
}
