import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/categoria_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

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
      const [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];
  @override
  Future<List<Transaccion>> obtenerTodas() async => const [];
}

void main() {
  testWidgets('el selector de ícono cambia el ícono elegido antes de guardar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeCategorias = _FakeCategoriaRepository({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          datosEnLaNubeProvider.overrideWithValue(false),
          categoriaRepositoryProvider.overrideWithValue(fakeCategorias),
          transaccionRepositoryProvider.overrideWithValue(
            _FakeTransaccionRepository(),
          ),
        ],
        child: const MaterialApp(home: CategoriaNuevaScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Por defecto se preselecciona el primer ícono del set ('restaurant').
    expect(find.byIcon(Icons.restaurant), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Mascotas',
    );
    await tester.pump();

    // Elige un ícono distinto del preseleccionado por defecto.
    await tester.tap(find.byIcon(Icons.movie));
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    // Sin `pumpAndSettle` todavía — dejaría avanzar también el auto-cierre
    // del SnackBar antes de poder comprobar que apareció.
    await tester.pump();
    await tester.pump();

    expect(fakeCategorias.categorias, hasLength(1));
    final creada = fakeCategorias.categorias.values.single;
    expect(creada.nombre, 'Mascotas');
    expect(creada.iconName, 'movie');
    expect(find.text('Categoría creada'), findsOneWidget);

    await tester.pumpAndSettle();
  });
}
