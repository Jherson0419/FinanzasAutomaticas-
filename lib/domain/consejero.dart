import 'dart:math' as math;

import 'abono_capital.dart';
import 'capacidad_pago.dart';
import 'costo_deuda.dart';
import 'entities/cuenta.dart';
import 'entities/deuda.dart';
import 'entities/pago_deuda.dart';
import 'entities/transaccion.dart';
import 'plan_pago.dart';
import 'proxima_ocurrencia_mensual.dart';
import 'saldo_deuda.dart';

/// Consejero local (Fase 86): un motor de reglas PURAS y deterministas
/// sobre tus datos. Sin IA ni red. Cada regla devuelve 0..n [Consejo];
/// una regla sin datos suficientes no devuelve nada (nunca inventa cifras).
///
/// Tono: segunda persona, directo, sin culpar ni asustar.

// ---------------------------------------------------------------------
// Umbrales (constantes con nombre)
// ---------------------------------------------------------------------

/// Regla 1: avisa de lo que vence en esta cantidad de días o menos.
const diasAvisoVencimiento = 3;

/// Regla 4: uso de la línea de una tarjeta por ENCIMA del cual se avisa…
const umbralUsoTarjeta = 0.30;

/// …y por encima del cual el aviso sube de prioridad.
const umbralUsoTarjetaAlto = 0.70;

/// Regla 7: gasto de una categoría por ENCIMA de este múltiplo de su
/// promedio de los [mesesPromedioCategoria] meses anteriores.
const umbralGastoCategoria = 1.5;
const mesesPromedioCategoria = 3;

/// Regla 3: la capacidad debe superar el extra configurado al menos en esto
/// (evita "podrías pagar S/ 3 más").
const margenMinimoCapacidad = 10.0;

/// Regla 8: monto del abono sugerido y ahorro mínimo para mencionarlo.
const montoAbonoSugerido = 100.0;
const ahorroMinimoAbono = 1.0;

/// Consejos visibles a la vez; el resto va en "Ver más".
const maximoConsejosVisibles = 3;

/// Días que un consejo pospuesto queda oculto.
const diasPosponerConsejo = 7;

/// Pie fijo del consejero.
const pieConsejero =
    'Son sugerencias automáticas de Finzo, no asesoría financiera.';

// ---------------------------------------------------------------------
// Modelo
// ---------------------------------------------------------------------

enum ReglaConsejo {
  vencePronto,
  pagaPrimero,
  capacidadDisponible,
  usoTarjeta,
  mora,
  faltaTasa,
  gastoCategoria,
  abonoSugerido,
}

/// A dónde lleva la acción de un consejo (ruta con nombre + argumento).
class AccionConsejo {
  final String etiqueta;
  final String ruta;
  final Object? argumentos;

  const AccionConsejo(this.etiqueta, this.ruta, [this.argumentos]);
}

class Consejo {
  /// Único y estable: `<regla>:<sujeto>` (p. ej. `usoTarjeta:<cuentaId>`).
  /// Con él se guarda si lo descartaste o pospusiste.
  final String id;
  final ReglaConsejo regla;

  /// Mayor = más importante.
  final int prioridad;
  final String titulo;
  final String texto;
  final AccionConsejo? accion;

  /// Datos de soporte (para la vista y las pruebas).
  final Map<String, Object> datos;

  /// Resumen GRUESO de los datos de soporte: un consejo descartado vuelve
  /// solo si su huella cambia (ver [EstadoConsejo]).
  final String huella;

  const Consejo({
    required this.id,
    required this.regla,
    required this.prioridad,
    required this.titulo,
    required this.texto,
    required this.huella,
    this.accion,
    this.datos = const {},
  });
}

/// Todo lo que las reglas pueden mirar. Montos en la moneda de cada cosa;
/// las reglas que comparan montos no mezclan monedas.
class ContextoConsejero {
  final DateTime ahora;
  final List<Deuda> deudas;
  final List<Cuenta> cuentas;
  final List<Transaccion> transacciones;
  final List<PagoDeuda> pagosDeuda;

