import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../entities/transaccion.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import '../saldo_deuda.dart';
import 'dto/resumen_para_consejos.dart';

/// Arma un resumen financiero agregado y anonimizado (mismo patrón de
/// agregación que `ObtenerResumenDashboard`) para el primer mensaje del
/// chat de consejos financieros (Fase 30). Antes de esta fase esta misma
/// lógica vivía en `ObtenerConsejosFinancieros`, que además llamaba a
/// Gemini directo (un solo turno, sin historial) — ese caso de uso
/// desapareció junto con el flujo de "Generar consejos" de un botón único;
/// esta clase es exactamente su método `_armarResumen()` extraído.
///
/// **Fase 60 — bug corregido:** antes, `saldoActual` de TODAS las cuentas
/// (incluidas las de crédito) se sumaba en un solo "saldo total disponible".
/// Como `saldoActual` de una tarjeta es negativo cuando tiene uso (Fase 57),
/// Gemini no tenía forma de distinguir "esto es dinero mío" de "esto es una
/// tarjeta con X ya gastado" — y llegó a sugerir usar una tarjeta para pagar
/// otras deudas. Ahora las cuentas de crédito se excluyen por completo de
/// `saldoTotalPorMoneda` y se reportan aparte en `tarjetasCredito`.
class ArmarResumenParaConsejos {
  final DeudaRepository _deudaRepository;
  final TransaccionRepository _transaccionRepository;
  final CategoriaRepository _categoriaRepository;
  final CuentaRepository _cuentaRepository;

  ArmarResumenParaConsejos({
    required DeudaRepository deudaRepository,
    required TransaccionRepository transaccionRepository,
    required CategoriaRepository categoriaRepository,
    required CuentaRepository cuentaRepository,
  }) : _deudaRepository = deudaRepository,
       _transaccionRepository = transaccionRepository,
       _categoriaRepository = categoriaRepository,
       _cuentaRepository = cuentaRepository;

  Future<ResumenParaConsejos> call() async {
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

    // Fase 60: las tarjetas de crédito NUNCA cuentan como fondos propios —
    // se excluyen de `saldoTotalPorMoneda` (aunque su `saldoActual` esté en
    // positivo) y se reportan aparte, como obligación pendiente.
    final saldoTotalPorMoneda = <Moneda, double>{};
    final tarjetasCredito = <TarjetaCreditoParaConsejos>[];
    for (final cuenta in cuentas) {
      if (cuenta.tipo == TipoCuenta.credito) {
        final montoUsado = cuenta.saldoActual < 0
            ? cuenta.saldoActual.abs()
            : 0.0;
        final lineaTotal = cuenta.lineaCredito ?? 0.0;
        tarjetasCredito.add(
          TarjetaCreditoParaConsejos(
            montoUsado: montoUsado,
            lineaTotal: lineaTotal,
            creditoDisponible: lineaTotal - montoUsado,
            moneda: cuenta.moneda,
          ),
        );
        continue;
      }
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
      final acumulado = switch (t.tipo) {
        TipoTransaccion.ingreso => ingresosAcumulado,
        TipoTransaccion.gasto => gastosAcumulado,
        // Fase 85: una transferencia entre cuentas propias no es ingreso
        // ni gasto — no se envía en el resumen.
        TipoTransaccion.transferenciaSalida ||
        TipoTransaccion.transferenciaEntrada => null,
      };
      acumulado?.update(clave, (v) => v + t.monto, ifAbsent: () => t.monto);
    }

    return ResumenParaConsejos(
      deudasActivas: [
        // Fase 82: solo lo que YO debo. Un préstamo que hice ("me deben")
        // no es una obligación mía y distorsionaría los consejos.
        for (final deuda in deudasActivas)
          if (deuda.direccion == DireccionDeuda.debo)
            DeudaParaConsejos(
              tipoDeuda: deuda.tipoDeuda,
              // Fase 79: total a pagar real (en cuotas fijas, capital +
              // interés), no el capital — así `montoTotal − montoPagado` da el
              // saldo pendiente correcto también en la Edge Function
              // `generar-consejos` ya desplegada, sin redeploy.
              montoTotal: totalAPagar(deuda),
              montoPagado: deuda.montoPagado,
              interesTotal: deuda.interesTotal,
              moneda: deuda.moneda,
              // Fase 88: el capital va aparte (payload v2).
              capital: deuda.montoTotal,
            ),
      ],
      ingresosPorCategoriaMes: _aLista(ingresosAcumulado),
      gastosPorCategoriaMes: _aLista(gastosAcumulado),
      saldoTotalPorMoneda: saldoTotalPorMoneda,
      tarjetasCredito: tarjetasCredito,
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
