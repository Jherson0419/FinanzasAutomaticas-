import 'cronograma_cuotas.dart';
import 'entities/cuenta.dart';
import 'entities/deuda.dart';
import 'proxima_ocurrencia_mensual.dart';
import 'saldo_deuda.dart';

/// Recordatorios locales (Fase 87). Dart puro: dado deudas, "ahora" y la
/// configuración, devuelve QUÉ recordar y CUÁNDO, en hora local "de pared"
/// (DateTime sin zona). El adaptador del plugin la convierte a la zona
/// horaria del teléfono. Mismo "ahora" → siempre el mismo resultado.

/// Días antes del vencimiento en que se avisa (0 = el mismo día).
const diasAvisoVencimiento = [3, 0];

/// Hora local de los avisos de vencimiento y cobro.
const horaRecordatorio = 9;

/// iOS admite como máximo 64 notificaciones pendientes por app; se
/// programan solo las [maximoRecordatoriosProgramados] más cercanas (con
/// margen) y se recalculan al abrir la app y tras cambios en las deudas.
const maximoRecordatoriosProgramados = 40;

/// Hasta cuántos días adelante se buscan vencimientos.
const horizonteDiasRecordatorios = 120;

/// Cuántas revisiones semanales futuras se programan.
const revisionesSemanalesProgramadas = 4;

enum TipoRecordatorio { vencimiento, pagoTarjeta, cobro, revisionSemanal }

/// Configuración (todo apagado hasta que el usuario active algo).
class ConfigRecordatorios {
  final bool vencimientos;
  final bool cobros;
  final bool revisionSemanal;

  /// Día de la revisión (`DateTime.monday` … `DateTime.sunday`).
  final int diaRevision;
  final int horaRevision;
  final int minutoRevision;

  /// Privacidad: por defecto los avisos NO muestran montos.
  final bool mostrarMontos;

  /// "¿Quieres que te recordemos…?" ya se ofreció tras la primera deuda.
  final bool ofrecimientoHecho;

  const ConfigRecordatorios({
    this.vencimientos = false,
    this.cobros = false,
    this.revisionSemanal = false,
    this.diaRevision = DateTime.sunday,
    this.horaRevision = 19,
    this.minutoRevision = 0,
    this.mostrarMontos = false,
    this.ofrecimientoHecho = false,
  });

  bool get algoActivo => vencimientos || cobros || revisionSemanal;

  ConfigRecordatorios copyWith({
    bool? vencimientos,
    bool? cobros,
    bool? revisionSemanal,
    int? diaRevision,
    int? horaRevision,
    int? minutoRevision,
    bool? mostrarMontos,
    bool? ofrecimientoHecho,
  }) => ConfigRecordatorios(
    vencimientos: vencimientos ?? this.vencimientos,
    cobros: cobros ?? this.cobros,
    revisionSemanal: revisionSemanal ?? this.revisionSemanal,
    diaRevision: diaRevision ?? this.diaRevision,
    horaRevision: horaRevision ?? this.horaRevision,
    minutoRevision: minutoRevision ?? this.minutoRevision,
    mostrarMontos: mostrarMontos ?? this.mostrarMontos,
    ofrecimientoHecho: ofrecimientoHecho ?? this.ofrecimientoHecho,
  );
}

class Recordatorio {
  /// Determinista a partir de [clave] (cabe en 31 bits, como pide el
  /// plugin).
  final int id;
  final String clave;
  final TipoRecordatorio tipo;

  /// Fecha y hora LOCAL (de pared).
  final DateTime fecha;
  final String titulo;
  final String cuerpo;

  const Recordatorio({
    required this.id,
    required this.clave,
    required this.tipo,
    required this.fecha,
    required this.titulo,
    required this.cuerpo,
  });
}

