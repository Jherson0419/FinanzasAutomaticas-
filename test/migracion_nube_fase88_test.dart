import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/migrar_datos_a_la_nube.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_transferencia.dart';
import 'package:finanzas_automaticas/domain/usecases/sembrar_datos_demo.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';

/// Fase 88 (E) — migración local → nube con TODOS los campos nuevos,
/// idempotente y sin transferencias con una sola cara.

enum _Triggers { actuales, fase89 }

/// "Nube" en memoria. [fallaEn] decide si `crear` de un id debe fallar.
class _Nube {
  final cuentas = <String, Cuenta>{};
  final categorias = <String, Categoria>{};
  final deudas = <String, Deuda>{};
  final transacciones = <String, Transaccion>{};
  final pagos = <String, PagoDeuda>{};
  bool Function(String id) fallaEn = (_) => false;
  bool fallaAlEliminar = false;

  /// Fase 88b — simula los triggers de producción.
  /// `actuales`: fn_actualizar_saldo_cuenta ('ingreso' suma, todo lo demás
  /// resta), fn_actualizar_saldo_por_pago_deuda (siempre resta) y
  /// fn_actualizar_deuda_tras_pago (+monto, +1 cuota, 'pagada' si
  /// monto_pagado >= monto_total). `fase89`: las versiones de
  /// fase89_triggers.sql.
  _Triggers? triggers;

  void alInsertarTransaccion(Transaccion t) {
    final c = cuentas[t.cuentaId];
    if (triggers == null || c == null) return;
    final delta = switch ((triggers!, t.tipo)) {
      (_Triggers.actuales, TipoTransaccion.ingreso) => t.monto,
      (_Triggers.actuales, _) => -t.monto,
      (_Triggers.fase89, TipoTransaccion.ingreso) => t.monto,
      (_Triggers.fase89, TipoTransaccion.transferenciaEntrada) => t.monto,
      (_Triggers.fase89, _) => -t.monto,
    };
    cuentas[c.id] = c.copyWith(saldoActual: c.saldoActual + delta);
  }

  void alInsertarPago(PagoDeuda p) {
    if (triggers == null) return;
    final d = deudas[p.deudaId];
    final c = p.cuentaId == null ? null : cuentas[p.cuentaId];
    if (c != null) {
      final suma =
          triggers == _Triggers.fase89 &&
          d?.direccion == DireccionDeuda.meDeben;
      cuentas[c.id] = c.copyWith(
        saldoActual: c.saldoActual + (suma ? p.montoPagado : -p.montoPagado),
      );
    }
    if (d == null) return;
    final pagado = d.montoPagado + p.montoPagado;
    deudas[d.id] = triggers == _Triggers.actuales
        ? d.copyWith(
            montoPagado: pagado,
            numeroCuotasPagadas: (d.numeroCuotasPagadas ?? 0) + 1,
            estado: pagado >= d.montoTotal ? EstadoDeuda.pagada : null,
          )
        : d.copyWith(montoPagado: pagado);
  }

  void _quizasFalla(String id) {
    if (fallaEn(id)) throw StateError('sin conexión al subir $id');
  }
}

class _CuentasNube implements CuentaRepository {
  _CuentasNube(this.n);
  final _Nube n;
  @override
  Future<List<Cuenta>> obtenerTodas() async => n.cuentas.values.toList();
  @override
  Future<Cuenta?> obtenerPorId(String id) async => n.cuentas[id];
  @override
  Future<void> crear(Cuenta c) async {
    n._quizasFalla(c.id);
    if (n.cuentas.containsKey(c.id)) throw StateError('duplicado ${c.id}');
    n.cuentas[c.id] = c;
  }

  @override
  Future<void> actualizar(Cuenta c) async => n.cuentas[c.id] = c;
  @override
  Future<void> eliminar(String id) async => n.cuentas.remove(id);
}

class _CategoriasNube implements CategoriaRepository {
  _CategoriasNube(this.n);
  final _Nube n;
  @override
  Future<List<Categoria>> obtenerTodas() async => n.categorias.values.toList();
  @override
  Future<Categoria?> obtenerPorId(String id) async => n.categorias[id];
  @override
  Future<void> crear(Categoria c) async {
    n._quizasFalla(c.id);
    if (n.categorias.containsKey(c.id)) throw StateError('duplicado ${c.id}');
    n.categorias[c.id] = c;
  }

  @override
  Future<void> actualizar(Categoria c) async => n.categorias[c.id] = c;
  @override
  Future<void> eliminar(String id) async => n.categorias.remove(id);
}

