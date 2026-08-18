import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/deudas_activas_section.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/movimientos_recientes_section.dart';

final _deudaFixture = const DeudaActivaResumen(
  id: 'd1',
  nombreDeuda: 'Préstamo personal',
  estructuraPago: EstructuraPago.cuotasFijas,
  proximaFechaPago: null,
  enMora: false,
  diasMora: null,
  montoPagado: 300,
  montoTotal: 1000,
  montoCuota: 100,
  moneda: Moneda.pen,
);

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
  testWidgets(
    'DeudasActivasSection: el encabezado expande y colapsa el detalle de cada deuda',
    (WidgetTester tester) async {
      await _pumpTearDown(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeudasActivasSection(
              deudasActivas: [_deudaFixture],
              deudasEnMoraCount: 0,
              deudasPorVencerEstaSemanaCount: 0,
              totalAdeudadoPorMoneda: const {Moneda.pen: 700},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expandido por defecto.
      expect(find.textContaining('Pagado'), findsOneWidget);

      await tester.tap(find.text('DEUDAS ACTIVAS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pagado'), findsNothing);
      // El encabezado (con el total adeudado) sigue visible al colapsar.
      expect(find.text('DEUDAS ACTIVAS'), findsOneWidget);

      await tester.tap(find.text('DEUDAS ACTIVAS'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Pagado'), findsOneWidget);
    },
  );

  testWidgets(
    'MovimientosRecientesSection: el encabezado expande y colapsa la lista y "Ver todos"',
    (WidgetTester tester) async {
      await _pumpTearDown(tester);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MovimientosRecientesSection(
              movimientosRecientes: [_movimientoFixture],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Supermercado'), findsOneWidget);
      expect(find.text('Ver todos'), findsOneWidget);

      await tester.tap(find.text('MOVIMIENTOS RECIENTES'));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado'), findsNothing);
      expect(find.text('Ver todos'), findsNothing);
      expect(find.text('MOVIMIENTOS RECIENTES'), findsOneWidget);

      await tester.tap(find.text('MOVIMIENTOS RECIENTES'));
      await tester.pumpAndSettle();

      expect(find.text('Supermercado'), findsOneWidget);
      expect(find.text('Ver todos'), findsOneWidget);
    },
  );
}
