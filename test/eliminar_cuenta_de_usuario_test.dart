import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_cuenta_de_usuario.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final List<Cuenta> cuentas;
  final List<String>? registroOrden;
  _FakeCuentaRepository(this.cuentas, {this.registroOrden});

  @override
  Future<List<Cuenta>> obtenerTodas() async => List.of(cuentas);
  @override
  Future<Cuenta?> obtenerPorId(String id) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> crear(Cuenta cuenta) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> actualizar(Cuenta cuenta) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> eliminar(String id) async {
    registroOrden?.add('cuenta:$id');
    cuentas.removeWhere((c) => c.id == id);
  }
}

class _FakeCategoriaRepository implements CategoriaRepository {
  final List<Categoria> categorias;
  final List<String>? registroOrden;
  _FakeCategoriaRepository(this.categorias, {this.registroOrden});

  @override
  Future<List<Categoria>> obtenerTodas() async => List.of(categorias);
  @override
  Future<Categoria?> obtenerPorId(String id) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> crear(Categoria categoria) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> actualizar(Categoria categoria) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> eliminar(String id) async {
    registroOrden?.add('categoria:$id');
    categorias.removeWhere((c) => c.id == id);
  }
}

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas;
  final List<String>? registroOrden;
  final Set<String> fallanUnaVez;
  _FakeDeudaRepository(
    this.deudas, {
    this.registroOrden,
    Set<String>? fallanUnaVez,
  }) : fallanUnaVez = fallanUnaVez ?? <String>{};

  @override
  Future<List<Deuda>> obtenerTodas() async => List.of(deudas);
  @override
  Future<List<Deuda>> obtenerActivas() async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<Deuda?> obtenerPorId(String id) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> crear(Deuda deuda) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> actualizar(Deuda deuda) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> eliminar(String id) async {
    if (fallanUnaVez.remove(id)) {
      throw StateError('falla de red simulada al borrar la deuda $id');
    }
    registroOrden?.add('deuda:$id');
    deudas.removeWhere((d) => d.id == id);
  }
}

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  final List<String>? registroOrden;
  _FakeTransaccionRepository(this.transacciones, {this.registroOrden});

  @override
  Future<List<Transaccion>> obtenerTodas() async => List.of(transacciones);
  @override
  Future<Transaccion?> obtenerPorId(String id) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> crear(Transaccion transaccion) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> actualizar(Transaccion transaccion) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> eliminar(String id) async {
    registroOrden?.add('transaccion:$id');
    transacciones.removeWhere((t) => t.id == id);
  }
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  final List<PagoDeuda> pagos;
  final List<String>? registroOrden;
  _FakePagoDeudaRepository(this.pagos, {this.registroOrden});

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async =>
      pagos.where((p) => p.deudaId == deudaId).toList();
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> crear(PagoDeuda pago) async =>
      throw UnimplementedError('no se usa al eliminar la cuenta de usuario');
  @override
  Future<void> eliminar(String id) async {
    registroOrden?.add('pago:$id');
    pagos.removeWhere((p) => p.id == id);
  }
}

class _FakeAuthRepository implements AuthRepository {
  final List<String>? registroOrden;
  final bool fallaAlEliminar;
  int vecesLlamado = 0;
  bool _haySesion = true;

  _FakeAuthRepository({this.registroOrden, this.fallaAlEliminar = false});

  @override
  bool get haySesionActiva => _haySesion;
  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> cerrarSesion() async => _haySesion = false;

