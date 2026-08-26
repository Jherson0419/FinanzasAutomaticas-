import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'dto/resumen_dashboard.dart';

class ObtenerResumenDashboard {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final CategoriaRepository _categoriaRepository;
  final DeudaRepository _deudaRepository;

  static const _movimientosRecientesLimite = 8;

  ObtenerResumenDashboard({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required CategoriaRepository categoriaRepository,
    required DeudaRepository deudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _categoriaRepository = categoriaRepository,
       _deudaRepository = deudaRepository;

  Future<ResumenDashboard> call() async {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    final finMes = DateTime(
      ahora.year,
      ahora.month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));

    final cuentas = await _cuentaRepository.obtenerTodas();
    final categorias = await _categoriaRepository.obtenerTodas();
    final categoriasPorId = {for (final c in categorias) c.id: c};
    final transaccionesMes = await _transaccionRepository.obtenerPorRangoFecha(
      inicioMes,
      finMes,
    );
    final movimientosRecientesRaw = await _transaccionRepository
        .obtenerRecientes(_movimientosRecientesLimite);
    final deudasActivasRaw = await _deudaRepository.obtenerActivas();

    final saldosPorCuenta = cuentas
        .map(
          (c) => SaldoCuenta(
            id: c.id,
            nombre: c.nombre,
            moneda: c.moneda,
            saldoActual: c.saldoActual,
          ),
        )
        .toList();

    // Fase 62: las tarjetas de crédito NUNCA cuentan como fondos
    // disponibles — su deuda ya se refleja aparte (en la propia tarjeta y,
    // desde esta fase, en su `Deuda` vinculada dentro de "Deudas activas").
    // Mismo criterio ya aplicado al resumen de Consejos en la Fase 60.
    final saldoTotalPorMoneda = <Moneda, double>{};
    for (final cuenta in cuentas) {
      if (cuenta.tipo == TipoCuenta.credito) continue;
      saldoTotalPorMoneda.update(
        cuenta.moneda,
        (v) => v + cuenta.saldoActual,
        ifAbsent: () => cuenta.saldoActual,
      );
    }

    final ingresosMesPorMoneda = <Moneda, double>{};
    final gastosMesPorMoneda = <Moneda, double>{};
    final gastoPorCategoriaAcumulado = <String, double>{};
    for (final t in transaccionesMes) {
      if (t.tipo == TipoTransaccion.ingreso) {
        ingresosMesPorMoneda.update(
          t.moneda,
          (v) => v + t.monto,
          ifAbsent: () => t.monto,
        );
      } else {
        gastosMesPorMoneda.update(
          t.moneda,
          (v) => v + t.monto,
          ifAbsent: () => t.monto,
        );
        final clave = '${t.categoriaId}|${t.moneda.name}';
        gastoPorCategoriaAcumulado.update(
          clave,
          (v) => v + t.monto,
          ifAbsent: () => t.monto,
        );
      }
    }

    final gastoPorCategoriaMes = gastoPorCategoriaAcumulado.entries.map((
      entry,
    ) {
      final partes = entry.key.split('|');
      final categoriaId = partes[0];
      final moneda = Moneda.values.byName(partes[1]);
      final categoria = categoriasPorId[categoriaId];
      final totalMoneda = gastosMesPorMoneda[moneda] ?? 0;
      return GastoPorCategoria(
        categoriaId: categoriaId,
        nombre: categoria?.nombre ?? 'Sin categoría',
        iconName: categoria?.iconName ?? 'category',
        moneda: moneda,
        monto: entry.value,
        porcentajeDelTotal: totalMoneda == 0 ? 0 : entry.value / totalMoneda,
      );
    }).toList()..sort((a, b) => b.monto.compareTo(a.monto));

    final deudasActivas = deudasActivasRaw
        .map(
          (d) => DeudaActivaResumen(
            id: d.id,
            nombreDeuda: d.nombreDeuda,
            estructuraPago: d.estructuraPago,
            proximaFechaPago: d.proximaFechaPago,
            enMora: d.enMora,
            diasMora: d.diasMora,
            montoPagado: d.montoPagado,
            montoTotal: d.montoTotal,
            montoCuota: d.montoCuota,
            moneda: d.moneda,
          ),
        )
        .toList();

    final totalAdeudadoPorMoneda = <Moneda, double>{};
    for (final d in deudasActivasRaw) {
      final saldo = d.montoTotal - d.montoPagado;
      totalAdeudadoPorMoneda.update(
        d.moneda,
        (v) => v + saldo,
        ifAbsent: () => saldo,
      );
    }

    final movimientosRecientes = movimientosRecientesRaw.map((t) {
      final categoria = categoriasPorId[t.categoriaId];
      return MovimientoReciente(
        id: t.id,
        concepto: t.concepto,
        monto: t.monto,
        moneda: t.moneda,
        tipo: t.tipo,
        categoriaNombre: categoria?.nombre ?? 'Sin categoría',
        categoriaIconName: categoria?.iconName ?? 'category',
        fuenteCaptura: t.fuenteCaptura,
        fecha: t.fecha,
      );
    }).toList();

    return ResumenDashboard(
      saldosPorCuenta: saldosPorCuenta,
      saldoTotalPorMoneda: saldoTotalPorMoneda,
      ingresosMesPorMoneda: ingresosMesPorMoneda,
      gastosMesPorMoneda: gastosMesPorMoneda,
      gastoPorCategoriaMes: gastoPorCategoriaMes,
      deudasActivas: deudasActivas,
      totalAdeudadoPorMoneda: totalAdeudadoPorMoneda,
      movimientosRecientes: movimientosRecientes,
    );
  }
}