class _DeudasNube implements DeudaRepository {
  _DeudasNube(this.n);
  final _Nube n;
  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];
  @override
  Future<List<Deuda>> obtenerTodas() async => n.deudas.values.toList();
  @override
  Future<List<Deuda>> obtenerActivas() async => n.deudas.values.toList();
  @override
  Future<Deuda?> obtenerPorId(String id) async => n.deudas[id];
  @override
  Future<void> crear(Deuda d) async {
    n._quizasFalla(d.id);
    if (n.deudas.containsKey(d.id)) throw StateError('duplicado ${d.id}');
    n.deudas[d.id] = d;
  }

  @override
  Future<void> actualizar(Deuda d) async => n.deudas[d.id] = d;
  @override
  Future<void> eliminar(String id) async => n.deudas.remove(id);
}

class _TransaccionesNube implements TransaccionRepository {
  _TransaccionesNube(this.n);
  final _Nube n;
  @override
  Future<List<Transaccion>> obtenerTodas() async =>
      n.transacciones.values.toList();
  @override
  Future<Transaccion?> obtenerPorId(String id) async => n.transacciones[id];
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String c) async =>
      n.transacciones.values.where((t) => t.cuentaId == c).toList();
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String c) async =>
      n.transacciones.values.where((t) => t.categoriaId == c).toList();
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime d,
    DateTime h,
  ) async => n.transacciones.values.toList();
  @override
  Future<List<Transaccion>> obtenerRecientes(int l) async =>
      n.transacciones.values.take(l).toList();
  @override
  Future<void> crear(Transaccion t) async {
    n._quizasFalla(t.id);
    if (n.transacciones.containsKey(t.id)) {
      throw StateError('duplicado ${t.id}');
    }
    n.transacciones[t.id] = t;
    n.alInsertarTransaccion(t);
  }

  @override
  Future<void> actualizar(Transaccion t) async => n.transacciones[t.id] = t;
  @override
  Future<void> eliminar(String id) async {
    if (n.fallaAlEliminar) throw StateError('sin conexión al borrar $id');
    n.transacciones.remove(id);
  }
}

class _PagosNube implements PagoDeudaRepository {
  _PagosNube(this.n);
  final _Nube n;
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String d) async =>
      n.pagos.values.where((p) => p.deudaId == d).toList();
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String c) async =>
      n.pagos.values.where((p) => p.cuentaId == c).toList();
  @override
  Future<void> crear(PagoDeuda p) async {
    n._quizasFalla(p.id);
    if (n.pagos.containsKey(p.id)) throw StateError('duplicado ${p.id}');
    n.pagos[p.id] = p;
    n.alInsertarPago(p);
  }

  @override
  Future<void> eliminar(String id) async => n.pagos.remove(id);
}

class _SinAmigos implements AmistadRepository {
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}
  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;
  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {}
  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      const [];
  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => const [];
  @override
  Future<void> aceptarSolicitud(String solicitudId) async {}
  @override
  Future<void> rechazarSolicitud(String solicitudId) async {}
}

