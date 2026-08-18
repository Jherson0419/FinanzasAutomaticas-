import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/crear_categoria.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_categoria.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_categoria.dart';

class _FakeCategoriaRepository implements CategoriaRepository {
  final Map<String, Categoria> categorias;
  _FakeCategoriaRepository(this.categorias);

  @override
  Future<void> crear(Categoria categoria) async =>
      categorias[categoria.id] = categoria;

  @override
  Future<void> actualizar(Categoria categoria) async =>
      categorias[categoria.id] = categoria;

  @override
  Future<void> eliminar(String id) async => categorias.remove(id);

  @override
  Future<Categoria?> obtenerPorId(String id) async => categorias[id];

  @override
  Future<List<Categoria>> obtenerTodas() async => categorias.values.toList();
}

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones;
  _FakeTransaccionRepository(this.transacciones);

  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      transacciones.where((t) => t.categoriaId == categoriaId).toList();
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];
  @override
  Future<List<Transaccion>> obtenerTodas() async => transacciones;
}

final _categoriaPredeterminada = const Categoria(
  id: 'cat-comida',
  nombre: 'Comida',
  tipo: TipoCategoria.gasto,
  iconName: 'restaurant',
  esPredeterminada: true,
);

final _categoriaPropia = const Categoria(
  id: 'cat-mascotas',
  nombre: 'Mascotas',
  tipo: TipoCategoria.gasto,
  iconName: 'category',
);

final _transaccionFixture = Transaccion(
  id: 'tx-1',
  cuentaId: 'cta-1',
  categoriaId: 'cat-mascotas',
  monto: 30,
  moneda: Moneda.pen,
  tipo: TipoTransaccion.gasto,
  concepto: 'Comida para el perro',
  metodoPago: MetodoPago.efectivo,
  esRecurrente: false,
  fuenteCaptura: FuenteCaptura.manual,
  fecha: DateTime(2026, 1, 1),
);

void main() {
  group('CrearCategoria', () {
    test('siempre crea con esPredeterminada: false', () async {
      final repo = _FakeCategoriaRepository({});
      final crear = CrearCategoria(categoriaRepository: repo);

      final creada = await crear(
        nombre: 'Mascotas',
        tipo: TipoCategoria.gasto,
        iconName: 'category',
      );

      expect(creada.esPredeterminada, isFalse);
      expect(repo.categorias[creada.id]!.esPredeterminada, isFalse);
    });
  });

  group('EditarCategoria', () {
    test('rechaza editar una categoría predeterminada', () async {
      final repo = _FakeCategoriaRepository({
        'cat-comida': _categoriaPredeterminada,
      });
      final editar = EditarCategoria(
        categoriaRepository: repo,
        transaccionRepository: _FakeTransaccionRepository([]),
      );

      expect(
        () => editar(
          categoriaId: 'cat-comida',
          nombre: 'Comida rápida',
          tipo: TipoCategoria.gasto,
          iconName: 'restaurant',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Las categorías predeterminadas no se pueden editar ni eliminar',
          ),
        ),
      );
    });

    test(
      'rechaza cambiar el tipo de una categoría propia con movimientos',
      () async {
        final repo = _FakeCategoriaRepository({
          'cat-mascotas': _categoriaPropia,
        });
        final editar = EditarCategoria(
          categoriaRepository: repo,
          transaccionRepository: _FakeTransaccionRepository([
            _transaccionFixture,
          ]),
        );

        expect(
          () => editar(
            categoriaId: 'cat-mascotas',
            nombre: 'Mascotas',
            tipo: TipoCategoria.ingreso,
            iconName: 'category',
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'permite editar nombre/ícono de una categoría propia sin tocar el tipo',
      () async {
        final repo = _FakeCategoriaRepository({
          'cat-mascotas': _categoriaPropia,
        });
        final editar = EditarCategoria(
          categoriaRepository: repo,
          transaccionRepository: _FakeTransaccionRepository([
            _transaccionFixture,
          ]),
        );

        final editada = await editar(
          categoriaId: 'cat-mascotas',
          nombre: 'Mascotas y veterinario',
          tipo: TipoCategoria.gasto,
          iconName: 'health_and_safety',
        );

        expect(editada.nombre, 'Mascotas y veterinario');
        expect(editada.iconName, 'health_and_safety');
      },
    );
  });

  group('EliminarCategoria', () {
    test('rechaza eliminar una categoría predeterminada', () async {
      final repo = _FakeCategoriaRepository({
        'cat-comida': _categoriaPredeterminada,
      });
      final eliminar = EliminarCategoria(
        categoriaRepository: repo,
        transaccionRepository: _FakeTransaccionRepository([]),
      );

      expect(
        () => eliminar(categoriaId: 'cat-comida'),
        throwsA(isA<StateError>()),
      );
      expect(repo.categorias.containsKey('cat-comida'), isTrue);
    });

    test(
      'rechaza eliminar una categoría propia con movimientos registrados',
      () async {
        final repo = _FakeCategoriaRepository({
          'cat-mascotas': _categoriaPropia,
        });
        final eliminar = EliminarCategoria(
          categoriaRepository: repo,
          transaccionRepository: _FakeTransaccionRepository([
            _transaccionFixture,
          ]),
        );

        expect(
          () => eliminar(categoriaId: 'cat-mascotas'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              'No se puede eliminar una categoría con movimientos registrados',
            ),
          ),
        );
        expect(repo.categorias.containsKey('cat-mascotas'), isTrue);
      },
    );

    test('elimina una categoría propia sin movimientos', () async {
      final repo = _FakeCategoriaRepository({'cat-mascotas': _categoriaPropia});
      final eliminar = EliminarCategoria(
        categoriaRepository: repo,
        transaccionRepository: _FakeTransaccionRepository([]),
      );

      await eliminar(categoriaId: 'cat-mascotas');

      expect(repo.categorias.containsKey('cat-mascotas'), isFalse);
    });
  });
}
