import 'entities/categoria.dart';
import 'entities/cuenta.dart';
import 'entities/transaccion.dart';

/// Dominio puro de la pantalla Movimientos (Fase 81). Sin Flutter ni
/// repositorios: todo opera sobre listas ya cargadas.

/// Una transacción con los nombres que necesita la búsqueda y la vista.
class MovimientoDetallado {
  final Transaccion transaccion;
  final String categoriaNombre;
  final String? categoriaIcono;
  final String cuentaNombre;

  const MovimientoDetallado({
    required this.transaccion,
    required this.categoriaNombre,
    required this.cuentaNombre,
    this.categoriaIcono,
  });
}

/// Cruza transacciones con sus categorías y cuentas. Si falta alguna, usa
/// "Sin categoría" / "" en vez de fallar. Resultado ordenado de la más
/// reciente a la más antigua.
List<MovimientoDetallado> detallarMovimientos(
  List<Transaccion> transacciones,
  List<Categoria> categorias,
  List<Cuenta> cuentas,
) {
  final categoriaPorId = {for (final c in categorias) c.id: c};
  final cuentaPorId = {for (final c in cuentas) c.id: c};
  return [
    for (final t in transacciones)
      MovimientoDetallado(
        transaccion: t,
        // Fase 85: una transferencia no tiene categoría.
        categoriaNombre: t.esTransferencia
            ? 'Transferencia'
            : categoriaPorId[t.categoriaId]?.nombre ?? 'Sin categoría',
        categoriaIcono: categoriaPorId[t.categoriaId]?.iconName,
        cuentaNombre: cuentaPorId[t.cuentaId]?.nombre ?? '',
      ),
  ]..sort((a, b) => b.transaccion.fecha.compareTo(a.transaccion.fecha));
}

const _sinTildes = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', //
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
  'ñ': 'n', 'ç': 'c',
};

