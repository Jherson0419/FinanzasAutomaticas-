import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/movimientos.dart';
import 'package:finanzas_automaticas/domain/plan_pago.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/saldo_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/armar_resumen_para_consejos.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/obtener_resumen_dashboard.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_gasto.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_ingreso.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_transferencia.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/transaccion_repository_supabase.dart';

import 'helpers/supabase_cliente.dart';

/// Falla en la llamada número [fallaEn] a `crear` (1 = la primera).
class _TransaccionesQueFallan implements TransaccionRepository {
  _TransaccionesQueFallan(this._real, this.fallaEn);
  final TransaccionRepository _real;
  final int fallaEn;
  var _llamadas = 0;

  @override
  Future<void> crear(Transaccion t) {
    _llamadas++;
    if (_llamadas == fallaEn) throw StateError('sin conexión');
    return _real.crear(t);
  }

  @override
  Future<void> actualizar(Transaccion t) => _real.actualizar(t);
  @override
  Future<void> eliminar(String id) => _real.eliminar(id);
  @override
  Future<List<Transaccion>> obtenerTodas() => _real.obtenerTodas();
  @override
  Future<Transaccion?> obtenerPorId(String id) => _real.obtenerPorId(id);
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String c) =>
      _real.obtenerPorCuenta(c);
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String c) =>
      _real.obtenerPorCategoria(c);
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(DateTime d, DateTime h) =>
      _real.obtenerPorRangoFecha(d, h);
  @override
  Future<List<Transaccion>> obtenerRecientes(int l) =>
      _real.obtenerRecientes(l);
}