/// FNV-1a de 32 bits recortado a 31: el mismo texto da siempre el mismo
/// id (a diferencia de `String.hashCode`, que no está garantizado).
int idDeterminista(String clave) {
  var h = 0x811c9dc5;
  for (final unidad in clave.codeUnits) {
    h ^= unidad;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

String _monto(double v, Moneda m) {
  final s = v.toStringAsFixed(2).split('.');
  final entero = s[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${m == Moneda.pen ? 'S/' : r'US$'} $entero.${s[1]}';
}

String _cuando(int dias) => switch (dias) {
  0 => 'Hoy',
  1 => 'Mañana',
  _ => 'En $dias días',
};

DateTime _dia(DateTime f) => DateTime(f.year, f.month, f.day);

bool _viva(Deuda d) =>
    d.estado != EstadoDeuda.pagada &&
    d.estado != EstadoDeuda.cancelada &&
    saldoPendiente(d) > toleranciaSaldoDeuda;

/// Vencimientos futuros (fecha, monto o `null`) de una deuda que debo.
List<(DateTime, double?)> _vencimientosDe(
  Deuda d,
  Map<String, Cuenta> cuentas,
  DateTime desde,
  DateTime hasta,
) {
  final r = <(DateTime, double?)>[];
  if (d.cuentaId != null) {
    final ancla = cuentas[d.cuentaId]?.fechaPago;
    if (ancla == null) return r;
    var f = proximaOcurrenciaMensual(ancla, desde);
    var k = 0;
    while (!f.isAfter(hasta) && k < 12) {
      r.add((f, d.pagoMinimo));
      f = proximaOcurrenciaMensual(ancla, f.add(const Duration(days: 1)));
      k++;
    }
  } else if (d.estructuraPago == EstructuraPago.cuotasFijas) {
    // Cuotas pendientes del cronograma (los pagos ya hechos no importan:
    // `numeroCuotasPagadas` marca las primeras como pagadas).
    final pagadas = d.numeroCuotasPagadas ?? 0;
    for (final c in generarCronogramaCuotas(d, const [])) {
      if (c.numero <= pagadas) continue;
      final f = _dia(c.fechaVencimiento);
      if (f.isBefore(desde) || f.isAfter(hasta)) continue;
      r.add((f, c.montoEsperado));
    }
  } else if (d.proximaFechaPago != null) {
    r.add((_dia(d.proximaFechaPago!), d.pagoMinimo));
  }
  return r;
}

/// Recordatorios a programar, de los más cercanos a los más lejanos, a lo
/// sumo [maximoRecordatoriosProgramados]. Solo fechas posteriores a
/// [ahora]. Deudas saldadas o canceladas no generan nada.
List<Recordatorio> calcularRecordatorios({
  required List<Deuda> deudas,
  required List<Cuenta> cuentas,
  required DateTime ahora,
  required ConfigRecordatorios config,
}) {
  final hoy = _dia(ahora);
  final hasta = hoy.add(const Duration(days: horizonteDiasRecordatorios));
  final cuentaPorId = {for (final c in cuentas) c.id: c};
  final r = <Recordatorio>[];

  void agregar(
    String clave,
    TipoRecordatorio tipo,
    DateTime fecha,
    String titulo,
    String cuerpo,
  ) {
    if (!fecha.isAfter(ahora)) return;
    r.add(
      Recordatorio(
        id: idDeterminista(clave),
        clave: clave,
        tipo: tipo,
        fecha: fecha,
        titulo: titulo,
        cuerpo: cuerpo,
      ),
    );
  }

  String conMonto(String texto, double? monto, Moneda m) =>
      config.mostrarMontos && monto != null && monto > 0
      ? '$texto (${_monto(monto, m)}).'
      : '$texto.';

  for (final d in deudas) {
    if (!_viva(d)) continue;
    if (d.direccion == DireccionDeuda.debo && config.vencimientos) {
      final esTarjeta = d.cuentaId != null;
      for (final (venc, monto) in _vencimientosDe(d, cuentaPorId, hoy, hasta)) {
        for (final dias in diasAvisoVencimiento) {
          final fecha = venc
              .subtract(Duration(days: dias))
              .add(const Duration(hours: horaRecordatorio));
          final cuerpo = esTarjeta
              ? '${_cuando(dias)} vence el pago de tu ${d.nombreDeuda}'
              : '${_cuando(dias)} vence una cuota de ${d.nombreDeuda}';
          agregar(
            'venc:${d.id}:${venc.toIso8601String()}:$dias',
            esTarjeta
                ? TipoRecordatorio.pagoTarjeta
                : TipoRecordatorio.vencimiento,
            fecha,
            esTarjeta ? 'Pago de tarjeta' : 'Vence una cuota',
            conMonto(cuerpo, monto, d.moneda),
          );
        }
      }
    }
    if (d.direccion == DireccionDeuda.meDeben && config.cobros) {
      // Solo para ti: nunca se avisa a la otra persona.
      final fechaCobro = d.proximaFechaPago ?? d.fechaVencimientoFinal;
      if (fechaCobro == null) continue;
      final venc = _dia(fechaCobro);
      if (venc.isBefore(hoy) || venc.isAfter(hasta)) continue;
      agregar(
        'cobro:${d.id}:${venc.toIso8601String()}',
        TipoRecordatorio.cobro,
        venc.add(const Duration(hours: horaRecordatorio)),
        'Cobro pendiente',
        conMonto(
          'Hoy vence lo que te debe ${d.nombreAcreedor}',
          saldoPendiente(d),
          d.moneda,
        ),
      );
    }
  }

  if (config.revisionSemanal) {
    final delta = (config.diaRevision - hoy.weekday) % 7;
    var f = hoy.add(
      Duration(
        days: delta,
        hours: config.horaRevision,
        minutes: config.minutoRevision,
      ),
    );
    if (!f.isAfter(ahora)) f = f.add(const Duration(days: 7));
    for (var k = 0; k < revisionesSemanalesProgramadas; k++) {
      final fecha = DateTime(
        f.year,
        f.month,
        f.day + 7 * k,
        config.horaRevision,
        config.minutoRevision,
      );
      agregar(
        'revision:${_dia(fecha).toIso8601String()}',
        TipoRecordatorio.revisionSemanal,
        fecha,
        'Tu revisión semanal',
        'Mira cómo te fue esta semana y qué viene.',
      );
    }
  }

  r.sort((a, b) {
    final f = a.fecha.compareTo(b.fecha);
    return f != 0 ? f : a.clave.compareTo(b.clave);
  });
  return r.take(maximoRecordatoriosProgramados).toList();
}

/// Qué hacer con los pendientes del sistema para dejar [deseados]: se
/// cancelan los que ya no corresponden (p. ej. la cuota que acabas de
/// pagar) y se (re)programan los deseados.
({List<int> cancelar, List<Recordatorio> programar}) planSincronizacion(
  Iterable<int> pendientes,
  List<Recordatorio> deseados,
) {
  final ids = {for (final r in deseados) r.id};
  return (
    cancelar: [
      for (final p in pendientes)
        if (!ids.contains(p)) p,
    ],
    programar: deseados,
  );
}