  /// Pago extra mensual configurado en el plan.
  final double extraMensual;

  /// Estrategia elegida en el plan; `null` = la recomendada.
  final EstrategiaPago? estrategia;

  /// Nombres de categoría por id (regla 7).
  final Map<String, String> nombresCategoria;

  const ContextoConsejero({
    required this.ahora,
    required this.deudas,
    required this.cuentas,
    required this.transacciones,
    this.pagosDeuda = const [],
    this.extraMensual = 0,
    this.estrategia,
    this.nombresCategoria = const {},
  });
}

String _monto(double v, Moneda m) {
  final s = v.abs().toStringAsFixed(2);
  final partes = s.split('.');
  final entero = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  final simbolo = m == Moneda.pen ? 'S/' : r'US$';
  return '$simbolo $entero.${partes[1]}';
}

String _dias(int d) => switch (d) {
  0 => 'hoy',
  1 => 'mañana',
  _ => 'en $d días',
};

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

// ---------------------------------------------------------------------
// Vencimientos (reglas 1 y revisión semanal)
// ---------------------------------------------------------------------

/// Un pago que vence.
class Vencimiento {
  final Deuda deuda;
  final DateTime fecha;

  /// `null` si no se conoce el monto (no se inventa).
  final double? monto;

  const Vencimiento(this.deuda, this.fecha, this.monto);
}

/// Próximo vencimiento de cada deuda que DEBO y sigue viva:
/// - cuotas fijas: `proximaFechaPago` y el monto de esa cuota;
/// - tarjeta: la fecha de pago de su cuenta y su pago mínimo (si lo tiene);
/// - pago libre: `proximaFechaPago` (si la tiene) y su pago mínimo.
List<Vencimiento> vencimientos(
  List<Deuda> deudas,
  List<Cuenta> cuentas,
  DateTime ahora,
) {
  final cuentaPorId = {for (final c in cuentas) c.id: c};
  final resultado = <Vencimiento>[];
  for (final d in deudasParaPlan(deudas)) {
    DateTime? fecha;
    double? monto;
    if (d.cuentaId != null) {
      final fechaPago = cuentaPorId[d.cuentaId]?.fechaPago;
      if (fechaPago != null) fecha = proximaOcurrenciaMensual(fechaPago, ahora);
      monto = d.pagoMinimo;
    } else if (d.estructuraPago == EstructuraPago.cuotasFijas) {
      fecha = d.proximaFechaPago;
      monto = montoDeCuota(d, (d.numeroCuotasPagadas ?? 0) + 1);
    } else {
      fecha = d.proximaFechaPago;
      monto = d.pagoMinimo;
    }
    if (fecha == null) continue;
    final saldo = saldoPendiente(d);
    resultado.add(
      Vencimiento(
        d,
        _dia(fecha),
        monto == null || monto <= 0 ? null : math.min(monto, saldo),
      ),
    );
  }
  resultado.sort((a, b) => a.fecha.compareTo(b.fecha));
  return resultado;
}

// ---------------------------------------------------------------------
// Reglas
// ---------------------------------------------------------------------

