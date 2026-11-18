import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/movimientos_recientes_section.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

final _movimientoFixture = MovimientoReciente(
  id: 'm1',
  concepto: 'Supermercado',
  monto: 50,
  moneda: Moneda.pen,
  tipo: TipoTransaccion.gasto,
  categoriaNombre: 'Comida',
  categoriaIconName: 'restaurant',
  fuenteCaptura: FuenteCaptura.manual,
  fecha: DateTime(2026, 3, 1),
);

Future<void> _pumpTearDown(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  // Fase 81: `MovimientosRecientesSection` dejó de ser un acordeón
  // (01-inicio.png): muestra a lo sumo 3 filas y "Ver todo" lleva a la
  // pestaña Movimientos. Se reemplaza la prueba de expandir/colapsar por la
  // del comportamiento nuevo, con las mismas garantías de contenido y
  // navegación que tenía "Ver todos".
  testWidgets(
    'MovimientosRecientesSection: muestra a lo sumo 3 movimientos con '
    'categoría y signo, y "Ver todo" abre Movimientos',
    (WidgetTester tester) async {
      await _pumpTearDown(tester);

      final movimientos = [
        for (var i = 0; i < 5; i++)
          MovimientoReciente(
            id: 'm$i',
            concepto: 'Movimiento $i',
            monto: 10.0 + i,
            moneda: Moneda.pen,
            tipo: i == 0 ? TipoTransaccion.ingreso : TipoTransaccion.gasto,
            categoriaNombre: 'Comida',
            categoriaIconName: 'restaurant',
            fuenteCaptura: FuenteCaptura.manual,
            fecha: DateTime(2026, 3, 1),
          ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todasLasTransaccionesProvider.overrideWith((ref) async => []),
            cuentasProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MovimientosRecientesSection(
                movimientosRecientes: [_movimientoFixture, ...movimientos],
              ),
            ),
            routes: {
              '/transacciones/todas': (_) =>
                  const Scaffold(body: Text('Pantalla Movimientos')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Movimientos recientes'), findsOneWidget);
      expect(find.text('Supermercado'), findsOneWidget);
      expect(find.text('Movimiento 0'), findsOneWidget);
      expect(find.text('Movimiento 1'), findsOneWidget);
      expect(find.text('Movimiento 2'), findsNothing, reason: 'solo 3 filas');
      // Signo explícito (no solo color): −S/ para gasto, +S/ para ingreso.
      expect(find.text('−S/ 50.00'), findsOneWidget);
      expect(find.text('+S/ 10.00'), findsOneWidget);
      expect(find.textContaining('Comida · '), findsNWidgets(3));

      await tester.tap(find.text('Ver todo'));
      await tester.pumpAndSettle();
      expect(find.text('Pantalla Movimientos'), findsOneWidget);
    },
  );
}
