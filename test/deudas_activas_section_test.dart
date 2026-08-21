import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/deudas_activas_section.dart';

DeudaActivaResumen _cuotaFija({required String id, String nombre = 'Cuotas'}) {
  return DeudaActivaResumen(
    id: id,
    nombreDeuda: nombre,
    estructuraPago: EstructuraPago.cuotasFijas,
    proximaFechaPago: null,
    enMora: false,
    diasMora: null,
    montoPagado: 300,
    montoTotal: 1000,
    montoCuota: 100,
    moneda: Moneda.pen,
  );
}

DeudaActivaResumen _pagoLibre({required String id, String nombre = 'Libre'}) {
  return DeudaActivaResumen(
    id: id,
    nombreDeuda: nombre,
    estructuraPago: EstructuraPago.pagoLibre,
    proximaFechaPago: null,
    enMora: false,
    diasMora: null,
    montoPagado: 100,
    montoTotal: 500,
    montoCuota: null,
    moneda: Moneda.pen,
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  List<DeudaActivaResumen> deudasActivas,
) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DeudasActivasSection(
          deudasActivas: deudasActivas,
          deudasEnMoraCount: 0,
          deudasPorVencerEstaSemanaCount: 0,
          totalAdeudadoPorMoneda: const {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Fase 60: por defecto muestra la página de cuotas fijas, con su '
    'subtítulo',
    (WidgetTester tester) async {
      await _pumpSection(tester, [
        _cuotaFija(id: 'd1', nombre: 'Préstamo BCP'),
        _pagoLibre(id: 'd2', nombre: 'Tarjeta BBVA'),
      ]);

      expect(find.text('Cuotas fijas'), findsOneWidget);
      expect(find.text('Préstamo BCP'), findsOneWidget);
      expect(find.text('Tarjeta BBVA'), findsNothing);
    },
  );

  testWidgets(
    'Fase 60: tocar el punto de "pago libre" cambia a esa página',
    (WidgetTester tester) async {
      await _pumpSection(tester, [
        _cuotaFija(id: 'd1', nombre: 'Préstamo BCP'),
        _pagoLibre(id: 'd2', nombre: 'Tarjeta BBVA'),
      ]);

      await tester.tap(
        find.byKey(const ValueKey('deudasActivas_puntoPagoLibre')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pago libre'), findsOneWidget);
      expect(find.text('Tarjeta BBVA'), findsOneWidget);
      expect(find.text('Préstamo BCP'), findsNothing);
    },
  );

  testWidgets(
    'Fase 60: un swipe horizontal hacia la izquierda avanza a "pago libre"',
    (WidgetTester tester) async {
      await _pumpSection(tester, [
        _cuotaFija(id: 'd1', nombre: 'Préstamo BCP'),
        _pagoLibre(id: 'd2', nombre: 'Tarjeta BBVA'),
      ]);

      await tester.fling(
        find.text('Préstamo BCP'),
        const Offset(-300, 0),
        800,
      );
      await tester.pumpAndSettle();

      expect(find.text('Pago libre'), findsOneWidget);
      expect(find.text('Tarjeta BBVA'), findsOneWidget);
    },
  );

  testWidgets(
    'Fase 60: si una categoría no tiene deudas, esa página muestra el '
    'estado vacío en vez de quedar en blanco',
    (WidgetTester tester) async {
      await _pumpSection(tester, [_cuotaFija(id: 'd1', nombre: 'Préstamo BCP')]);

      expect(find.text('Préstamo BCP'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('deudasActivas_puntoPagoLibre')),
      );
      await tester.pumpAndSettle();

      expect(find.text('No tienes deudas de este tipo.'), findsOneWidget);
    },
  );

  testWidgets(
    'Fase 60: sin ninguna deuda activa, no se muestra el selector de '
    'páginas, solo el mensaje general',
    (WidgetTester tester) async {
      await _pumpSection(tester, []);

      expect(find.text('No tienes deudas activas registradas.'), findsOneWidget);
      expect(find.text('Cuotas fijas'), findsNothing);
      expect(find.text('Pago libre'), findsNothing);
    },
  );
}
