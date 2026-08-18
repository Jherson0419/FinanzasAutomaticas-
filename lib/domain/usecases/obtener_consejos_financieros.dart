import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/consejos_financieros_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'dto/resumen_para_consejos.dart';

/// Arma un resumen financiero agregado y anonimizado (mismo patrón de
/// agregación que `ObtenerResumenDashboard`) y le pide consejos a
/// `ConsejosFinancierosRepository`.
class ObtenerConsejosFinancieros {
  final DeudaRepository _deudaRepository;
  final TransaccionRepository _transaccionRepository;
  final CategoriaRepository _categoriaRepository;
  final CuentaRepository _cuentaRepository;
  final ConsejosFinancierosRepository _consejosFinancierosRepository;

  ObtenerConsejosFinancieros({
    required DeudaRepository deudaRepository,
    required TransaccionRepository transaccionRepository,
    required CategoriaRepository categoriaRepository,
    required CuentaRepository cuentaRepository,
    required ConsejosFinancierosRepository consejosFinancierosRepository,
  }) : _deudaRepository = deudaRepository,
       _transaccionRepository = transaccionRepository,
       _categoriaRepository = categoriaRepository,
       _cuentaRepository = cuentaRepository,
       _consejosFinancierosRepository = consejosFinancierosRepository;

  Future<List<String>> call() async {
    final resumen = await _armarResumen();
    return _consejosFinancierosRepository.generarConsejos(resumen);
  }

  Future<ResumenParaConsejos> _armarResumen() async {
    final ahora = DateTime.now();
    final inicioMes = DateTime(ahora.year, ahora.month, 1);
    final finMes = DateTime(
      ahora.year,
      ahora.month + 1,
      1,
    ).subtract(const Duration(microseconds: 1));

    final deudasActivas = await _deudaRepository.obtenerActivas();
    final transaccionesMes = await _transaccionRepository.obtenerPorRangoFecha(
      inicioMes,
      finMes,
    );
    final categorias = await _categoriaRepository.obtenerTodas();
    final cuentas = await _cuentaRepository.obtenerTodas();
    final categoriasPorId = {for (final c in categorias) c.id: c};

    final saldoTotalPorMoneda = <Moneda, double>{};
    for (final cuenta in cuentas) {
      saldoTotalPorMoneda.update(
        cuenta.moneda,
        (v) => v + cuenta.saldoActual,
        ifAbsent: () => cuenta.saldoActual,
      );
    }

    final ingresosAcumulado = <(String, Moneda), double>{};
    final gastosAcumulado = <(String, Moneda), double>{};
    for (final t in transaccionesMes) {
      final nombreCategoria =
          categoriasPorId[t.categoriaId]?.nombre ?? 'Sin categoría';
      final clave = (nombreCategoria, t.moneda);
      final acumulado = t.tipo == TipoTransaccion.ingreso
          ? ingresosAcumulado
          : gastosAcumulado;
      acumulado.update(clave, (v) => v + t.monto, ifAbsent: () => t.monto);
    }

    return ResumenParaConsejos(
      deudasActivas: [
        for (final deuda in deudasActivas)
          DeudaParaConsejos(
            tipoDeuda: deuda.tipoDeuda,
            montoTotal: deuda.montoTotal,
            montoPagado: deuda.montoPagado,
            interesTotal: deuda.interesTotal,
            moneda: deuda.moneda,
          ),
      ],
      ingresosPorCategoriaMes: _aLista(ingresosAcumulado),
      gastosPorCategoriaMes: _aLista(gastosAcumulado),
      saldoTotalPorMoneda: saldoTotalPorMoneda,
    );
  }

  List<CategoriaMontoConsejo> _aLista(Map<(String, Moneda), double> acumulado) {
    return [
      for (final entry in acumulado.entries)
        CategoriaMontoConsejo(
          categoriaNombre: entry.key.$1,
          monto: entry.value,
          moneda: entry.key.$2,
        ),
    ];
  }
}