void main() {
  late AppDatabase db;
  late _Nube nube;
  late String idTransferencia;

  MigrarDatosALaNube migrador() => MigrarDatosALaNube(
    cuentaRepositoryLocal: CuentaRepositoryDrift(db),
    categoriaRepositoryLocal: CategoriaRepositoryDrift(db),
    deudaRepositoryLocal: DeudaRepositoryDrift(db),
    transaccionRepositoryLocal: TransaccionRepositoryDrift(db),
    pagoDeudaRepositoryLocal: PagoDeudaRepositoryDrift(db),
    cuentaRepositoryNube: _CuentasNube(nube),
    categoriaRepositoryNube: _CategoriasNube(nube),
    deudaRepositoryNube: _DeudasNube(nube),
    transaccionRepositoryNube: _TransaccionesNube(nube),
    pagoDeudaRepositoryNube: _PagosNube(nube),
  );

  /// Ninguna transferencia de la nube queda con una sola cara.
  void sinTransferenciasCojas() {
    final porId = <String, List<Transaccion>>{};
    for (final t in nube.transacciones.values) {
      if (t.transferenciaId != null) {
        porId.putIfAbsent(t.transferenciaId!, () => []).add(t);
      }
    }
    for (final MapEntry(:key, :value) in porId.entries) {
      expect(value, hasLength(2), reason: 'transferencia $key');
    }
  }

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    nube = _Nube();
    final ahora = DateTime(2026, 11, 17, 10);
    // Datos demo completos: cuentas (Visa con TCEA), deudas (incluida
    // "Lucía te debe"), pagos, historial de 3 meses.
    await SembrarDatosDemo(
      cuentaRepository: CuentaRepositoryDrift(db),
      categoriaRepository: CategoriaRepositoryDrift(db),
      transaccionRepository: TransaccionRepositoryDrift(db),
      deudaRepository: DeudaRepositoryDrift(db),
      pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
    ).call(ahora: ahora);
    // Abono a capital que deja una última cuota parcial (préstamo demo).
    await RegistrarPagoDeuda(
      pagoDeudaRepository: PagoDeudaRepositoryDrift(db),
      deudaRepository: DeudaRepositoryDrift(db),
      cuentaRepository: CuentaRepositoryDrift(db),
      amistadRepository: _SinAmigos(),
    ).call(
      deudaId: SembrarDatosDemo.idDeudaLaptop,
      montoPagado: 100,
      tipo: TipoPagoDeuda.abonoCapital,
      fechaPago: ahora,
    );
    // Transferencia Débito → Visa ("Pagar tarjeta").
    final (salida, _) =
        await RegistrarTransferencia(
          cuentaRepository: CuentaRepositoryDrift(db),
          transaccionRepository: TransaccionRepositoryDrift(db),
          deudaRepository: DeudaRepositoryDrift(db),
        ).call(
          origenId: SembrarDatosDemo.idCuentaBcp,
          destinoId: SembrarDatosDemo.idCuentaVisa,
          monto: 300,
          fecha: ahora,
        );
    idTransferencia = salida.transferenciaId!;
  });
  tearDown(() => db.close());

  test('sube los datos demo completos con todos los campos nuevos', () async {
    final resumen = await migrador()();

    final locales = await DeudaRepositoryDrift(db).obtenerTodas();
    expect(nube.deudas.length, locales.length);
    expect(
      nube.cuentas.length,
      (await CuentaRepositoryDrift(db).obtenerTodas()).length,
    );
    expect(
      nube.transacciones.length,
      (await TransaccionRepositoryDrift(db).obtenerTodas()).length,
    );

    // "Me deben".
    expect(
      nube.deudas[SembrarDatosDemo.idDeudaLucia]!.direccion,
      DireccionDeuda.meDeben,
    );
    // Abono con última cuota parcial.
    final laptop = nube.deudas[SembrarDatosDemo.idDeudaLaptop]!;
    expect(laptop.montoAbonadoCapital, 100);
    expect(laptop.montoUltimaCuota, isNotNull);
    expect(
      nube.pagos.values.where((p) => p.tipo == TipoPagoDeuda.abonoCapital),
      hasLength(1),
    );
    // Visa con TCEA.
    expect(nube.cuentas[SembrarDatosDemo.idCuentaVisa]!.tcea, 0.48);
    // Transferencia: dos caras, sin categoría, mismo id.
    final caras = nube.transacciones.values
        .where((t) => t.transferenciaId == idTransferencia)
        .toList();
    expect(caras.map((t) => t.tipo).toSet(), {
      TipoTransaccion.transferenciaSalida,
      TipoTransaccion.transferenciaEntrada,
    });
    expect(caras.every((t) => t.categoriaId == null), isTrue);
    sinTransferenciasCojas();

    expect(resumen.subidos['deudas'], locales.length);
    expect(resumen.yaEstaban.values.every((v) => v == 0), isTrue);
    expect(resumen.transferenciasIncompletasLocales, isEmpty);
  });

  test('reintento: repetirla no duplica nada', () async {
    await migrador()();
    final antes = (
      nube.cuentas.length,
      nube.deudas.length,
      nube.transacciones.length,
      nube.pagos.length,
    );
    final segunda = await migrador()();
    expect((
      nube.cuentas.length,
      nube.deudas.length,
      nube.transacciones.length,
      nube.pagos.length,
    ), antes);
    // Nada nuevo subido; la reescritura final de saldos sí corre siempre
    // (es idempotente).
    expect(
      segunda.subidos.entries
          .where((e) => e.key != 'saldos reescritos')
          .every((e) => e.value == 0),
      isTrue,
    );
    expect(segunda.yaEstaban['transacciones'], nube.transacciones.length);
    expect(segunda.descripcion, contains('ya estaban'));
  });

  test(
    'fallo a mitad: dice exactamente qué se subió; el reintento termina',
    () async {
      // Falla la deuda de la laptop (3.ª del orden local o la que sea).
      nube.fallaEn = (id) => id == SembrarDatosDemo.idDeudaLaptop;
      final error = await migrador()().then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );
      expect(error, isA<MigracionFallidaException>());
      final e = error! as MigracionFallidaException;
      expect(e.paso, 'deudas');
      final cuentasLocales = (await CuentaRepositoryDrift(
        db,
      ).obtenerTodas()).length;
      expect(e.resumen.subidos['cuentas'], cuentasLocales);
      expect(e.resumen.subidos['deudas'], nube.deudas.length);
      expect(e.resumen.subidos.containsKey('transacciones'), isFalse);
      expect(nube.transacciones, isEmpty);
      expect(e.toString(), contains('Hasta ahí: cuentas: $cuentasLocales'));

      // Se arregla la conexión y se reintenta: no hay duplicados.
      nube.fallaEn = (_) => false;
      final r = await migrador()();
      expect(r.yaEstaban['cuentas'], cuentasLocales);
      expect(
        nube.deudas.length,
        (await DeudaRepositoryDrift(db).obtenerTodas()).length,
      );
      sinTransferenciasCojas();
    },
  );

  test(
    'si falla la 2.ª cara de una transferencia, se deshace la 1.ª',
    () async {
      final entrada = (await TransaccionRepositoryDrift(db).obtenerTodas())
          .firstWhere(
            (t) =>
                t.transferenciaId == idTransferencia &&
                t.tipo == TipoTransaccion.transferenciaEntrada,
          );
      nube.fallaEn = (id) => id == entrada.id;
      final error = await migrador()().then<Object?>(
        (_) => null,
        onError: (Object e) => e,
      );
      final e = error! as MigracionFallidaException;
      expect(e.paso, 'transacciones');
      expect(e.detalle, contains('se deshizo'));
      sinTransferenciasCojas();
      expect(
        nube.transacciones.values.where(
          (t) => t.transferenciaId == idTransferencia,
        ),
        isEmpty,
      );

      nube.fallaEn = (_) => false;
      await migrador()();
      sinTransferenciasCojas();
      expect(
        nube.transacciones.values.where(
          (t) => t.transferenciaId == idTransferencia,
        ),
        hasLength(2),
      );
    },
  );

  test(
    'si tampoco se puede deshacer, lo avisa y el reintento la completa',
    () async {
      final entrada = (await TransaccionRepositoryDrift(db).obtenerTodas())
          .firstWhere(
            (t) =>
                t.transferenciaId == idTransferencia &&
                t.tipo == TipoTransaccion.transferenciaEntrada,
          );
      nube.fallaEn = (id) => id == entrada.id;
      nube.fallaAlEliminar = true;
      final e =
          await migrador()().then<Object?>(
                (_) => null,
                onError: (Object e) => e,
              )
              as MigracionFallidaException;
      expect(e.detalle, contains('ATENCIÓN'));
      expect(e.detalle, contains(idTransferencia));

      nube.fallaEn = (_) => false;
      nube.fallaAlEliminar = false;
      await migrador()();
      sinTransferenciasCojas();
    },
  );

  for (final triggers in _Triggers.values) {
    test('Fase 88b — con los triggers de producción (${triggers.name}) los '
        'saldos y las deudas quedan iguales a los del teléfono', () async {
      nube.triggers = triggers;
      final r = await migrador()();
      for (final local in await CuentaRepositoryDrift(db).obtenerTodas()) {
        expect(
          nube.cuentas[local.id]!.saldoActual,
          closeTo(local.saldoActual, 1e-9),
          reason: local.nombre,
        );
      }
      for (final local in await DeudaRepositoryDrift(db).obtenerTodas()) {
        final enNube = nube.deudas[local.id]!;
        expect(
          enNube.montoPagado,
          local.montoPagado,
          reason: local.nombreDeuda,
        );
        expect(enNube.numeroCuotasPagadas, local.numeroCuotasPagadas);
        expect(enNube.estado, local.estado, reason: local.nombreDeuda);
      }
      expect(
        r.subidos['saldos reescritos'],
        nube.cuentas.length + nube.deudas.length,
      );
    });
  }

  test('control: la simulación de triggers sí altera los saldos', () async {
    nube.triggers = _Triggers.actuales;
    final cuenta = (await CuentaRepositoryDrift(
      db,
    ).obtenerTodas()).firstWhere((c) => c.id == SembrarDatosDemo.idCuentaBcp);
    nube.cuentas[cuenta.id] = cuenta;
    final tx = (await TransaccionRepositoryDrift(
      db,
    ).obtenerTodas()).firstWhere((t) => t.cuentaId == cuenta.id);
    await _TransaccionesNube(nube).crear(tx);
    expect(nube.cuentas[cuenta.id]!.saldoActual, isNot(cuenta.saldoActual));
  });

  test(
    'una transferencia que ya estaba a medias en el teléfono se reporta',
    () async {
      final caras = (await TransaccionRepositoryDrift(
        db,
      ).obtenerTodas()).where((t) => t.transferenciaId == idTransferencia);
      await TransaccionRepositoryDrift(db).eliminar(
        caras
            .firstWhere((t) => t.tipo == TipoTransaccion.transferenciaEntrada)
            .id,
      );
      final r = await migrador()();
      expect(r.transferenciasIncompletasLocales, [idTransferencia]);
    },
  );
}
