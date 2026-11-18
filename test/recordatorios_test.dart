import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/recordatorios.dart';
import 'package:finanzas_automaticas/domain/repositories/notificaciones_locales_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/sincronizar_recordatorios.dart';
import 'package:finanzas_automaticas/infrastructure/notificaciones_locales/notificaciones_locales_plugin.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/preferencias_recordatorios_repository_shared_prefs.dart';

/// Fase 87 (E) — recordatorios locales, sin el plugin.
final _ahora = DateTime(2026, 11, 17, 10); // martes

/// 10 cuotas de 440 desde el 20 de agosto; [pagadas] pagadas.
Deuda _prestamo({int pagadas = 3, EstadoDeuda estado = EstadoDeuda.activa}) =>
    Deuda(
      id: 'prestamo',
      nombreDeuda: 'Préstamo personal',
      tipoDeuda: TipoDeuda.prestamoPersonal,
      tipoAcreedor: TipoAcreedor.entidadFinanciera,
      nombreAcreedor: 'BCP',
      moneda: Moneda.pen,
      montoTotal: 4400,
      montoPagado: 440.0 * pagadas,
      tieneInteres: false,
      estructuraPago: EstructuraPago.cuotasFijas,
      numeroCuotasTotal: 10,
      numeroCuotasPagadas: pagadas,
      montoCuota: 440,
      periodicidadCuotas: PeriodicidadCuota.mensual,
      fechaInicio: DateTime(2026, 8, 20),
      enMora: false,
      estado: estado,
    );

Deuda _visa() => Deuda(
  id: 'deuda-visa',
  nombreDeuda: 'Visa BCP',
  tipoDeuda: TipoDeuda.tarjetaCredito,
  tipoAcreedor: TipoAcreedor.entidadFinanciera,
  nombreAcreedor: 'BCP',
  moneda: Moneda.pen,
  montoTotal: 5000,
  montoPagado: 3800,
  tieneInteres: true,
  estructuraPago: EstructuraPago.pagoLibre,
  pagoMinimo: 120,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
  cuentaId: 'visa',
);

final _cuentaVisa = Cuenta(
  id: 'visa',
  nombre: 'Visa BCP',
  tipo: TipoCuenta.credito,
  moneda: Moneda.pen,
  saldoActual: -1200,
  lineaCredito: 5000,
  fechaCorte: DateTime(2026, 10, 10),
  fechaPago: DateTime(2026, 10, 28),
  pagoMinimo: 120,
);

Deuda _lucia({DateTime? proxima}) => Deuda(
  id: 'lucia',
  nombreDeuda: 'Préstamo a Lucía',
  tipoDeuda: TipoDeuda.deudaInformal,
  tipoAcreedor: TipoAcreedor.personaNatural,
  nombreAcreedor: 'Lucía',
  moneda: Moneda.pen,
  montoTotal: 380,
  montoPagado: 0,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 10, 1),
  proximaFechaPago: proxima ?? DateTime(2026, 12, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
  direccion: DireccionDeuda.meDeben,
);

const _vencimientos = ConfigRecordatorios(vencimientos: true);

List<Recordatorio> _calc(
  List<Deuda> deudas, {
  ConfigRecordatorios config = _vencimientos,
  DateTime? ahora,
  List<Cuenta> cuentas = const [],
}) => calcularRecordatorios(
  deudas: deudas,
  cuentas: cuentas,
  ahora: ahora ?? _ahora,
  config: config,
);

class _Fake implements NotificacionesLocalesRepository {
  _Fake({this.permiso = EstadoPermisoNotificaciones.concedido});
  EstadoPermisoNotificaciones permiso;
  final programadas = <int, Recordatorio>{};
  int pedidos = 0;

  @override
  Future<EstadoPermisoNotificaciones> estadoPermiso() async => permiso;
  @override
  Future<bool> pedirPermiso() async {
    pedidos++;
    return permiso == EstadoPermisoNotificaciones.concedido;
  }