/// Minúsculas y sin tildes ("Café" → "cafe", "Año" → "ano"), sin paquetes
/// externos. Colapsa espacios repetidos.
String normalizarTexto(String texto) {
  final buffer = StringBuffer();
  for (final caracter in texto.toLowerCase().split('')) {
    buffer.write(_sinTildes[caracter] ?? caracter);
  }
  return buffer.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Primer instante del mes de [fecha] y primer instante del mes siguiente:
/// rango semiabierto `[desde, hasta)` para [filtrarMovimientos].
(DateTime, DateTime) rangoDelMes(DateTime fecha) => (
  DateTime(fecha.year, fecha.month, 1),
  DateTime(fecha.year, fecha.month + 1, 1),
);

/// Fase 85 — origen y destino de cada transferencia, por `transferenciaId`
/// (una cara puede faltar si la transferencia quedó a medias).
Map<String, ({String? origenId, String? destinoId})> cuentasDeTransferencias(
  Iterable<Transaccion> transacciones,
) {
  final pares = <String, ({String? origenId, String? destinoId})>{};
  for (final t in transacciones) {
    final id = t.transferenciaId;
    if (id == null) continue;
    final previo = pares[id] ?? (origenId: null, destinoId: null);
    pares[id] = switch (t.tipo) {
      TipoTransaccion.transferenciaSalida => (
        origenId: t.cuentaId,
        destinoId: previo.destinoId,
      ),
      TipoTransaccion.transferenciaEntrada => (
        origenId: previo.origenId,
        destinoId: t.cuentaId,
      ),
      TipoTransaccion.ingreso || TipoTransaccion.gasto => previo,
    };
  }
  return pares;
}

/// Fase 85 — "Transferencia a Visa BCP" (vista desde la salida) o
/// "Transferencia desde Débito" (desde la entrada). Sin la otra cara o sin
/// su nombre, solo "Transferencia".
String tituloTransferencia(
  Transaccion t,
  Map<String, ({String? origenId, String? destinoId})> pares,
  Map<String, String> nombreCuenta,
) {
  final par = pares[t.transferenciaId];
  final (prefijo, otraCuenta) = switch (t.tipo) {
    TipoTransaccion.transferenciaEntrada => ('desde', par?.origenId),
    _ => ('a', par?.destinoId),
  };
  final nombre = otraCuenta == null ? null : nombreCuenta[otraCuenta];
  return nombre == null || nombre.isEmpty
      ? 'Transferencia'
      : 'Transferencia $prefijo $nombre';
}

/// Filtra movimientos. Todos los criterios se combinan con "y":
/// - [texto]: normalizado (ver [normalizarTexto]); cada palabra debe
///   aparecer en el concepto, el nombre de la categoría o el de la cuenta.
/// - [tipo]: solo ingresos o solo gastos.
/// - [soloTransferencias] (Fase 85): solo transferencias.
/// - [desde] (incluido) / [hasta] (EXCLUIDO): rango semiabierto, así el
///   mes de noviembre es `[1 nov 00:00, 1 dic 00:00)` — ver [rangoDelMes].
/// - [cuentaId] / [categoriaId]: igualdad exacta.
///
/// Fase 85: sin [cuentaId], una transferencia aparece UNA vez (su salida);
/// la entrada solo se muestra si su salida no está en [movimientos]. Con
/// [cuentaId], se ve la cara de esa cuenta.
List<MovimientoDetallado> filtrarMovimientos(
  List<MovimientoDetallado> movimientos, {
  String texto = '',
  TipoTransaccion? tipo,
  bool soloTransferencias = false,
  DateTime? desde,
  DateTime? hasta,
  String? cuentaId,
  String? categoriaId,
}) {
  final palabras = normalizarTexto(
    texto,
  ).split(' ').where((p) => p.isNotEmpty).toList();
  final salidas = {
    for (final m in movimientos)
      if (m.transaccion.tipo == TipoTransaccion.transferenciaSalida)
        m.transaccion.transferenciaId,
  };
  return movimientos.where((m) {
    final t = m.transaccion;
    if (tipo != null && t.tipo != tipo) return false;
    if (soloTransferencias && !t.esTransferencia) return false;
    if (cuentaId == null &&
        t.tipo == TipoTransaccion.transferenciaEntrada &&
        salidas.contains(t.transferenciaId)) {
      return false;
    }
    if (desde != null && t.fecha.isBefore(desde)) return false;
    if (hasta != null && !t.fecha.isBefore(hasta)) return false;
    if (cuentaId != null && t.cuentaId != cuentaId) return false;
    if (categoriaId != null && t.categoriaId != categoriaId) return false;
    if (palabras.isEmpty) return true;
    final buscable = normalizarTexto(
      '${t.concepto} ${m.categoriaNombre} ${m.cuentaNombre}',
    );
    return palabras.every(buscable.contains);
  }).toList();
}

/// Qué día es un grupo respecto de "hoy" (la vista lo traduce a
/// "Hoy" / "Ayer" / fecha).
enum TipoDia { hoy, ayer, otro }

/// Movimientos de un mismo día de calendario.
class GrupoDia {
  /// Medianoche del día.
  final DateTime dia;
  final TipoDia tipoDia;
  final List<MovimientoDetallado> movimientos;

  /// Ingresos − gastos del día, por moneda (sin convertir). Las
  /// transferencias no cuentan (Fase 85).
  final Map<Moneda, double> subtotalNeto;

  const GrupoDia({
    required this.dia,
    required this.tipoDia,
    required this.movimientos,
    required this.subtotalNeto,
  });
}

/// Agrupa por día de calendario, del más reciente al más antiguo; dentro
/// de cada día, del movimiento más reciente al más antiguo. Un día sin
/// movimientos no genera grupo.
List<GrupoDia> agruparPorDia(
  List<MovimientoDetallado> movimientos, {
  required DateTime ahora,
}) {
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final ayer = DateTime(hoy.year, hoy.month, hoy.day - 1);
  final porDia = <DateTime, List<MovimientoDetallado>>{};
  for (final m in movimientos) {
    final f = m.transaccion.fecha;
    porDia.putIfAbsent(DateTime(f.year, f.month, f.day), () => []).add(m);
  }
  final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final dia in dias)
      GrupoDia(
        dia: dia,
        tipoDia: dia == hoy
            ? TipoDia.hoy
            : dia == ayer
            ? TipoDia.ayer
            : TipoDia.otro,
        movimientos: porDia[dia]!
          ..sort((a, b) => b.transaccion.fecha.compareTo(a.transaccion.fecha)),
        subtotalNeto: _netoPorMoneda(porDia[dia]!),
      ),
  ];
}

Map<Moneda, double> _netoPorMoneda(List<MovimientoDetallado> movimientos) {
  final neto = <Moneda, double>{};
  for (final m in movimientos) {
    final t = m.transaccion;
    final signo = switch (t.tipo) {
      TipoTransaccion.ingreso => 1,
      TipoTransaccion.gasto => -1,
      TipoTransaccion.transferenciaSalida ||
      TipoTransaccion.transferenciaEntrada => null,
    };
    if (signo == null) continue;
    neto.update(
      t.moneda,
      (v) => v + signo * t.monto,
      ifAbsent: () => signo * t.monto,
    );
  }
  return neto;
}