/// Regla 1 — vence en ≤ [diasAvisoVencimiento] días; compara con la cuenta
/// de fondos (no tarjeta) con más saldo en esa moneda.
List<Consejo> reglaVencePronto(ContextoConsejero c) {
  final hoy = _dia(c.ahora);
  final consejos = <Consejo>[];
  for (final v in vencimientos(c.deudas, c.cuentas, c.ahora)) {
    final dias = v.fecha.difference(hoy).inDays;
    // Lo vencido (días < 0) lo cubre la regla de mora.
    if (dias < 0 || dias > diasAvisoVencimiento) continue;
    final moneda = v.deuda.moneda;
    final fondos =
        c.cuentas
            .where((x) => x.moneda == moneda && x.tipo != TipoCuenta.credito)
            .toList()
          ..sort((a, b) => b.saldoActual.compareTo(a.saldoActual));
    final mayor = fondos.firstOrNull;
    final monto = v.monto;
    String comparacion = '';
    if (monto != null && mayor != null) {
      comparacion = mayor.saldoActual >= monto
          ? ' Tu cuenta con más saldo, ${mayor.nombre}, tiene '
                '${_monto(mayor.saldoActual, moneda)}: te alcanza.'
          : ' Tu cuenta con más saldo, ${mayor.nombre}, tiene '
                '${_monto(mayor.saldoActual, moneda)}: te faltan '
                '${_monto(monto - mayor.saldoActual, moneda)}.';
    }
    final esTarjeta = v.deuda.cuentaId != null;
    consejos.add(
      Consejo(
        id: '${ReglaConsejo.vencePronto.name}:${v.deuda.id}',
        regla: ReglaConsejo.vencePronto,
        prioridad: 100 - dias,
        titulo: monto == null
            ? '${v.deuda.nombreDeuda} vence ${_dias(dias)}'
            : 'Paga ${_monto(monto, moneda)} de ${v.deuda.nombreDeuda}',
        texto:
            '${monto == null ? 'Tu pago' : 'Este pago'} vence ${_dias(dias)}.'
            '$comparacion',
        accion: esTarjeta
            ? AccionConsejo('Pagar tarjeta', '/transferencias/nueva', {
                'destinoId': v.deuda.cuentaId,
                'monto': monto,
              })
            : AccionConsejo('Registrar pago', '/deudas/pago', v.deuda.id),
        datos: {
          'deudaId': v.deuda.id,
          'dias': dias,
          'monto': ?monto,
          'cuentaMayor': ?mayor?.id,
          'saldoMayor': ?mayor?.saldoActual,
        },
        // Vuelve con el siguiente vencimiento.
        huella: v.fecha.toIso8601String(),
      ),
    );
  }
  return consejos;
}

/// El plan vigente (moneda principal) con la estrategia elegida o la
/// recomendada; `null` sin deudas.
ResultadoPlan? planVigente(ContextoConsejero c) {
  final comparaciones = compararPlanes(c.deudas, extraMensual: c.extraMensual);
  if (comparaciones.isEmpty) return null;
  final comp = comparaciones.values.first;
  return comp.plan(c.estrategia ?? comp.recomendacion.estrategia);
}

/// Regla 2 — la deuda que conviene pagar primero y cuánto cuesta esperar
/// un mes (interés de un mes sobre su capital). Solo con tasa conocida.
List<Consejo> reglaPagaPrimero(ContextoConsejero c) {
  final plan = planVigente(c);
  if (plan == null || plan.deudas.length < 2) return const [];
  final primera = plan.deudas.first;
  final tasa = primera.tasa;
  if (tasa == null || tasa <= 0) return const [];
  final costoMes = primera.capitalInicial * tasaMensualDesdeAnual(tasa);
  if (costoMes < 1) return const [];
  final m = primera.deuda.moneda;
  final porque = plan.estrategia == EstrategiaPago.bolaDeNieve
      ? 'es la más pequeña: saldarla te libera su pago para la siguiente'
      : 'es la que más interés te cobra (${(tasa * 100).toStringAsFixed(0)} % '
            'al año)';
  return [
    Consejo(
      id: '${ReglaConsejo.pagaPrimero.name}:${primera.deuda.id}',
      regla: ReglaConsejo.pagaPrimero,
      prioridad: 60,
      titulo: 'Pon tu pago extra en ${primera.deuda.nombreDeuda}',
      texto:
          'Según tu plan, $porque. Cada mes que esperas te cuesta unos '
          '${_monto(costoMes, m)} en intereses.',
      accion: const AccionConsejo('Ver mi plan', '/plan-pago'),
      datos: {'deudaId': primera.deuda.id, 'costoMes': costoMes},
      huella: primera.deuda.id,
    ),
  ];
}

