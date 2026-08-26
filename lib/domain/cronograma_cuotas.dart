import 'entities/deuda.dart';
import 'entities/pago_deuda.dart';

/// Una cuota programada del cronograma de amortización de una deuda
/// `cuotasFijas`. Clase de dominio pura, sin dependencias de Flutter.
class CuotaProgramada {
  final int numero;
  final DateTime fechaVencimiento;
  final double montoEsperado;
  final bool pagada;
  final PagoDeuda? pago;

  const CuotaProgramada({
    required this.numero,
    required this.fechaVencimiento,
    required this.montoEsperado,
    required this.pagada,
    this.pago,
  });
}

/// Genera el cronograma completo de cuotas de [deuda] cruzando [pagos] ya
/// registrados. Solo tiene sentido para `EstructuraPago.cuotasFijas`; para
/// `pagoLibre` (o si faltan datos requeridos) devuelve una lista vacía.
///
/// Los pagos con `numeroCuota` se emparejan directamente con esa cuota. Los
/// pagos legacy sin `numeroCuota` se ordenan por `fechaPago` y se asignan en
/// ese orden a las primeras cuotas que sigan sin marcar, para que deudas
/// antiguas conserven su progreso sin perder datos.
List<CuotaProgramada> generarCronogramaCuotas(
  Deuda deuda,
  List<PagoDeuda> pagos,
) {
  if (deuda.estructuraPago != EstructuraPago.cuotasFijas) return [];

  final numeroCuotasTotal = deuda.numeroCuotasTotal;
  final montoCuota = deuda.montoCuota;
  final periodicidad = deuda.periodicidadCuotas;
  if (numeroCuotasTotal == null || montoCuota == null || periodicidad == null) {
    return [];
  }

  final pagosPorNumero = <int, PagoDeuda>{};
  final pagosSinNumero = <PagoDeuda>[];
  for (final pago in pagos) {
    final numero = pago.numeroCuota;
    if (numero != null) {
      pagosPorNumero[numero] = pago;
    } else {
      pagosSinNumero.add(pago);
    }
  }
  pagosSinNumero.sort((a, b) => a.fechaPago.compareTo(b.fechaPago));

  var indiceSinNumero = 0;
  final cronograma = <CuotaProgramada>[];
  for (var numero = 1; numero <= numeroCuotasTotal; numero++) {
    final fechaVencimiento = _sumarPeriodos(
      deuda.fechaInicio,
      numero - 1,
      periodicidad,
    );

    var pago = pagosPorNumero[numero];
    if (pago == null && indiceSinNumero < pagosSinNumero.length) {
      pago = pagosSinNumero[indiceSinNumero];
      indiceSinNumero++;
    }

    cronograma.add(
      CuotaProgramada(
        numero: numero,
        fechaVencimiento: fechaVencimiento,
        montoEsperado: montoCuota,
        pagada: pago != null,
        pago: pago,
      ),
    );
  }
  return cronograma;
}

/// Fecha de vencimiento de la primera cuota pendiente del cronograma, o
/// `null` si todas las cuotas ya están pagadas.
DateTime? proximaFechaPagoDesdeCronograma(List<CuotaProgramada> cronograma) {
  for (final cuota in cronograma) {
    if (!cuota.pagada) return cuota.fechaVencimiento;
  }
  return null;
}

/// Fecha de vencimiento de la última cuota del cronograma, o `null` si el
/// cronograma está vacío.
DateTime? fechaVencimientoFinalDesdeCronograma(
  List<CuotaProgramada> cronograma,
) {
  if (cronograma.isEmpty) return null;
  return cronograma.last.fechaVencimiento;
}

DateTime _sumarPeriodos(
  DateTime fechaInicio,
  int periodos,
  PeriodicidadCuota periodicidad,
) {
  if (periodicidad == PeriodicidadCuota.quincenal) {
    return fechaInicio.add(Duration(days: 15 * periodos));
  }
  return sumarMeses(fechaInicio, periodos);
}

/// Suma [meses] calendario a [fecha] respetando fin de mes (ej. 31 de enero
/// + 1 mes = 28/29 de febrero, no 3 de marzo). Pública (Fase 62) para que
/// `proxima_ocurrencia_mensual.dart` la reutilice en vez de reescribirla.
DateTime sumarMeses(DateTime fecha, int meses) {
  final totalMeses = fecha.month - 1 + meses;
  final anio = fecha.year + totalMeses ~/ 12;
  final mes = totalMeses % 12 + 1;
  final ultimoDiaDelMes = DateTime(anio, mes + 1, 0).day;
  final dia = fecha.day > ultimoDiaDelMes ? ultimoDiaDelMes : fecha.day;
  return DateTime(anio, mes, dia);
}