/// Una porción de "Gasto del mes".
class PorcionGasto {
  /// `null` en la porción "Otros".
  final String? categoriaId;
  final String nombre;
  final double monto;

  /// Porcentaje exacto (0–100).
  final double porcentaje;

  /// Porcentaje entero para mostrar; los de un mismo resumen suman
  /// exactamente 100 (método del mayor resto).
  final int porcentajeEntero;

  bool get esOtros => categoriaId == null;

  const PorcionGasto({
    required this.categoriaId,
    required this.nombre,
    required this.monto,
    required this.porcentaje,
    required this.porcentajeEntero,
  });
}

/// "Gasto del mes" de UNA moneda.
class ResumenGastoCategorias {
  final Moneda moneda;
  final double total;
  final List<PorcionGasto> porciones;

  const ResumenGastoCategorias({
    required this.moneda,
    required this.total,
    required this.porciones,
  });
}

/// Top [topN] categorías de gasto + "Otros" (si hay más), por moneda y sin
/// convertir. Solo cuenta gastos; los ingresos se ignoran. Monedas sin
/// gastos no aparecen. Orden de monedas: soles primero, luego el resto.
List<ResumenGastoCategorias> resumenGastoPorCategoria(
  List<MovimientoDetallado> movimientos, {
  int topN = 3,
}) {
  final porMoneda = <Moneda, Map<String, (String, double)>>{};
  for (final m in movimientos) {
    final t = m.transaccion;
    final esGasto = switch (t.tipo) {
      TipoTransaccion.gasto => true,
      // Fase 85: las transferencias nunca entran en "Gasto del mes".
      TipoTransaccion.ingreso ||
      TipoTransaccion.transferenciaSalida ||
      TipoTransaccion.transferenciaEntrada => false,
    };
    if (!esGasto) continue;
    final clave = t.categoriaId ?? '';
    final categorias = porMoneda.putIfAbsent(t.moneda, () => {});
    final previo = categorias[clave];
    categorias[clave] = (
      m.categoriaNombre,
      (previo?.$2 ?? 0) + t.monto,
    );
  }

  final monedas = porMoneda.keys.toList()
    ..sort((a, b) => a == Moneda.pen ? -1 : (b == Moneda.pen ? 1 : 0));

  return [
    for (final moneda in monedas)
      _resumenDeMoneda(moneda, porMoneda[moneda]!, topN),
  ];
}

ResumenGastoCategorias _resumenDeMoneda(
  Moneda moneda,
  Map<String, (String, double)> categorias,
  int topN,
) {
  final ordenadas = categorias.entries.toList()
    ..sort((a, b) {
      final porMonto = b.value.$2.compareTo(a.value.$2);
      return porMonto != 0 ? porMonto : a.value.$1.compareTo(b.value.$1);
    });
  final total = ordenadas.fold(0.0, (s, e) => s + e.value.$2);

  final top = ordenadas.take(topN).toList();
  final resto = ordenadas.skip(topN).toList();
  final crudas = <(String?, String, double)>[
    for (final e in top) (e.key, e.value.$1, e.value.$2),
    if (resto.isNotEmpty)
      (null, 'Otros', resto.fold(0.0, (s, e) => s + e.value.$2)),
  ];

  final exactos = [
    for (final c in crudas) total == 0 ? 0.0 : c.$3 / total * 100,
  ];
  final enteros = _repartirEnteros(exactos);
  return ResumenGastoCategorias(
    moneda: moneda,
    total: total,
    porciones: [
      for (var i = 0; i < crudas.length; i++)
        PorcionGasto(
          categoriaId: crudas[i].$1,
          nombre: crudas[i].$2,
          monto: crudas[i].$3,
          porcentaje: exactos[i],
          porcentajeEntero: enteros[i],
        ),
    ],
  );
}

/// Método del mayor resto: redondea hacia abajo y reparte los puntos que
/// faltan para 100 entre los restos más grandes.
List<int> _repartirEnteros(List<double> exactos) {
  if (exactos.isEmpty) return const [];
  final suma = exactos.fold(0.0, (s, e) => s + e);
  if (suma == 0) return List.filled(exactos.length, 0);
  final base = [for (final e in exactos) e.floor()];
  var faltan = 100 - base.fold(0, (s, e) => s + e);
  final porResto = List.generate(exactos.length, (i) => i)
    ..sort((a, b) => (exactos[b] - base[b]).compareTo(exactos[a] - base[a]));
  for (final i in porResto) {
    if (faltan <= 0) break;
    base[i]++;
    faltan--;
  }
  return base;
}