/// Regla 3 — tu capacidad segura supera el extra configurado.
List<Consejo> reglaCapacidad(
  ContextoConsejero c, {
  ResultadoCapacidad? capacidad,
}) {
  final r =
      capacidad ??
      calcularCapacidadPago(
        transacciones: c.transacciones,
        deudas: c.deudas,
        ahora: c.ahora,
      );
  if (r is! CapacidadCalculada || r.noAlcanza) return const [];
  if (deudasParaPlan(c.deudas).isEmpty) return const [];
  final mas = r.recomendado - c.extraMensual;
  if (mas < margenMinimoCapacidad) return const [];
  return [
    Consejo(
      id: '${ReglaConsejo.capacidadDisponible.name}:${r.moneda.name}',
      regla: ReglaConsejo.capacidadDisponible,
      prioridad: 50,
      titulo: 'Podrías pagar ${_monto(mas, r.moneda)} más',
      texto:
          'Con tu peor mes de ingresos y tu mes de más gasto, aún te '
          'quedarían ${_monto(r.recomendado, r.moneda)} al mes para tus '
          'deudas (hoy usas ${_monto(c.extraMensual, r.moneda)}).',
      accion: const AccionConsejo('Ver mi capacidad', '/plan-pago/capacidad'),
      datos: {'recomendado': r.recomendado, 'mas': mas},
      // Vuelve si la diferencia cambia en un tramo de S/ 50.
      huella: '${(mas / 50).floor()}',
    ),
  ];
}

/// Regla 4 — uso de la línea de una tarjeta.
List<Consejo> reglaUsoTarjeta(ContextoConsejero c) {
  final consejos = <Consejo>[];
  for (final cuenta in c.cuentas) {
    if (cuenta.tipo != TipoCuenta.credito) continue;
    final linea = cuenta.lineaCredito;
    if (linea == null || linea <= 0) continue;
    final usado = cuenta.saldoActual < 0 ? -cuenta.saldoActual : 0.0;
    final uso = usado / linea;
    if (uso <= umbralUsoTarjeta) continue;
    final alto = uso > umbralUsoTarjetaAlto;
    final pct = (uso * 100).round();
    consejos.add(
      Consejo(
        id: '${ReglaConsejo.usoTarjeta.name}:${cuenta.id}',
        regla: ReglaConsejo.usoTarjeta,
        prioridad: alto ? 80 : 40,
        titulo: 'Usas el $pct % de tu ${cuenta.nombre}',
        texto:
            'Debes ${_monto(usado, cuenta.moneda)} de una línea de '
            '${_monto(linea, cuenta.moneda)}. Bajar de '
            '${(umbralUsoTarjeta * 100).round()} % te deja margen para '
            'imprevistos${alto ? ' y te acerca menos a tu límite' : ''}.',
        accion: AccionConsejo('Pagar tarjeta', '/transferencias/nueva', {
          'destinoId': cuenta.id,
        }),
        datos: {'cuentaId': cuenta.id, 'uso': uso},
        huella: alto ? 'alto' : 'medio',
      ),
    );
  }
  return consejos;
}

/// Regla 5 — deudas en mora.
List<Consejo> reglaMora(ContextoConsejero c) => [
  for (final d in c.deudas)
    if (d.direccion == DireccionDeuda.debo &&
        (d.enMora || d.estado == EstadoDeuda.enMora) &&
        d.estado != EstadoDeuda.pagada)
      Consejo(
        id: '${ReglaConsejo.mora.name}:${d.id}',
        regla: ReglaConsejo.mora,
        prioridad: 90,
        titulo: '${d.nombreDeuda} está en mora',
        texto:
            '${(d.diasMora ?? 0) > 0 ? 'Lleva ${d.diasMora} días vencida. ' : ''}'
            'Ponerte al día primero evita más cargos; si no puedes, '
            'conversa con ${d.nombreAcreedor} para acordar un pago.',
        accion: AccionConsejo('Ver deuda', '/deudas/detalle', d.id),
        datos: {'deudaId': d.id, 'diasMora': d.diasMora ?? 0},
        // Vuelve cada 30 días de mora.
        huella: '${(d.diasMora ?? 0) ~/ 30}',
      ),
];

