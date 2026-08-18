import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/migrar_datos_a_la_nube.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final List<Cuenta> semilla;
  final List<String>? registroOrden;
  final List<Cuenta> creadas = [];

  _FakeCuentaRepository({this.semilla = const [], this.registroOrden});

  @override
  Future<List<Cuenta>> obtenerTodas() async => [...semilla, ...creadas];
  @override
  Future<Cuenta?> obtenerPorId(String id) async => null;
  @override
  Future<void> crear(Cuenta cuenta) async {
    registroOrden?.add('cuenta:${cuenta.id}');
    creadas.add(cuenta);
  }

  @override
  Future<void> actualizar(Cuenta cuenta) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
  @override
  Future<void> eliminar(String id) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
}

class _FakeCategoriaRepository implements CategoriaRepository {
  final List<Categoria> semilla;
  final List<String>? registroOrden;
  final List<Categoria> creadas = [];

  _FakeCategoriaRepository({this.semilla = const [], this.registroOrden});

  @override
  Future<List<Categoria>> obtenerTodas() async => [...semilla, ...creadas];
  @override
  Future<Categoria?> obtenerPorId(String id) async => null;
  @override
  Future<void> crear(Categoria categoria) async {
    registroOrden?.add('categoria:${categoria.id}');
    creadas.add(categoria);
  }

  @override
  Future<void> actualizar(Categoria categoria) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
  @override
  Future<void> eliminar(String id) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
}

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> semilla;
  final List<String>? registroOrden;
  final bool fallaAlCrear;
  final List<Deuda> creadas = [];

  _FakeDeudaRepository({
    this.semilla = const [],
    this.registroOrden,
    this.fallaAlCrear = false,
  });

  @override
  Future<List<Deuda>> obtenerTodas() async => [...semilla, ...creadas];
  @override
  Future<List<Deuda>> obtenerActivas() async => const [];
  @override
  Future<Deuda?> obtenerPorId(String id) async => null;
  @override
  Future<void> crear(Deuda deuda) async {
    if (fallaAlCrear) throw StateError('falla simulada: deudas');
    registroOrden?.add('deuda:${deuda.id}');
    creadas.add(deuda);
  }

  @override
  Future<void> actualizar(Deuda deuda) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
  @override
  Future<void> eliminar(String id) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
}

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> semilla;
  final List<String>? registroOrden;
  final List<Transaccion> creadas = [];

  _FakeTransaccionRepository({this.semilla = const [], this.registroOrden});

  @override
  Future<List<Transaccion>> obtenerTodas() async => [...semilla, ...creadas];
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      const [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];
  @override
  Future<void> crear(Transaccion transaccion) async {
    registroOrden?.add('transaccion:${transaccion.id}');
    creadas.add(transaccion);
  }

  @override
  Future<void> actualizar(Transaccion transaccion) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
  @override
  Future<void> eliminar(String id) async =>
      throw UnimplementedError('no debería llamarse durante la migración');
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  final Map<String, List<PagoDeuda>> semillaPorDeuda;
  final List<String>? registroOrden;
  final List<PagoDeuda> creados = [];

  _FakePagoDeudaRepository({
    this.semillaPorDeuda = const {},
    this.registroOrden,
  });

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => [
    ...?semillaPorDeuda[deudaId],
    ...creados.where((p) => p.deudaId == deudaId),
  ];
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<void> crear(PagoDeuda pago) async {
    registroOrden?.add('pago:${pago.id}');
    creados.add(pago);
  }

  @override
  Future<void> eliminar(String id) async {
    creados.removeWhere((p) => p.id == id);
  }
}

Cuenta _cuenta(String id) => Cuenta(
  id: id,
  nombre: 'Cuenta $id',
  tipo: TipoCuenta.efectivo,
  moneda: Moneda.pen,
  saldoActual: 100,
);

Categoria _categoriaPropia(String id) => Categoria(
  id: id,
  nombre: 'Categoría $id',
  tipo: TipoCategoria.gasto,
  iconName: 'category',
  esPredeterminada: false,
);

Categoria _categoriaPredeterminada(String id) => Categoria(
  id: id,
  nombre: 'Predeterminada $id',
  tipo: TipoCategoria.gasto,
  iconName: 'restaurant',
  esPredeterminada: true,
);

