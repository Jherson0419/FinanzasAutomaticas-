
import 'entities/cuenta.dart';
import 'entities/deuda.dart';
import 'entities/transaccion.dart';
import 'plan_pago.dart';

/// Capacidad de pago (Fase 86): cuánto podrías destinar de más a tus
/// deudas cada mes, calculado SOLO con tus datos locales. Dart puro.
///
/// - Usa los meses COMPLETOS anteriores al actual (el mes en curso todavía
///   no terminó) que tengan movimientos en la moneda analizada, hasta
///   [mesesMaximosCapacidad]. Un mes sin ningún ingreso ni gasto
///   registrado se toma como "sin datos", no como un mes de S/ 0.
/// - Solo ingresos y gastos: las transferencias entre cuentas propias
///   nunca cuentan. Los pagos de deuda tampoco aparecen como gasto
///   (`RegistrarPagoDeuda` no crea transacciones), por eso se restan los
///   mínimos aparte sin contarlos dos veces.
/// - Dos estimaciones: SEGURA (peor ingreso − gasto más alto) y TÍPICA
///   (medianas). La recomendación es la segura.

/// Colchón por defecto: 10 % del ingreso que usa cada estimación.
const colchonPorDefecto = 0.10;

/// Con menos meses completos no se estima nada ("sin datos").
const mesesMinimosCapacidad = 2;

/// Ventana máxima de meses completos.
const mesesMaximosCapacidad = 6;

/// Ingresos y gastos de un mes completo (una moneda).
class FlujoMes {
  /// Día 1 del mes.
  final DateTime mes;
  final double ingresos;
  final double gastos;

  const FlujoMes({
    required this.mes,
    required this.ingresos,
    required this.gastos,
  });
}

/// Mediana; con un número par de valores, el promedio de los dos centrales.
double mediana(List<double> valores) {
  if (valores.isEmpty) return 0;
  final o = [...valores]..sort();
  final m = o.length ~/ 2;
  return o.length.isOdd ? o[m] : (o[m - 1] + o[m]) / 2;
}

/// Flujos de los meses completos con datos en [moneda], del más antiguo al
/// más reciente, a lo sumo [mesesMaximosCapacidad] (los más recientes).
List<FlujoMes> flujosMensualesCompletos(
  Iterable<Transaccion> transacciones, {
  required Moneda moneda,
  required DateTime ahora,
}) {
  final inicioMesActual = DateTime(ahora.year, ahora.month);
  final desde = DateTime(ahora.year, ahora.month - mesesMaximosCapacidad);
  final porMes = <DateTime, (double, double)>{};
  for (final t in transacciones) {
    if (t.moneda != moneda) continue;
    if (t.fecha.isBefore(desde) || !t.fecha.isBefore(inicioMesActual)) {
      continue;
    }
    final (ingreso, gasto) = switch (t.tipo) {
      TipoTransaccion.ingreso => (t.monto, 0.0),
      TipoTransaccion.gasto => (0.0, t.monto),
      // Mover dinero entre cuentas propias no es ingreso ni gasto.
      TipoTransaccion.transferenciaSalida ||
      TipoTransaccion.transferenciaEntrada => (null, null),
    };
    if (ingreso == null || gasto == null) continue;
    final mes = DateTime(t.fecha.year, t.fecha.month);
    final previo = porMes[mes] ?? (0.0, 0.0);
    porMes[mes] = (previo.$1 + ingreso, previo.$2 + gasto);
  }
  final meses = porMes.keys.toList()..sort();
  return [
    for (final m in meses)
      FlujoMes(mes: m, ingresos: porMes[m]!.$1, gastos: porMes[m]!.$2),
  ];
}

