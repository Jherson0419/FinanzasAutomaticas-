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

  /// `usuario_id` del amigo de Finzo con quien es esta deuda (Fase 64),
  /// `null` para cualquier deuda normal. `DeudasActivasSection` lo resuelve
  /// a un nick vía `amigosProvider` para mostrar "Debo a {nick}" (Fase 68).
  final String? amigoUsuarioId;

  /// Próxima fecha de vencimiento REAL de esta deuda (Fase 68), resuelta
  /// por `ObtenerResumenDashboard`:
  /// - `cuotasFijas` → `proximaFechaPago` tal cual.
  /// - Deuda automática de tarjeta (`cuentaId != null`, Fase 62,
  ///   estructura `pagoLibre`) → la próxima fecha de pago de la `Cuenta`
  ///   vinculada (`proximaOcurrenciaMensual(cuenta.fechaPago, hoy)`), que
  ///   `Deuda.proximaFechaPago` nunca tiene porque esa deuda no usa
  ///   cuotas.
  /// - `pagoLibre` sin cuenta vinculada → `null`, no tiene fecha real.
  ///
  /// Usado por `domain/urgencia_deuda.dart` para ordenar/colorear "Deudas
  /// activas" por urgencia.
  final DateTime? fechaVencimientoReal;

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
    this.amigoUsuarioId,
    this.fechaVencimientoReal,
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