Deuda _deuda(String id) => Deuda(
  id: id,
  nombreDeuda: 'Deuda $id',
  tipoDeuda: TipoDeuda.prestamoPersonal,
  tipoAcreedor: TipoAcreedor.personaNatural,
  nombreAcreedor: 'Acreedor',
  moneda: Moneda.pen,
  montoTotal: 1000,
  montoPagado: 0,
  tieneInteres: false,
  estructuraPago: EstructuraPago.pagoLibre,
  fechaInicio: DateTime(2026, 1, 1),
  enMora: false,
  estado: EstadoDeuda.activa,
);

Transaccion _transaccion(
  String id, {
  String cuentaId = 'cta-1',
  String categoriaId = 'cat-1',
}) => Transaccion(
  id: id,
  cuentaId: cuentaId,
  categoriaId: categoriaId,
  monto: 10,
  moneda: Moneda.pen,
  tipo: TipoTransaccion.gasto,
  concepto: 'Movimiento $id',
  metodoPago: MetodoPago.efectivo,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: DateTime(2026, 2, 1),
);

PagoDeuda _pago(String id, String deudaId) => PagoDeuda(
  id: id,
  deudaId: deudaId,
  cuentaId: 'cta-1',
  montoPagado: 50,
  fechaPago: DateTime(2026, 2, 15),
);