void main() {
  late AppDatabase db;
  late CuentaRepositoryDrift cuentas;
  late TransaccionRepositoryDrift transacciones;
  late DeudaRepositoryDrift deudas;
  late CategoriaRepositoryDrift categorias;
  late RegistrarTransferencia transferir;
  late Cuenta debito;
  late Cuenta visa;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    cuentas = CuentaRepositoryDrift(db);
    transacciones = TransaccionRepositoryDrift(db);
    deudas = DeudaRepositoryDrift(db);
    categorias = CategoriaRepositoryDrift(db);
    transferir = RegistrarTransferencia(
      cuentaRepository: cuentas,
      transaccionRepository: transacciones,
      deudaRepository: deudas,
    );
    final registrarCuenta = RegistrarCuenta(
      cuentaRepository: cuentas,
      deudaRepository: deudas,
    );
    debito = await registrarCuenta(
      nombre: 'Débito BCP',
      tipo: TipoCuenta.debito,
      moneda: Moneda.pen,
      saldoInicial: 3000,
    );
    // Tarjeta con S/ 1,200 usados de S/ 5,000 (deuda vinculada).
    visa = await registrarCuenta(
      nombre: 'Visa BCP',
      tipo: TipoCuenta.credito,
      moneda: Moneda.pen,
      saldoInicial: -1200,
      lineaCredito: 5000,
      fechaCorte: DateTime(2026, 11, 10),
      fechaPago: DateTime(2026, 11, 28),
      pagoMinimo: 120,
      tcea: 0.48,
    );
  });
  tearDown(() => db.close());

  Future<double> saldo(String id) async =>
      (await cuentas.obtenerPorId(id))!.saldoActual;

  Future<Deuda> deudaVisa() async =>
      (await deudas.obtenerTodas()).firstWhere((d) => d.cuentaId == visa.id);

  Future<Categoria> categoria(String nombre, TipoCategoria tipo) async =>
      (await categorias.obtenerTodas()).firstWhere(
        (c) => c.nombre == nombre && c.tipo == tipo,
      );

  /// Un ingreso y un gasto "reales" del mes, para comprobar que la
  /// transferencia no altera sus totales.
  Future<void> sembrarMovimientosDelMes() async {
    await RegistrarIngreso(
      cuentaRepository: cuentas,
      transaccionRepository: transacciones,
      deudaRepository: deudas,
    )(
      cuentaId: debito.id,
      categoriaId: (await categoria('Sueldo', TipoCategoria.ingreso)).id,
      monto: 4000,
      moneda: Moneda.pen,
      concepto: 'Sueldo',
      metodoPago: MetodoPago.transferencia,
    );
    await RegistrarGasto(
      cuentaRepository: cuentas,
      transaccionRepository: transacciones,
      deudaRepository: deudas,
    )(
      cuentaId: debito.id,
      categoriaId: (await categoria('Comida', TipoCategoria.gasto)).id,
      monto: 150,
      moneda: Moneda.pen,
      concepto: 'Mercado',
      metodoPago: MetodoPago.tarjeta,
    );
  }

  test('crea 2 movimientos ligados, sin categoría, y mueve los saldos',
      () async {
    final (salida, entrada) = await transferir(
      origenId: debito.id,
      destinoId: visa.id,
      monto: 500,
      nota: 'Pago Visa noviembre',
    );
    expect(salida.tipo, TipoTransaccion.transferenciaSalida);
    expect(entrada.tipo, TipoTransaccion.transferenciaEntrada);
    expect(salida.transferenciaId, isNotNull);
    expect(entrada.transferenciaId, salida.transferenciaId);
    expect(salida.categoriaId, isNull);
    expect(entrada.categoriaId, isNull);
    expect(salida.cuentaId, debito.id);
    expect(entrada.cuentaId, visa.id);
    expect(salida.concepto, 'Pago Visa noviembre');
    expect(salida.metodoPago, MetodoPago.transferencia);

    final guardadas = await transacciones.obtenerTodas();
    expect(guardadas, hasLength(2));
    expect(await saldo(debito.id), 2500);
    expect(await saldo(visa.id), -700);
  });

  test('pagar la tarjeta baja la deuda vinculada y el plan se recalcula',
      () async {
    final antes = await deudaVisa();
    expect(saldoPendiente(antes), 1200);
    final planAntes = compararPlanes(
      await deudas.obtenerTodas(),
      extraMensual: 0,
    )[Moneda.pen]!;

    await transferir(origenId: debito.id, destinoId: visa.id, monto: 500);

    final despues = await deudaVisa();
    expect(saldoPendiente(despues), 700);
    expect(despues.montoTotal, 5000);
    final planDespues = compararPlanes(
      await deudas.obtenerTodas(),
      extraMensual: 0,
    )[Moneda.pen]!;
    expect(planAntes.avalancha.capitalTotal, closeTo(1200, 1e-9));
    expect(planDespues.avalancha.capitalTotal, closeTo(700, 1e-9));
  });

  test('ingresos, gastos, categorías, "Gasto del mes" y consejos quedan '
      'intactos', () async {
    await sembrarMovimientosDelMes();
    final dashboard = ObtenerResumenDashboard(
      cuentaRepository: cuentas,
      transaccionRepository: transacciones,
      categoriaRepository: categorias,
      deudaRepository: deudas,
    );
    final consejos = ArmarResumenParaConsejos(
      deudaRepository: deudas,
      transaccionRepository: transacciones,
      categoriaRepository: categorias,
      cuentaRepository: cuentas,
    );
    Future<List<ResumenGastoCategorias>> gastoDelMes() async {
      final (desde, hasta) = rangoDelMes(DateTime.now());
      final detallados = detallarMovimientos(
        await transacciones.obtenerTodas(),
        await categorias.obtenerTodas(),
        await cuentas.obtenerTodas(),
      );
      return resumenGastoPorCategoria(
        filtrarMovimientos(detallados, desde: desde, hasta: hasta),
      );
    }

    final dAntes = await dashboard();
    final cAntes = await consejos();
    final gAntes = await gastoDelMes();

    await transferir(origenId: debito.id, destinoId: visa.id, monto: 500);

    final dDespues = await dashboard();
    expect(dDespues.ingresosMesPorMoneda, dAntes.ingresosMesPorMoneda);
    expect(dDespues.gastosMesPorMoneda, dAntes.gastosMesPorMoneda);
    expect(dDespues.ingresosMesPorMoneda[Moneda.pen], 4000);
    expect(dDespues.gastosMesPorMoneda[Moneda.pen], 150);
    expect(
      dDespues.gastoPorCategoriaMes.map((g) => (g.nombre, g.monto)),
      dAntes.gastoPorCategoriaMes.map((g) => (g.nombre, g.monto)),
    );
    // Saldo disponible: la tarjeta no cuenta como fondos; el débito baja.
    expect(dDespues.saldoTotalPorMoneda[Moneda.pen], 3000 + 4000 - 150 - 500);
    // Movimientos recientes: la transferencia es UNA fila.
    expect(
      dDespues.movimientosRecientes.where((m) => m.transferenciaId != null),
      hasLength(1),
    );

    final cDespues = await consejos();
    String plano(List<dynamic> l) => [
      for (final c in l) '${c.categoriaNombre}:${c.monto}:${c.moneda}',
    ].join(',');
    expect(plano(cDespues.ingresosPorCategoriaMes), plano(cAntes.ingresosPorCategoriaMes));
    expect(plano(cDespues.gastosPorCategoriaMes), plano(cAntes.gastosPorCategoriaMes));
    expect(
      [
        ...cDespues.ingresosPorCategoriaMes,
        ...cDespues.gastosPorCategoriaMes,
      ].any((c) => c.categoriaNombre == 'Transferencia' ||
          c.categoriaNombre == 'Sin categoría'),
      isFalse,
    );

    final gDespues = await gastoDelMes();
    expect(gDespues.single.total, gAntes.single.total);
    expect(gDespues.single.total, 150);
  });

  test('Movimientos: una sola fila sin filtro de cuenta, la cara de cada '
      'cuenta con filtro, y el filtro "Transferencias"', () async {
    await sembrarMovimientosDelMes();
    await transferir(origenId: debito.id, destinoId: visa.id, monto: 500);
    final todasCuentas = await cuentas.obtenerTodas();
    final detallados = detallarMovimientos(
      await transacciones.obtenerTodas(),
      await categorias.obtenerTodas(),
      todasCuentas,
    );
    final sinFiltro = filtrarMovimientos(detallados);
    expect(sinFiltro.where((m) => m.transaccion.esTransferencia), hasLength(1));
    expect(
      filtrarMovimientos(detallados, soloTransferencias: true).single
          .transaccion
          .tipo,
      TipoTransaccion.transferenciaSalida,
    );
    expect(
      filtrarMovimientos(detallados, cuentaId: visa.id).single.transaccion.tipo,
      TipoTransaccion.transferenciaEntrada,
    );

    final pares = cuentasDeTransferencias(
      detallados.map((m) => m.transaccion),
    );
    final nombres = {for (final c in todasCuentas) c.id: c.nombre};
    final salida = detallados
        .firstWhere(
          (m) => m.transaccion.tipo == TipoTransaccion.transferenciaSalida,
        )
        .transaccion;
    final entrada = detallados
        .firstWhere(
          (m) => m.transaccion.tipo == TipoTransaccion.transferenciaEntrada,
        )
        .transaccion;
    expect(
      tituloTransferencia(salida, pares, nombres),
      'Transferencia a Visa BCP',
    );
    expect(
      tituloTransferencia(entrada, pares, nombres),
      'Transferencia desde Débito BCP',
    );
    // Subtotal del día: solo ingresos − gastos.
    final hoy = agruparPorDia(sinFiltro, ahora: DateTime.now());
    final neto = hoy.fold<double>(
      0,
      (s, g) => s + (g.subtotalNeto[Moneda.pen] ?? 0),
    );
    expect(neto, 4000 - 150);
  });

  test('borrar (desde cualquiera de las dos caras) revierte todo, también '
      'la deuda de la tarjeta', () async {
    final (_, entrada) = await transferir(
      origenId: debito.id,
      destinoId: visa.id,
      monto: 500,
    );
    await EliminarTransaccion(
      transaccionRepository: transacciones,
      cuentaRepository: cuentas,
      deudaRepository: deudas,
    )(transaccionId: entrada.id);
    expect(await transacciones.obtenerTodas(), isEmpty);
    expect(await saldo(debito.id), 3000);
    expect(await saldo(visa.id), -1200);
    expect(saldoPendiente(await deudaVisa()), 1200);

    final (salida2, _) = await transferir(
      origenId: debito.id,
      destinoId: visa.id,
      monto: 300,
    );
    await EliminarTransferencia(
      cuentaRepository: cuentas,
      transaccionRepository: transacciones,
      deudaRepository: deudas,
    )(transferenciaId: salida2.transferenciaId!);
    expect(await transacciones.obtenerTodas(), isEmpty);
    expect(await saldo(debito.id), 3000);
    expect(await saldo(visa.id), -1200);
  });

  test('rechazos sin escribir nada: misma cuenta, monedas distintas, monto '
      '≤ 0 y cuenta inexistente', () async {
    final usd = await RegistrarCuenta(
      cuentaRepository: cuentas,
      deudaRepository: deudas,
    )(nombre: 'Dólares', tipo: TipoCuenta.debito, moneda: Moneda.usd);
    await expectLater(
      transferir(origenId: debito.id, destinoId: debito.id, monto: 10),
      throwsArgumentError,
    );
    await expectLater(
      transferir(origenId: debito.id, destinoId: usd.id, monto: 10),
      throwsStateError,
    );
    for (final monto in [0.0, -5.0, double.nan]) {
      await expectLater(
        transferir(origenId: debito.id, destinoId: visa.id, monto: monto),
        throwsArgumentError,
        reason: '$monto',
      );
    }
    await expectLater(
      transferir(origenId: debito.id, destinoId: 'no-existe', monto: 10),
      throwsArgumentError,
    );
    expect(await transacciones.obtenerTodas(), isEmpty);
    expect(await saldo(debito.id), 3000);
    expect(await saldo(visa.id), -1200);
    expect(await saldo(usd.id), 0);
  });

  test('si falla a mitad, informa qué quedó hecho', () async {
    final conFallo = RegistrarTransferencia(
      cuentaRepository: cuentas,
      transaccionRepository: _TransaccionesQueFallan(transacciones, 2),
      deudaRepository: deudas,
    );
    final error = await conFallo(
      origenId: debito.id,
      destinoId: visa.id,
      monto: 500,
    ).then<Object?>((_) => null, onError: (Object e) => e);
    expect(error, isA<TransferenciaIncompleta>());
    final incompleta = error! as TransferenciaIncompleta;
    expect(incompleta.hechos, [
      'salida registrada en Débito BCP',
      'saldo de Débito BCP actualizado',
    ]);
    expect(incompleta.mensaje, contains('quedó a medias'));
    // Lo hecho se puede deshacer borrando la transferencia.
    await EliminarTransferencia(
      cuentaRepository: cuentas,
      transaccionRepository: transacciones,
      deudaRepository: deudas,
    )(transferenciaId: incompleta.transferenciaId);
    expect(await saldo(debito.id), 3000);
    expect(await saldo(visa.id), -1200);
  });

  test('una transferencia no se edita; un movimiento no pasa a serlo',
      () async {
    final (salida, _) = await transferir(
      origenId: debito.id,
      destinoId: visa.id,
      monto: 500,
    );
    final editar = EditarTransaccion(
      transaccionRepository: transacciones,
      cuentaRepository: cuentas,
      deudaRepository: deudas,
    );
    await expectLater(
      editar(
        transaccionId: salida.id,
        cuentaId: debito.id,
        categoriaId: 'x',
        monto: 1,
        moneda: Moneda.pen,
        tipo: TipoTransaccion.gasto,
        concepto: 'x',
        metodoPago: MetodoPago.efectivo,
      ),
      throwsStateError,
    );
    expect(await saldo(debito.id), 2500);
  });

  group('Supabase: mapeo tolerante', () {
    test('tipo, transferencia_id y categoría NULL', () async {
      final repo = TransaccionRepositorySupabase(
        await clienteSupabaseAutenticado('user-1'),
      );
      final (salida, entrada) = await transferir(
        origenId: debito.id,
        destinoId: visa.id,
        monto: 500,
      );
      final fila = repo.aFila(salida);
      expect(fila['tipo'], 'transferencia_salida');
      expect(fila['transferencia_id'], salida.transferenciaId);
      expect(fila['categoria_id'], isNull);
      expect(repo.aFila(entrada)['tipo'], 'transferencia_entrada');
      final vuelta = repo.aDominio({...fila, 'fecha': fila['fecha']});
      expect(vuelta.tipo, TipoTransaccion.transferenciaSalida);
      expect(vuelta.transferenciaId, salida.transferenciaId);
      expect(vuelta.categoriaId, isNull);

      // Un gasto normal no envía la columna; sin columna → null.
      await sembrarMovimientosDelMes();
      final gasto = (await transacciones.obtenerTodas()).firstWhere(
        (t) => t.tipo == TipoTransaccion.gasto,
      );
      final filaGasto = repo.aFila(gasto);
      expect(filaGasto.containsKey('transferencia_id'), isFalse);
      expect(repo.aDominio(filaGasto).transferenciaId, isNull);
    });
  });
}