/// Regla 6 — deudas sin tasa ("Falta la tasa").
List<Consejo> reglaFaltaTasa(ContextoConsejero c) => [
  for (final d in deudasParaPlan(c.deudas))
    if (tasaEfectivaAnual(d) == null)
      Consejo(
        id: '${ReglaConsejo.faltaTasa.name}:${d.id}',
        regla: ReglaConsejo.faltaTasa,
        prioridad: 30,
        titulo: 'Falta la tasa de ${d.nombreDeuda}',
        texto:
            'Sin su tasa, tu plan la calcula sin interés. Agrégala para '
            'saber cuánto te cuesta de verdad.',
        accion: d.cuentaId != null
            ? AccionConsejo('Agregar la TCEA', '/cuentas/nueva', d.cuentaId)
            : AccionConsejo('Agregar la tasa', '/deudas/nueva', d.id),
        datos: {'deudaId': d.id},
        huella: d.id,
      ),
];

/// Regla 7 — gasto del mes en curso en una categoría > [umbralGastoCategoria]
/// veces su promedio de los [mesesPromedioCategoria] meses completos
/// anteriores. Exige que esos meses tengan movimientos (si no, no se sabe
/// el promedio) y un promedio mayor a 0.
List<Consejo> reglaGastoCategoria(ContextoConsejero c) {
  final consejos = <Consejo>[];
  final inicioMes = DateTime(c.ahora.year, c.ahora.month);
  for (final moneda in Moneda.values) {
    final flujos = flujosMensualesCompletos(
      c.transacciones,
      moneda: moneda,
      ahora: c.ahora,
    );
    final anteriores = [
      for (var k = 1; k <= mesesPromedioCategoria; k++)
        DateTime(c.ahora.year, c.ahora.month - k),
    ];
    final mesesConDatos = {for (final f in flujos) f.mes};
    if (!anteriores.every(mesesConDatos.contains)) continue;
    final desde = anteriores.last;

    final actual = <String, double>{};
    final previo = <String, double>{};
    for (final t in c.transacciones) {
      if (t.moneda != moneda || t.tipo != TipoTransaccion.gasto) continue;
      final cat = t.categoriaId;
      if (cat == null) continue;
      if (!t.fecha.isBefore(inicioMes)) {
        if (!t.fecha.isAfter(c.ahora)) {
          actual.update(cat, (v) => v + t.monto, ifAbsent: () => t.monto);
        }
      } else if (!t.fecha.isBefore(desde)) {
        previo.update(cat, (v) => v + t.monto, ifAbsent: () => t.monto);
      }
    }
    for (final MapEntry(key: cat, value: gastado) in actual.entries) {
      final promedio = (previo[cat] ?? 0) / mesesPromedioCategoria;
      if (promedio <= 0) continue;
      final veces = gastado / promedio;
      if (veces <= umbralGastoCategoria) continue;
      final nombre = c.nombresCategoria[cat] ?? 'una categoría';
      consejos.add(
        Consejo(
          id: '${ReglaConsejo.gastoCategoria.name}:$cat',
          regla: ReglaConsejo.gastoCategoria,
          prioridad: 35,
          titulo: 'Este mes llevas ${_monto(gastado, moneda)} en $nombre',
          texto:
              'Es ${veces.toStringAsFixed(1)} veces tu promedio de los '
              'últimos $mesesPromedioCategoria meses '
              '(${_monto(promedio, moneda)}). Si puedes, frena un poco '
              'hasta fin de mes.',
          accion: const AccionConsejo(
            'Ver movimientos',
            '/transacciones/todas',
          ),
          datos: {'categoriaId': cat, 'gastado': gastado, 'promedio': promedio},
          // Vuelve el mes siguiente.
          huella: '${c.ahora.year}-${c.ahora.month}',
        ),
      );
    }
  }
  return consejos;
}

