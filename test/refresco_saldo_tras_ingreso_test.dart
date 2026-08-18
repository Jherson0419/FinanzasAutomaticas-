import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/cuentas_carrusel.dart';
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

class _FakeTransaccionRepository implements TransaccionRepository {
  final List<Transaccion> transacciones = [];

  @override
  Future<void> crear(Transaccion transaccion) async =>
      transacciones.add(transaccion);

  @override
  Future<void> actualizar(Transaccion transaccion) async {
    final indice = transacciones.indexWhere((t) => t.id == transaccion.id);
    if (indice != -1) transacciones[indice] = transaccion;
  }

  @override
  Future<void> eliminar(String id) async =>
      transacciones.removeWhere((t) => t.id == id);

  @override
  Future<Transaccion?> obtenerPorId(String id) async {
    for (final t in transacciones) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async =>
      transacciones.where((t) => t.cuentaId == cuentaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      transacciones.where((t) => t.categoriaId == categoriaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => transacciones
      .where((t) => !t.fecha.isBefore(desde) && !t.fecha.isAfter(hasta))
      .toList();

  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async =>
      transacciones.take(limite).toList();

  @override
  Future<List<Transaccion>> obtenerTodas() async => transacciones;
}

class _FakeCategoriaRepository implements CategoriaRepository {
  final List<Categoria> categorias;
  _FakeCategoriaRepository(this.categorias);

  @override
  Future<Categoria?> obtenerPorId(String id) async {
    for (final c in categorias) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<Categoria>> obtenerTodas() async => categorias;

  @override
  Future<void> crear(Categoria categoria) async {}

  @override
  Future<void> actualizar(Categoria categoria) async {}

  @override
  Future<void> eliminar(String id) async {}
}

final _cuentaFixture = const Cuenta(
  id: 'cta-1',
  nombre: 'BCP Cuenta sueldo',
  tipo: TipoCuenta.debito,
  moneda: Moneda.pen,
  saldoActual: 1000,
);

final _categoriaFixture = const Categoria(
  id: 'cat-sueldo',
  nombre: 'Sueldo',
  tipo: TipoCategoria.ingreso,
  iconName: 'payments',
);

/// El carrusel vive en una ruta base; el formulario se abre en una ruta
/// separada empujada encima (como en la app real: dashboard → "Nuevo
/// gasto/ingreso"). Así, al hacer `Navigator.pop()` desde el formulario,
/// solo se retira esa ruta y el carrusel de la ruta base —que nunca se
/// desmontó— puede observarse ya refrescado, sin reiniciar nada.
class _HarnessScreen extends StatelessWidget {
  const _HarnessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const CuentasCarrusel(),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const TransaccionNuevaScreen(),
              ),
            ),
            child: const Text('Nuevo gasto/ingreso'),
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets(
    'tras registrar un ingreso, la tarjeta de la cuenta en el carrusel muestra el saldo actualizado sin reiniciar la app',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeCuentas = _FakeCuentaRepository({'cta-1': _cuentaFixture});

      // El carrusel vive en la ruta base y el formulario se empuja encima
      // (mismo `ProviderScope`, misma app) para comprobar que invalidar un
      // provider desde el formulario refresca al carrusel ya montado, sin
      // necesidad de recrear la app.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            datosEnLaNubeProvider.overrideWithValue(false),
            cuentaRepositoryProvider.overrideWithValue(fakeCuentas),
            transaccionRepositoryProvider.overrideWithValue(
              _FakeTransaccionRepository(),
            ),
            categoriaRepositoryProvider.overrideWithValue(
              _FakeCategoriaRepository([_categoriaFixture]),
            ),
          ],
          child: const MaterialApp(home: _HarnessScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('S/ 1,000.00'), findsOneWidget);

      await tester.tap(find.text('Nuevo gasto/ingreso'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ingreso'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto'),
        '500',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Cuenta'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCP Cuenta sueldo (S/)').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Categoría'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sueldo').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      // El formulario hace `Navigator.pop()` al guardar; como en este árbol
      // no hay una ruta anterior a la que volver, el widget sigue montado
      // y podemos verificar directamente que el carrusel ya refleja 1500.
      expect(find.text('S/ 1,500.00'), findsOneWidget);
      expect(find.text('S/ 1,000.00'), findsNothing);
    },
  );
}
