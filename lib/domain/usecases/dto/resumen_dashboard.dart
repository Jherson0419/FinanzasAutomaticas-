import 'dart:math' as math;

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
    double? totalAPagar,
    this.cuentaId,
    this.direccion = DireccionDeuda.debo,
  }) : totalAPagar = totalAPagar ?? montoTotal;

  /// Fase 82 — `debo` o `meDeben`.
  final DireccionDeuda direccion;

  /// Fase 81: cuenta de crédito vinculada (deuda automática de tarjeta,
  /// Fase 62) o `null`. El progreso de pago de "Tus deudas" la excluye: en
  /// esas deudas `montoPagado` es el crédito disponible, no lo devuelto.
  final String? cuentaId;

  /// Lo que hay que pagar en total (Fase 79, ver `domain/saldo_deuda.dart`):
  /// en cuotas fijas, cuota × número de cuotas (capital + interés); si no,
  /// [montoTotal]. Opcional en el constructor solo para no romper a quien
  /// arma este DTO a mano (fixtures/tests) — `ObtenerResumenDashboard`
  /// siempre lo pasa.
  final double totalAPagar;

  /// `max(totalAPagar − montoPagado, 0)`.
  double get saldoPendiente =>
      math.max(totalAPagar - montoPagado, 0).toDouble();

  double get progreso => totalAPagar == 0
      ? 0
      : (montoPagado / totalAPagar).clamp(0.0, 1.0).toDouble();
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

  /// Fase 85 — no `null` si el movimiento es una transferencia.
  final String? transferenciaId;

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
    this.transferenciaId,
  });
}

class ResumenDashboard {
  final List<SaldoCuenta> saldosPorCuenta;
  final Map<Moneda, double> saldoTotalPorMoneda;
  final Map<Moneda, double> ingresosMesPorMoneda;
  final Map<Moneda, double> gastosMesPorMoneda;
  final List<GastoPorCategoria> gastoPorCategoriaMes;

  /// Deudas activas que YO debo (Fase 82: solo `direccion == debo`). Es
  /// lo que alimenta "Total que debes", próximos pagos, alertas de
  /// vencimiento y los conteos de mora/por vencer.
  final List<DeudaActivaResumen> deudasActivas;

  /// Saldo pendiente de [deudasActivas] por moneda (solo `debo`).
  final Map<Moneda, double> totalAdeudadoPorMoneda;

  /// Fase 82 — préstamos que hice: deudas activas con `meDeben`, ya
  /// ordenadas como [deudasActivas]. Fuera de todo total de "lo que debo".
  final List<DeudaActivaResumen> deudasMeDebenActivas;

  /// Saldo pendiente de [deudasMeDebenActivas] por moneda.
  final Map<Moneda, double> totalTeDebenPorMoneda;
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
    this.deudasMeDebenActivas = const [],
    this.totalTeDebenPorMoneda = const {},
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
      deudasActivas.isEmpty &&
      deudasMeDebenActivas.isEmpty;
}