/// Regla 8 — "Si abonas S/ 100 a X ahorras S/ Y y Z meses", con la
/// simulación real del plan (pago único en el mes 1, que va a la deuda
/// prioritaria).
List<Consejo> reglaAbonoSugerido(ContextoConsejero c) {
  final plan = planVigente(c);
  if (plan == null || plan.deudas.isEmpty || !plan.seCompleta) {
    return const [];
  }
  final primera = plan.deudas.first;
  final m = plan.moneda;
  final comp = simularEscenario(
    deudas: c.deudas,
    moneda: m,
    extraActual: plan.extraMensual,
    estrategiaActual: plan.estrategia,
    extraEscenario: plan.extraMensual,
    estrategiaEscenario: plan.estrategia,
    pagoUnico: PagoUnico(mes: 1, monto: montoAbonoSugerido),
  );
  final ahorro = comp.interesAhorrado;
  if (ahorro < ahorroMinimoAbono) return const [];
  final meses = comp.mesesAntes ?? 0;
  return [
    Consejo(
      id: '${ReglaConsejo.abonoSugerido.name}:${primera.deuda.id}',
      regla: ReglaConsejo.abonoSugerido,
      prioridad: 20,
      titulo:
          'Si abonas ${_monto(montoAbonoSugerido, m)} a '
          '${primera.deuda.nombreDeuda}',
      texto:
          'Ahorras ${_monto(ahorro, m)} en intereses'
          '${meses > 0 ? ' y terminas ${meses == 1 ? '1 mes' : '$meses meses'} antes' : ''}.',
      accion: const AccionConsejo('Simular', '/plan-pago/simulador'),
      datos: {'deudaId': primera.deuda.id, 'ahorro': ahorro, 'meses': meses},
      huella: primera.deuda.id,
    ),
  ];
}

/// Todas las reglas, ordenadas por prioridad (desc) y luego por id.
List<Consejo> generarConsejos(
  ContextoConsejero c, {
  ResultadoCapacidad? capacidad,
}) {
  final consejos = [
    ...reglaVencePronto(c),
    ...reglaPagaPrimero(c),
    ...reglaCapacidad(c, capacidad: capacidad),
    ...reglaUsoTarjeta(c),
    ...reglaMora(c),
    ...reglaFaltaTasa(c),
    ...reglaGastoCategoria(c),
    ...reglaAbonoSugerido(c),
  ];
  consejos.sort((a, b) {
    final p = b.prioridad.compareTo(a.prioridad);
    return p != 0 ? p : a.id.compareTo(b.id);
  });
  return consejos;
}

// ---------------------------------------------------------------------
// Descartar / posponer
// ---------------------------------------------------------------------

enum TipoEstadoConsejo { descartado, pospuesto }

/// Lo que hiciste con un consejo.
///
/// CRITERIO "¿cuándo vuelve?":
/// - Pospuesto: vuelve a los [diasPosponerConsejo] días, pase lo que pase.
/// - Descartado: no vuelve mientras su [huella] sea la misma. La huella es
///   un resumen grueso de sus datos de soporte, definido por cada regla:
///   la fecha del vencimiento (vence pronto), la deuda prioritaria (paga
///   primero, abono sugerido), tramos de S/ 50 de la diferencia
///   (capacidad), el tramo de uso >30 % / >70 % (tarjeta), cada 30 días de
///   mora, la deuda (falta tasa) y el mes (gasto por categoría).
class EstadoConsejo {
  final TipoEstadoConsejo tipo;
  final DateTime fecha;
  final String huella;

