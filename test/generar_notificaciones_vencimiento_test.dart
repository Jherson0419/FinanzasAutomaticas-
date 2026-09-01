import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/notificacion_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/entities/notificacion.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/domain/usecases/generar_notificaciones_vencimiento.dart';

class _FakeNotificacionRepository implements NotificacionRepository {
  List<NotificacionVencimientoPendiente>? itemsRecibidos;
  int vecesLlamado = 0;

  @override
  Future<List<Notificacion>> obtenerTodas() async => [];
  @override
  Future<void> marcarLeida(String id) async {}

  @override
  Future<void> generarNotificacionesVencimiento(
    List<NotificacionVencimientoPendiente> items,
  ) async {
    vecesLlamado++;
    itemsRecibidos = items;
  }
}

class _FakePreferenciasRepository implements PreferenciasRepository {
  DateTime? ultimaGeneracion;
  DateTime? ultimaGeneracionGuardada;

  @override
  Future<DateTime?> ultimaGeneracionNotificacionesVencimiento() async =>
      ultimaGeneracion;
  @override
  Future<void> guardarUltimaGeneracionNotificacionesVencimiento(
    DateTime fecha,
  ) async => ultimaGeneracionGuardada = fecha;

  @override
  Future<String?> obtenerNombre() async => null;
  @override
  Future<void> guardarNombre(String nombre) async {}
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<bool> recordarSesion() async => true;
  @override
  Future<void> guardarRecordarSesion(bool recordar) async {}
  @override
  Future<void> limpiarTodo() async {}
}

DeudaActivaResumen _deuda({
  required String id,
  bool enMora = false,
  DateTime? fechaVencimientoReal,
}) {
  return DeudaActivaResumen(
    id: id,
    nombreDeuda: 'Deuda $id',
    estructuraPago: EstructuraPago.cuotasFijas,
    proximaFechaPago: fechaVencimientoReal,
    enMora: enMora,
    diasMora: null,
    montoPagado: 0,
    montoTotal: 100,
    montoCuota: 50,
    moneda: Moneda.pen,
    fechaVencimientoReal: fechaVencimientoReal,
  );
}

void main() {
  final hoy = DateTime(2026, 3, 15);

  test(
    'la primera vez (sin ultimaGeneracion previa) genera y guarda la fecha de hoy',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final fakePreferencias = _FakePreferenciasRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: fakePreferencias,
      );

      await generar([
        _deuda(id: 'd1', enMora: true, fechaVencimientoReal: hoy),
      ], ahora: hoy);

      expect(fakeNotificaciones.vecesLlamado, 1);
      expect(fakePreferencias.ultimaGeneracionGuardada, hoy);
    },
  );

  test(
    'si ya se generó hoy, no vuelve a llamar al repositorio ni recalcula nada',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final fakePreferencias = _FakePreferenciasRepository()
        ..ultimaGeneracion = hoy;
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: fakePreferencias,
      );

      await generar([
        _deuda(id: 'd1', enMora: true, fechaVencimientoReal: hoy),
      ], ahora: hoy);

      expect(fakeNotificaciones.vecesLlamado, 0);
    },
  );

  test('si ya se generó un día distinto, vuelve a generar hoy', () async {
    final fakeNotificaciones = _FakeNotificacionRepository();
    final fakePreferencias = _FakePreferenciasRepository()
      ..ultimaGeneracion = hoy.subtract(const Duration(days: 1));
    final generar = GenerarNotificacionesVencimiento(
      notificacionRepository: fakeNotificaciones,
      preferenciasRepository: fakePreferencias,
    );

    await generar([
      _deuda(id: 'd1', enMora: true, fechaVencimientoReal: hoy),
    ], ahora: hoy);

    expect(fakeNotificaciones.vecesLlamado, 1);
    expect(fakePreferencias.ultimaGeneracionGuardada, hoy);
  });

  test(
    'una deuda vencida (enMora) con fecha real se manda como cuota_vencida',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: _FakePreferenciasRepository(),
      );

      await generar([
        _deuda(id: 'd1', enMora: true, fechaVencimientoReal: hoy),
      ], ahora: hoy);

      final items = fakeNotificaciones.itemsRecibidos!;
      expect(items, hasLength(1));
      expect(items.single.deudaId, 'd1');
      expect(items.single.tipo, 'cuota_vencida');
      expect(items.single.fecha, DateTime(hoy.year, hoy.month, hoy.day));
    },
  );

  test(
    'una deuda que vence en 2 días (≤3, no en mora) se manda como cuota_por_vencer',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: _FakePreferenciasRepository(),
      );

      await generar([
        _deuda(
          id: 'd1',
          fechaVencimientoReal: hoy.add(const Duration(days: 2)),
        ),
      ], ahora: hoy);

      expect(fakeNotificaciones.itemsRecibidos!.single.tipo, 'cuota_por_vencer');
    },
  );

  test(
    'una deuda normal (vence en más de 3 días) no genera ningún ítem',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: _FakePreferenciasRepository(),
      );

      await generar([
        _deuda(
          id: 'd1',
          fechaVencimientoReal: hoy.add(const Duration(days: 30)),
        ),
      ], ahora: hoy);

      expect(fakeNotificaciones.vecesLlamado, 0);
    },
  );

  test(
    'una deuda sin fechaVencimientoReal (pagoLibre sin cuenta, o enMora sin '
    'fecha) nunca genera un ítem, aunque esté en mora',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: _FakePreferenciasRepository(),
      );

      await generar([
        _deuda(id: 'd1', enMora: true),
        _deuda(id: 'd2'),
      ], ahora: hoy);

      expect(fakeNotificaciones.vecesLlamado, 0);
    },
  );

  test(
    'con varias deudas, solo las urgentes se mandan al repositorio',
    () async {
      final fakeNotificaciones = _FakeNotificacionRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: fakeNotificaciones,
        preferenciasRepository: _FakePreferenciasRepository(),
      );

      await generar([
        _deuda(id: 'normal', fechaVencimientoReal: hoy.add(const Duration(days: 30))),
        _deuda(id: 'vencida', enMora: true, fechaVencimientoReal: hoy),
        _deuda(id: 'porVencer', fechaVencimientoReal: hoy.add(const Duration(days: 1))),
      ], ahora: hoy);

      final ids = fakeNotificaciones.itemsRecibidos!.map((i) => i.deudaId).toSet();
      expect(ids, {'vencida', 'porVencer'});
    },
  );

  test(
    'sin ninguna deuda urgente, igual guarda la fecha de hoy (para no '
    'recalcular de nuevo si se abre otra vez el mismo día)',
    () async {
      final fakePreferencias = _FakePreferenciasRepository();
      final generar = GenerarNotificacionesVencimiento(
        notificacionRepository: _FakeNotificacionRepository(),
        preferenciasRepository: fakePreferencias,
      );

      await generar([
        _deuda(id: 'normal', fechaVencimientoReal: hoy.add(const Duration(days: 30))),
      ], ahora: hoy);

      expect(fakePreferencias.ultimaGeneracionGuardada, hoy);
    },
  );
}