  @override
  Future<void> iniciarSesionConGoogle() async {}
  @override
  Future<void> eliminarCuenta() async {
    vecesLlamado++;
    if (fallaAlEliminar) {
      throw StateError('falla de red simulada al eliminar la cuenta de auth');
    }
    registroOrden?.add('auth');
    _haySesion = false;
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

Transaccion _transaccion(String id) => Transaccion(
  id: id,
  cuentaId: 'cta-1',
  categoriaId: 'cat-1',
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
    'borra en el orden pagos→transacciones→deudas→categorías propias→cuentas, '
    'respeta las categorías predeterminadas y solo al final borra la cuenta de auth',
    () async {
      final orden = <String>[];

      final cuentaRepo = _FakeCuentaRepository([
        _cuenta('cta-1'),
      ], registroOrden: orden);
      final categoriaRepo = _FakeCategoriaRepository([
        _categoriaPredeterminada('cat-pred'),
        _categoriaPropia('cat-1'),
      ], registroOrden: orden);
      final deudaRepo = _FakeDeudaRepository([
        _deuda('deuda-1'),
      ], registroOrden: orden);
      final transaccionRepo = _FakeTransaccionRepository([
        _transaccion('tx-1'),
      ], registroOrden: orden);
      final pagoRepo = _FakePagoDeudaRepository([
        _pago('pago-1', 'deuda-1'),
      ], registroOrden: orden);
      final authRepo = _FakeAuthRepository(registroOrden: orden);

      final eliminar = EliminarCuentaDeUsuario(
        cuentaRepository: cuentaRepo,
        categoriaRepository: categoriaRepo,
        deudaRepository: deudaRepo,
        transaccionRepository: transaccionRepo,
        pagoDeudaRepository: pagoRepo,
        authRepository: authRepo,
      );

      final etapas = <String>[];
      await eliminar(onProgreso: etapas.add);

      expect(orden, [
        'pago:pago-1',
        'transaccion:tx-1',
        'deuda:deuda-1',
        'categoria:cat-1',
        'cuenta:cta-1',
        'auth',
      ]);

      // La categoría predeterminada nunca se toca — no es del usuario.
      expect(categoriaRepo.categorias.map((c) => c.id), ['cat-pred']);
      expect(cuentaRepo.cuentas, isEmpty);
      expect(deudaRepo.deudas, isEmpty);
      expect(transaccionRepo.transacciones, isEmpty);
      expect(pagoRepo.pagos, isEmpty);
      expect(authRepo.vecesLlamado, 1);
      expect(authRepo.haySesionActiva, isFalse);
      expect(etapas, isNotEmpty);
      expect(etapas.last, 'Eliminando la cuenta...');
    },
  );

  test('si falla el borrado de datos a mitad de camino, no llega a borrar la '
      'cuenta de autenticación, y un reintento sobre los mismos repositorios '
      'termina el trabajo sin duplicar nada', () async {
    final cuentaRepo = _FakeCuentaRepository([_cuenta('cta-1')]);
    final categoriaRepo = _FakeCategoriaRepository([_categoriaPropia('cat-1')]);
    // La deuda falla la primera vez que se intenta borrar (simula un
    // corte de red a mitad de la operación) — la segunda vez (reintento)
    // funciona.
    final deudaRepo = _FakeDeudaRepository(
      [_deuda('deuda-1')],
      fallanUnaVez: {'deuda-1'},
    );
    final transaccionRepo = _FakeTransaccionRepository([_transaccion('tx-1')]);
    final pagoRepo = _FakePagoDeudaRepository([_pago('pago-1', 'deuda-1')]);
    final authRepo = _FakeAuthRepository();

    final eliminar = EliminarCuentaDeUsuario(
      cuentaRepository: cuentaRepo,
      categoriaRepository: categoriaRepo,
      deudaRepository: deudaRepo,
      transaccionRepository: transaccionRepo,
      pagoDeudaRepository: pagoRepo,
      authRepository: authRepo,
    );

    await expectLater(() => eliminar(), throwsA(isA<StateError>()));

    // El primer intento sí alcanzó a borrar pagos y transacciones (van
    // antes que deudas en el orden), pero nunca tocó la cuenta de auth —
    // el usuario sigue con sesión activa y puede reintentar de inmediato.
    expect(pagoRepo.pagos, isEmpty);
    expect(transaccionRepo.transacciones, isEmpty);
    expect(deudaRepo.deudas, hasLength(1));
    expect(cuentaRepo.cuentas, hasLength(1));
    expect(authRepo.vecesLlamado, 0);
    expect(authRepo.haySesionActiva, isTrue);

    // Reintento: la deuda ya no falla (se consumió el fallo simulado), y
    // como pagos/transacciones ya están vacíos, no hay nada que volver a
    // borrar ahí — el reintento simplemente completa lo que faltaba.
    await eliminar();

    expect(deudaRepo.deudas, isEmpty);
    expect(categoriaRepo.categorias, isEmpty);
    expect(cuentaRepo.cuentas, isEmpty);
    expect(authRepo.vecesLlamado, 1);
    expect(authRepo.haySesionActiva, isFalse);
  });

  test(
    'si falla el borrado de la cuenta de autenticación, los datos ya '
    'quedan borrados y un reintento vuelve a intentar solo el paso de auth',
    () async {
      final cuentaRepo = _FakeCuentaRepository([_cuenta('cta-1')]);
      final categoriaRepo = _FakeCategoriaRepository([]);
      final deudaRepo = _FakeDeudaRepository([]);
      final transaccionRepo = _FakeTransaccionRepository([]);
      final pagoRepo = _FakePagoDeudaRepository([]);
      final authRepo = _FakeAuthRepository(fallaAlEliminar: true);

      final eliminar = EliminarCuentaDeUsuario(
        cuentaRepository: cuentaRepo,
        categoriaRepository: categoriaRepo,
        deudaRepository: deudaRepo,
        transaccionRepository: transaccionRepo,
        pagoDeudaRepository: pagoRepo,
        authRepository: authRepo,
      );

      await expectLater(() => eliminar(), throwsA(isA<StateError>()));

      // Los datos financieros ya no existen aunque la cuenta de auth
      // todavía exista — es el estado transitorio que describe la Fase 22
      // ("sin datos pero con sesión activa"), y se resuelve solo con
      // reintentar: como ya no queda nada que borrar, el segundo intento
      // solo reintenta el paso de auth.
      expect(cuentaRepo.cuentas, isEmpty);
      expect(authRepo.vecesLlamado, 1);
      expect(authRepo.haySesionActiva, isTrue);
    },
  );
}