  @override
  Future<List<int>> pendientes() async => programadas.keys.toList();
  @override
  Future<void> programar(Recordatorio r) async => programadas[r.id] = r;
  @override
  Future<void> cancelar(int id) async => programadas.remove(id);
  @override
  Future<void> abrirAjustes() async {}
}

void main() {
  test('cuotas: 3 días antes y el mismo día a las 9:00, solo a futuro y '
      'dentro del horizonte', () {
    final r = _calc([_prestamo()]);
    // Vencen 20 nov, 20 dic, 20 ene, 20 feb (20 mar queda fuera de 120
    // días). El aviso de 3 días antes del 20 nov (17 nov 9:00) ya pasó.
    expect(r.map((x) => x.fecha), [
      DateTime(2026, 11, 20, 9),
      DateTime(2026, 12, 17, 9),
      DateTime(2026, 12, 20, 9),
      DateTime(2027, 1, 17, 9),
      DateTime(2027, 1, 20, 9),
      DateTime(2027, 2, 17, 9),
      DateTime(2027, 2, 20, 9),
    ]);
    expect(r.first.cuerpo, 'Hoy vence una cuota de Préstamo personal.');
    expect(r[1].cuerpo, 'En 3 días vence una cuota de Préstamo personal.');
    expect(r.every((x) => x.tipo == TipoRecordatorio.vencimiento), isTrue);
  });

  test('el mismo día: antes de las 9:00 sí, después no', () {
    final dia = DateTime(2026, 11, 20);
    expect(
      _calc([
        _prestamo(),
      ], ahora: dia.add(const Duration(hours: 8))).first.fecha,
      DateTime(2026, 11, 20, 9),
    );
    expect(
      _calc([
        _prestamo(),
      ], ahora: dia.add(const Duration(hours: 10))).first.fecha,
      DateTime(2026, 12, 17, 9),
    );
  });

  test('"Mañana" con 1 día', () {
    final r = _calc([_prestamo()], ahora: DateTime(2026, 11, 16, 8));
    expect(r.first.cuerpo, contains('En 3 días'));
    // Con [3, 0] no hay aviso de "Mañana"; el texto existe para otros días.
    expect(r.where((x) => x.cuerpo.startsWith('Mañana')), isEmpty);
  });

  test('tarjeta: fecha de pago mensual de la cuenta', () {
    final r = _calc([_visa()], cuentas: [_cuentaVisa]);
    expect(r.first.tipo, TipoRecordatorio.pagoTarjeta);
    expect(r.first.fecha, DateTime(2026, 11, 25, 9));
    expect(r[1].fecha, DateTime(2026, 11, 28, 9));
    expect(r[1].cuerpo, 'Hoy vence el pago de tu Visa BCP.');
    // Sin la cuenta (o sin fecha de pago) no se inventa nada.
    expect(_calc([_visa()]), isEmpty);
  });

  test('cobros: solo el día, solo con fecha, y solo si están activos', () {
    const cobros = ConfigRecordatorios(cobros: true);
    final r = _calc([_lucia()], config: cobros);
    expect(r.single.fecha, DateTime(2026, 12, 1, 9));
    expect(r.single.tipo, TipoRecordatorio.cobro);
    expect(r.single.cuerpo, 'Hoy vence lo que te debe Lucía.');
    expect(_calc([_lucia()]), isEmpty, reason: 'cobros apagados');
    expect(
      _calc([_prestamo()], config: cobros),
      isEmpty,
      reason: 'los vencimientos no van con "cobros"',
    );
  });

  test('montos ocultos por defecto; visibles con "Mostrar montos"', () {
    expect(_calc([_prestamo()]).first.cuerpo, isNot(contains('S/')));
    final con = _calc(
      [_prestamo()],
      config: const ConfigRecordatorios(
        vencimientos: true,
        mostrarMontos: true,
      ),
    );
    expect(
      con.first.cuerpo,
      'Hoy vence una cuota de Préstamo personal (S/ 440.00).',
    );
    // Nunca en el título.
    expect(con.every((x) => !x.titulo.contains('S/')), isTrue);
  });

  test('saldadas y canceladas no se programan; todo apagado → nada', () {
    expect(_calc([_prestamo(estado: EstadoDeuda.pagada)]), isEmpty);
    expect(_calc([_prestamo(estado: EstadoDeuda.cancelada)]), isEmpty);
    expect(_calc([_prestamo(pagadas: 10)]), isEmpty);
    expect(
      _calc([_prestamo(), _lucia()], config: const ConfigRecordatorios()),
      isEmpty,
    );
  });

  test('revisión semanal: domingo 19:00 por defecto, 4 próximas', () {
    final r = _calc(
      const [],
      config: const ConfigRecordatorios(revisionSemanal: true),
    );
    expect(r.map((x) => x.fecha), [
      DateTime(2026, 11, 22, 19),
      DateTime(2026, 11, 29, 19),
      DateTime(2026, 12, 6, 19),
      DateTime(2026, 12, 13, 19),
    ]);
    // Configurable: martes 8:30 — hoy martes a las 10:00 ya pasó.
    final martes = _calc(
      const [],
      config: const ConfigRecordatorios(
        revisionSemanal: true,
        diaRevision: DateTime.tuesday,
        horaRevision: 8,
        minutoRevision: 30,
      ),
    );
    expect(martes.first.fecha, DateTime(2026, 11, 24, 8, 30));
  });

  test('tope de $maximoRecordatoriosProgramados: los más cercanos', () {
    final muchas = [
      for (var k = 0; k < 20; k++)
        _prestamo()
            .copyWith(nombreDeuda: 'Deuda $k')
            .let(
              (d) => Deuda(
                id: 'd$k',
                nombreDeuda: d.nombreDeuda,
                tipoDeuda: d.tipoDeuda,
                tipoAcreedor: d.tipoAcreedor,
                nombreAcreedor: d.nombreAcreedor,
                moneda: d.moneda,
                montoTotal: d.montoTotal,
                montoPagado: d.montoPagado,
                tieneInteres: false,
                estructuraPago: d.estructuraPago,
                numeroCuotasTotal: d.numeroCuotasTotal,
                numeroCuotasPagadas: d.numeroCuotasPagadas,
                montoCuota: d.montoCuota,
                periodicidadCuotas: d.periodicidadCuotas,
                fechaInicio: DateTime(2026, 8, 1 + k),
                enMora: false,
                estado: EstadoDeuda.activa,
              ),
            ),
    ];
    final r = _calc(muchas);
    expect(r, hasLength(maximoRecordatoriosProgramados));
    for (var i = 1; i < r.length; i++) {
      expect(r[i].fecha.isBefore(r[i - 1].fecha), isFalse);
    }
    // Lo descartado por el tope es posterior a lo programado.
    final todos = calcularRecordatorios(
      deudas: muchas,
      cuentas: const [],
      ahora: _ahora,
      config: _vencimientos,
    );
    expect(todos.last.fecha, r.last.fecha);
  });

  test('"ahora" fijo → siempre el mismo resultado (ids incluidos)', () {
    final a = _calc([_prestamo()], cuentas: [_cuentaVisa]);
    final b = _calc([_prestamo()], cuentas: [_cuentaVisa]);
    expect(
      [for (final x in a) (x.id, x.fecha, x.cuerpo)],
      [for (final x in b) (x.id, x.fecha, x.cuerpo)],
    );
    expect(idDeterminista('venc:x'), idDeterminista('venc:x'));
    expect(idDeterminista('venc:x'), isNot(idDeterminista('venc:y')));
    expect(idDeterminista('abc'), inInclusiveRange(0, 0x7fffffff));
    expect(a.map((x) => x.id).toSet(), hasLength(a.length));
  });

  group('sincronizar', () {
    test('al pagar una cuota, sus avisos se cancelan', () async {
      final fake = _Fake();
      final sincronizar = SincronizarRecordatorios(fake);
      expect(
        await sincronizar(
          deudas: [_prestamo()],
          cuentas: const [],
          ahora: _ahora,
          config: _vencimientos,
        ),
        ResultadoSincronizacion.programados,
      );
      final idHoy20 = idDeterminista(
        'venc:prestamo:${DateTime(2026, 11, 20).toIso8601String()}:0',
      );
      expect(fake.programadas, contains(idHoy20));
      await sincronizar(
        deudas: [_prestamo(pagadas: 4)],
        cuentas: const [],
        ahora: _ahora,
        config: _vencimientos,
      );
      expect(fake.programadas, isNot(contains(idHoy20)));
      expect(
        fake.programadas.values
            .map((r) => r.fecha)
            .reduce((a, b) => a.isBefore(b) ? a : b),
        DateTime(2026, 12, 17, 9),
      );
    });

    test('sin permiso: no programa nada ni pide permiso', () async {
      final fake = _Fake(permiso: EstadoPermisoNotificaciones.denegado);
      expect(
        await SincronizarRecordatorios(fake)(
          deudas: [_prestamo()],
          cuentas: const [],
          ahora: _ahora,
          config: _vencimientos,
        ),
        ResultadoSincronizacion.sinPermiso,
      );
      expect(fake.programadas, isEmpty);
      expect(fake.pedidos, 0);
    });

    test('todo apagado: cancela lo pendiente', () async {
      final fake = _Fake();
      await SincronizarRecordatorios(fake)(
        deudas: [_prestamo()],
        cuentas: const [],
        ahora: _ahora,
        config: _vencimientos,
      );
      expect(fake.programadas, isNotEmpty);
      expect(
        await SincronizarRecordatorios(fake)(
          deudas: [_prestamo()],
          cuentas: const [],
          ahora: _ahora,
          config: const ConfigRecordatorios(),
        ),
        ResultadoSincronizacion.nadaActivo,
      );
      expect(fake.programadas, isEmpty);
    });
  });

  test('zona horaria: la hora de pared se programa en la zona del usuario', () {
    tz_data.initializeTimeZones();
    final pared = DateTime(2026, 11, 20, 9);
    final lima = enZona(pared, tz.getLocation('America/Lima'));
    expect(lima.toUtc(), DateTime.utc(2026, 11, 20, 14));
    final madrid = enZona(pared, tz.getLocation('Europe/Madrid'));
    expect(madrid.toUtc(), DateTime.utc(2026, 11, 20, 8));
    // Horario de verano: en julio Madrid es UTC+2.
    final julio = enZona(
      DateTime(2026, 7, 1, 9),
      tz.getLocation('Europe/Madrid'),
    );
    expect(julio.toUtc(), DateTime.utc(2026, 7, 1, 7));
  });

  test('preferencias: todo apagado por defecto; ida y vuelta', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = PreferenciasRecordatoriosRepositorySharedPrefs(prefs);
    final d = repo.leer();
    expect(
      [d.vencimientos, d.cobros, d.revisionSemanal, d.mostrarMontos],
      [false, false, false, false],
    );
    expect(
      (d.diaRevision, d.horaRevision, d.minutoRevision),
      (DateTime.sunday, 19, 0),
    );
    await repo.guardar(
      d.copyWith(
        vencimientos: true,
        diaRevision: DateTime.friday,
        horaRevision: 7,
        ofrecimientoHecho: true,
      ),
    );
    final l = repo.leer();
    expect(l.vencimientos, isTrue);
    expect(l.diaRevision, DateTime.friday);
    expect(l.horaRevision, 7);
    expect(l.ofrecimientoHecho, isTrue);
    expect(l.mostrarMontos, isFalse);
  });
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