/// Moneda principal del análisis: soles si hay movimientos en soles en la
/// ventana; si no, la moneda con más ingresos; sin movimientos, soles.
Moneda monedaPrincipalCapacidad(
  Iterable<Transaccion> transacciones, {
  required DateTime ahora,
}) {
  final volumen = <Moneda, double>{};
  for (final m in Moneda.values) {
    final flujos = flujosMensualesCompletos(
      transacciones,
      moneda: m,
      ahora: ahora,
    );
    if (flujos.isEmpty) continue;
    volumen[m] = flujos.fold(0.0, (s, f) => s + f.ingresos);
  }
  if (volumen.containsKey(Moneda.pen) || volumen.isEmpty) return Moneda.pen;
  return volumen.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Resultado de [calcularCapacidadPago].
sealed class ResultadoCapacidad {
  final Moneda moneda;

  /// Otras monedas con movimientos o deudas: no se mezclan ni se convierten.
  final List<Moneda> otrasMonedas;

  const ResultadoCapacidad({required this.moneda, required this.otrasMonedas});
}

/// Menos de [mesesMinimosCapacidad] meses completos: no se estima nada.
class CapacidadSinDatos extends ResultadoCapacidad {
  final int mesesConDatos;

  const CapacidadSinDatos({
    required super.moneda,
    required super.otrasMonedas,
    required this.mesesConDatos,
  });
}

/// Mínimo de una tarjeta que NO se resta (Fase 87): el promedio mensual de
/// gastos cargados a esa tarjeta en la ventana ya lo cubre — esas compras
/// cuentan como gasto, restar también el mínimo las contaría dos veces.
class MinimoTarjetaExcluido {
  final String deudaId;
  final String nombre;
  final double minimo;
  final double gastoPromedio;

  const MinimoTarjetaExcluido({
    required this.deudaId,
    required this.nombre,
    required this.minimo,
    required this.gastoPromedio,
  });
}

class CapacidadCalculada extends ResultadoCapacidad {
  final List<FlujoMes> meses;

  /// Suma de los pagos mínimos mensuales de lo que DEBES en [moneda]
  /// (`pagoMinimoMensual`, el mismo que usa el plan), SIN los de
  /// [tarjetasExcluidas].
  final double minimos;

  /// Fracción del ingreso reservada (0.10 = 10 %).
  final double colchon;

  /// Tarjetas cuyo mínimo no se restó (ver [MinimoTarjetaExcluido]).
  final List<MinimoTarjetaExcluido> tarjetasExcluidas;

  const CapacidadCalculada({
    required super.moneda,
    required super.otrasMonedas,
    required this.meses,
    required this.minimos,
    required this.colchon,
    this.tarjetasExcluidas = const [],
  });

  /// Lo que deja un mes: ingreso − gasto − colchón (% del ingreso de ESE
  /// mes).
  double margenDelMes(FlujoMes m) =>
      m.ingresos - m.gastos - colchon * m.ingresos;

  /// Fase 87: el mes que menos dejó (el más ajustado de la ventana). En
  /// empate, el más antiguo.
  FlujoMes get mesMasAjustado =>
      meses.reduce((a, b) => margenDelMes(b) < margenDelMes(a) ? b : a);

  double get ingresoMediano => mediana([for (final m in meses) m.ingresos]);
  double get gastoMediano => mediana([for (final m in meses) m.gastos]);

  double get colchonSeguro => colchon * mesMasAjustado.ingresos;
  double get colchonTipico => colchon * ingresoMediano;

  /// Fase 87: mínimo, entre los meses, de (ingreso − gasto − colchón de
  /// ese mes), menos los mínimos de deuda.
  double get seguro => margenDelMes(mesMasAjustado) - minimos;

  /// Mediana de ingresos − mediana de gastos − mínimos − colchón.
  double get tipico => ingresoMediano - gastoMediano - minimos - colchonTipico;

  /// `true` si la estimación segura no deja nada (≤ 0).
  bool get noAlcanza => seguro <= 0;

  /// `true` si el peor mes no alcanzó pero un mes típico sí (Fase 87).
  bool get soloAlcanzaEnMesTipico => noAlcanza && tipico > 0;

  /// Lo que falta en el escenario seguro (0 si alcanza).
  double get faltante => noAlcanza ? -seguro : 0;

  /// Pago extra recomendado: la estimación segura, en soles enteros hacia
  /// abajo, nunca negativa.
  double get recomendado => noAlcanza ? 0 : seguro.floorToDouble();

  /// Monto típico en soles enteros (para "Usar S/ X (arriesgado…)").
  double get tipicoRedondeado => tipico <= 0 ? 0 : tipico.floorToDouble();
}

/// Calcula la capacidad de pago con los meses completos anteriores a
/// [ahora]. [moneda] por defecto: [monedaPrincipalCapacidad].
///
/// Fase 87 — mínimos de tarjeta: si el promedio mensual de GASTOS
/// cargados a la tarjeta (en los meses de la ventana) es ≥ su pago mínimo,
/// ese mínimo no se resta.
ResultadoCapacidad calcularCapacidadPago({
  required Iterable<Transaccion> transacciones,
  required Iterable<Deuda> deudas,
  required DateTime ahora,
  double colchon = colchonPorDefecto,
  Moneda? moneda,
}) {
  if (colchon < 0 || colchon >= 1) {
    throw ArgumentError('El colchón debe estar entre 0 % y 99 %');
  }
  final m = moneda ?? monedaPrincipalCapacidad(transacciones, ahora: ahora);
  final enPlan = deudasParaPlan(deudas);
  final otras = <Moneda>{
    for (final x in Moneda.values)
      if (x != m &&
          (flujosMensualesCompletos(
                transacciones,
                moneda: x,
                ahora: ahora,
              ).isNotEmpty ||
              enPlan.any((d) => d.moneda == x)))
        x,
  }.toList();
  final flujos = flujosMensualesCompletos(
    transacciones,
    moneda: m,
    ahora: ahora,
  );
  if (flujos.length < mesesMinimosCapacidad) {
    return CapacidadSinDatos(
      moneda: m,
      otrasMonedas: otras,
      mesesConDatos: flujos.length,
    );
  }
  final mesesVentana = {for (final f in flujos) f.mes};
  double gastoPromedioEnTarjeta(String cuentaId) {
    var total = 0.0;
    for (final t in transacciones) {
      if (t.cuentaId != cuentaId ||
          t.moneda != m ||
          t.tipo != TipoTransaccion.gasto) {
        continue;
      }
      if (!mesesVentana.contains(DateTime(t.fecha.year, t.fecha.month))) {
        continue;
      }
      total += t.monto;
    }
    return total / flujos.length;
  }

  var minimos = 0.0;
  final excluidas = <MinimoTarjetaExcluido>[];
  for (final d in enPlan.where((d) => d.moneda == m)) {
    final minimo = pagoMinimoMensual(d);
    final cuentaId = d.cuentaId;
    if (cuentaId != null && minimo > 0) {
      final promedio = gastoPromedioEnTarjeta(cuentaId);
      if (promedio >= minimo) {
        excluidas.add(
          MinimoTarjetaExcluido(
            deudaId: d.id,
            nombre: d.nombreDeuda,
            minimo: minimo,
            gastoPromedio: promedio,
          ),
        );
        continue;
      }
    }
    minimos += minimo;
  }
  return CapacidadCalculada(
    moneda: m,
    otrasMonedas: otras,
    meses: flujos,
    minimos: minimos,
    colchon: colchon,
    tarjetasExcluidas: excluidas,
  );
}