void main() {
  test(
    'sube todo preservando IDs, en el orden cuentas→categorías→deudas→transacciones→pagos, sin migrar predeterminadas',
    () async {
      final orden = <String>[];

      final cuentaLocal = _FakeCuentaRepository(semilla: [_cuenta('cta-1')]);
      final categoriaLocal = _FakeCategoriaRepository(
        semilla: [
          _categoriaPredeterminada('cat-pred'),
          _categoriaPropia('cat-1'),
        ],
      );
      final deudaLocal = _FakeDeudaRepository(semilla: [_deuda('deuda-1')]);
      final transaccionLocal = _FakeTransaccionRepository(
        semilla: [_transaccion('tx-1')],
      );
      final pagoLocal = _FakePagoDeudaRepository(
        semillaPorDeuda: {
          'deuda-1': [_pago('pago-1', 'deuda-1')],
        },
      );

      final cuentaNube = _FakeCuentaRepository(registroOrden: orden);
      final categoriaNube = _FakeCategoriaRepository(registroOrden: orden);
      final deudaNube = _FakeDeudaRepository(registroOrden: orden);
      final transaccionNube = _FakeTransaccionRepository(registroOrden: orden);
      final pagoNube = _FakePagoDeudaRepository(registroOrden: orden);

      final migrar = MigrarDatosALaNube(
        cuentaRepositoryLocal: cuentaLocal,
        categoriaRepositoryLocal: categoriaLocal,
        deudaRepositoryLocal: deudaLocal,
        transaccionRepositoryLocal: transaccionLocal,
        pagoDeudaRepositoryLocal: pagoLocal,
        cuentaRepositoryNube: cuentaNube,
        categoriaRepositoryNube: categoriaNube,
        deudaRepositoryNube: deudaNube,
        transaccionRepositoryNube: transaccionNube,
        pagoDeudaRepositoryNube: pagoNube,
      );

      final etapas = <String>[];
      await migrar(onProgreso: etapas.add);

      expect(cuentaNube.creadas.map((c) => c.id), ['cta-1']);
      expect(categoriaNube.creadas.map((c) => c.id), ['cat-1']);
      expect(deudaNube.creadas.map((d) => d.id), ['deuda-1']);
      expect(transaccionNube.creadas.map((t) => t.id), ['tx-1']);
      expect(pagoNube.creados.map((p) => p.id), ['pago-1']);

      expect(orden, [
        'cuenta:cta-1',
        'categoria:cat-1',
        'deuda:deuda-1',
        'transaccion:tx-1',
        'pago:pago-1',
      ]);

      expect(etapas, isNotEmpty);
      expect(etapas.last, 'Verificando...');
    },
  );

  test(
    'si una inserción falla a mitad de camino, propaga el error con el paso y no sube los pasos siguientes ni toca los repos locales',
    () async {
      final cuentaLocal = _FakeCuentaRepository(semilla: [_cuenta('cta-1')]);
      final categoriaLocal = _FakeCategoriaRepository(
        semilla: [_categoriaPropia('cat-1')],
      );
      final deudaLocal = _FakeDeudaRepository(semilla: [_deuda('deuda-1')]);
      final transaccionLocal = _FakeTransaccionRepository(
        semilla: [_transaccion('tx-1')],
      );
      final pagoLocal = _FakePagoDeudaRepository();

      final cuentaNube = _FakeCuentaRepository();
      final categoriaNube = _FakeCategoriaRepository();
      // Las deudas fallan al subir — cuentas y categorías ya se subieron.
      final deudaNube = _FakeDeudaRepository(fallaAlCrear: true);
      final transaccionNube = _FakeTransaccionRepository();
      final pagoNube = _FakePagoDeudaRepository();

      final migrar = MigrarDatosALaNube(
        cuentaRepositoryLocal: cuentaLocal,
        categoriaRepositoryLocal: categoriaLocal,
        deudaRepositoryLocal: deudaLocal,
        transaccionRepositoryLocal: transaccionLocal,
        pagoDeudaRepositoryLocal: pagoLocal,
        cuentaRepositoryNube: cuentaNube,
        categoriaRepositoryNube: categoriaNube,
        deudaRepositoryNube: deudaNube,
        transaccionRepositoryNube: transaccionNube,
        pagoDeudaRepositoryNube: pagoNube,
      );

      await expectLater(
        () => migrar(),
        throwsA(
          isA<MigracionFallidaException>().having(
            (e) => e.paso,
            'paso',
            'deudas',
          ),
        ),
      );

      // Los pasos anteriores sí llegaron a subirse (no hay forma de
      // deshacerlos sin transacciones distribuidas, pero los siguientes no
      // deben ejecutarse).
      expect(cuentaNube.creadas, hasLength(1));
      expect(categoriaNube.creadas, hasLength(1));
      expect(transaccionNube.creadas, isEmpty);
      expect(pagoNube.creados, isEmpty);

      // Ningún repositorio local se escribió — MigrarDatosALaNube nunca
      // borra ni modifica nada local, esa es responsabilidad exclusiva de
      // MigrarDatosScreen y solo tras terminar sin errores.
      expect(cuentaLocal.creadas, isEmpty);
      expect(categoriaLocal.creadas, isEmpty);
    },
  );

  test(
    'si la verificación final no cuadra los conteos, lanza MigracionFallidaException',
    () async {
      final cuentaLocal = _FakeCuentaRepository(
        semilla: [_cuenta('cta-1'), _cuenta('cta-2')],
      );

      // El fake de cuentas en la nube "pierde" una cuenta al contar de
      // vuelta (simula una discrepancia real de red/RLS).
      final cuentaNube = _CuentaRepositoryQueMientaAlContar();

      final migrar = MigrarDatosALaNube(
        cuentaRepositoryLocal: cuentaLocal,
        categoriaRepositoryLocal: _FakeCategoriaRepository(),
        deudaRepositoryLocal: _FakeDeudaRepository(),
        transaccionRepositoryLocal: _FakeTransaccionRepository(),
        pagoDeudaRepositoryLocal: _FakePagoDeudaRepository(),
        cuentaRepositoryNube: cuentaNube,
        categoriaRepositoryNube: _FakeCategoriaRepository(),
        deudaRepositoryNube: _FakeDeudaRepository(),
        transaccionRepositoryNube: _FakeTransaccionRepository(),
        pagoDeudaRepositoryNube: _FakePagoDeudaRepository(),
      );

      await expectLater(
        () => migrar(),
        throwsA(
          isA<MigracionFallidaException>().having(
            (e) => e.paso,
            'paso',
            contains('verificación'),
          ),
        ),
      );
    },
  );
}

/// Sube las cuentas normalmente pero `obtenerTodas()` (usado por la
/// verificación final) devuelve una menos de las que en verdad "subió" —
/// simula que la subida pareció exitosa pero el conteo posterior no cuadra.
class _CuentaRepositoryQueMientaAlContar implements CuentaRepository {
  final List<Cuenta> creadas = [];

  @override
  Future<void> crear(Cuenta cuenta) async => creadas.add(cuenta);
  @override
  Future<List<Cuenta>> obtenerTodas() async =>
      creadas.isEmpty ? [] : creadas.sublist(0, creadas.length - 1);
  @override
  Future<Cuenta?> obtenerPorId(String id) async => null;
  @override
  Future<void> actualizar(Cuenta cuenta) async {}
  @override
  Future<void> eliminar(String id) async {}
}
