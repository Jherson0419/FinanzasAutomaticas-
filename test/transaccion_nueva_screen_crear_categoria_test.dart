import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/placeholders/transaccion_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas;
  _FakeCuentaRepository(this.cuentas);

  @override
  Future<void> actualizar(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;
  @override
  Future<void> crear(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;
  @override
  Future<void> eliminar(String id) async => cuentas.remove(id);
  @override
  Future<Cuenta?> obtenerPorId(String id) async => cuentas[id];
  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas.values.toList();
}

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

void main() {
  testWidgets(
    '"+ Crear categoría nueva" crea y selecciona la categoría sin perder los demás campos',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeCategorias = _FakeCategoriaRepository({});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            datosEnLaNubeProvider.overrideWithValue(false),
            cuentaRepositoryProvider.overrideWithValue(
              _FakeCuentaRepository({
                'cta-1': const Cuenta(
                  id: 'cta-1',
                  nombre: 'BCP Cuenta sueldo',
                  tipo: TipoCuenta.debito,
                  moneda: Moneda.pen,
                  saldoActual: 1000,
                ),
              }),
            ),
            categoriaRepositoryProvider.overrideWithValue(fakeCategorias),
          ],
          child: const MaterialApp(home: TransaccionNuevaScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Datos ya ingresados antes de crear la categoría nueva.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto'),
        '25.50',
      );
      await tester.pump();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCP Cuenta sueldo (S/)').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Concepto (opcional)'),
        'Comida del perro',
      );
      await tester.pump();

      // Abre el modo rápido desde el dropdown de categoría.
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Categoría'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('+ Crear categoría nueva').last);
      await tester.pumpAndSettle();

      // El modo rápido no muestra selector de tipo (ya implícito: Gasto).
      expect(find.byType(SegmentedButton<TipoCategoria>), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Mascotas',
      );
      await tester.pump();

      final guardarModal = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.widgetWithText(FilledButton, 'Guardar'),
      );
      await tester.tap(guardarModal);
      await tester.pumpAndSettle();

      // La categoría se creó y quedó seleccionada en el dropdown.
      expect(fakeCategorias.categorias, hasLength(1));
      final creada = fakeCategorias.categorias.values.single;
      expect(creada.nombre, 'Mascotas');
      expect(creada.tipo, TipoCategoria.gasto);
      expect(creada.esPredeterminada, isFalse);
      expect(find.text('Mascotas'), findsOneWidget);

      // El resto de los campos ya ingresados no se perdió.
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Monto'))
            .controller!
            .text,
        '25.50',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Concepto (opcional)'),
            )
            .controller!
            .text,
        'Comida del perro',
      );
      expect(find.text('BCP Cuenta sueldo (S/)'), findsOneWidget);

      // Con monto, cuenta y categoría completos, Guardar ya está habilitado.
      final botonGuardarTransaccion = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar'),
      );
      expect(botonGuardarTransaccion.onPressed, isNotNull);
    },
  );
}