  const EstadoConsejo({
    required this.tipo,
    required this.fecha,
    required this.huella,
  });

  bool oculta(Consejo consejo, DateTime ahora) => switch (tipo) {
    TipoEstadoConsejo.pospuesto => ahora.isBefore(
      fecha.add(const Duration(days: diasPosponerConsejo)),
    ),
    TipoEstadoConsejo.descartado => consejo.huella == huella,
  };
}

/// Consejos a mostrar: sin los ocultos, en orden; [principales] son los
/// primeros [maximoConsejosVisibles] y [mas] el resto ("Ver más").
class ConsejosVisibles {
  final List<Consejo> principales;
  final List<Consejo> mas;

  const ConsejosVisibles(this.principales, this.mas);

  bool get vacio => principales.isEmpty;
}

ConsejosVisibles consejosVisibles(
  List<Consejo> consejos,
  Map<String, EstadoConsejo> estados,
  DateTime ahora,
) {
  final visibles = [
    for (final c in consejos)
      if (!(estados[c.id]?.oculta(c, ahora) ?? false)) c,
  ];
  return ConsejosVisibles(
    visibles.take(maximoConsejosVisibles).toList(),
    visibles.skip(maximoConsejosVisibles).toList(),
  );
}

// ---------------------------------------------------------------------
// Revisión semanal
// ---------------------------------------------------------------------

class RevisionSemanal {
  final Moneda moneda;

  /// Últimos 7 días: pagos a deudas que debes (incluye transferencias a
  /// tus tarjetas), gastos e ingresos (sin transferencias).
  final double pagadoADeudas;
  final double gastado;
  final double ingresos;

  /// Próximos 7 días (hoy incluido).
  final List<Vencimiento> proximos;

  const RevisionSemanal({
    required this.moneda,
    required this.pagadoADeudas,
    required this.gastado,
    required this.ingresos,
    required this.proximos,
  });
}

/// Revisión de los últimos 7 días y los próximos 7, en [moneda].
RevisionSemanal revisionSemanal(
  ContextoConsejero c, {
  Moneda moneda = Moneda.pen,
}) {
  final hoy = _dia(c.ahora);
  final desde = hoy.subtract(const Duration(days: 7));
  final hasta = hoy.add(const Duration(days: 7));
  bool ultimaSemana(DateTime f) => !f.isBefore(desde) && !f.isAfter(c.ahora);

  final debo = {
    for (final d in c.deudas)
      if (d.direccion == DireccionDeuda.debo && d.moneda == moneda) d.id,
  };
  final tarjetas = {
    for (final x in c.cuentas)
      if (x.tipo == TipoCuenta.credito) x.id,
  };
  var pagado = 0.0;
  for (final p in c.pagosDeuda) {
    if (debo.contains(p.deudaId) && ultimaSemana(p.fechaPago)) {
      pagado += p.montoPagado;
    }
  }
  var gastado = 0.0;
  var ingresos = 0.0;
  for (final t in c.transacciones) {
    if (t.moneda != moneda || !ultimaSemana(t.fecha)) continue;
    switch (t.tipo) {
      case TipoTransaccion.ingreso:
        ingresos += t.monto;
      case TipoTransaccion.gasto:
        gastado += t.monto;
      case TipoTransaccion.transferenciaEntrada:
        // Pagar la tarjeta es pagar una deuda.
        if (tarjetas.contains(t.cuentaId)) pagado += t.monto;
      case TipoTransaccion.transferenciaSalida:
        break;
    }
  }
  return RevisionSemanal(
    moneda: moneda,
    pagadoADeudas: pagado,
    gastado: gastado,
    ingresos: ingresos,
    proximos: [
      for (final v in vencimientos(c.deudas, c.cuentas, c.ahora))
        if (v.deuda.moneda == moneda &&
            !v.fecha.isBefore(hoy) &&
            v.fecha.isBefore(hasta))
          v,
    ],
  );
}
