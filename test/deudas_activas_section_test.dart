import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_dashboard.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/deudas_activas_section.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';
import 'package:finanzas_automaticas/presentation/theme/app_theme.dart';

DeudaActivaResumen _cuotaFija({
  required String id,
  String nombre = 'Cuotas',
  bool enMora = false,
  DateTime? fechaVencimientoReal,
  String? amigoUsuarioId,
}) {
  return DeudaActivaResumen(
    id: id,
    nombreDeuda: nombre,
    estructuraPago: EstructuraPago.cuotasFijas,
    proximaFechaPago: fechaVencimientoReal,
    enMora: enMora,
    diasMora: null,
    montoPagado: 300,
    montoTotal: 1000,
    montoCuota: 100,
    moneda: Moneda.pen,
    fechaVencimientoReal: fechaVencimientoReal,
    amigoUsuarioId: amigoUsuarioId,
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
  List<DeudaActivaResumen> deudasActivas, {
  List<PerfilPublico> amigos = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [amigosProvider.overrideWith((ref) => amigos)],
      child: MaterialApp(
        home: Scaffold(
          body: DeudasActivasSection(
            deudasActivas: deudasActivas,
            deudasEnMoraCount: 0,
            deudasPorVencerEstaSemanaCount: 0,
            totalAdeudadoPorMoneda: const {},
          ),
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

  BoxDecoration? decoracionDeFila(WidgetTester tester, String nombreDeuda) {
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(nombreDeuda), matching: find.byType(Container))
          .first,
    );
    return container.decoration as BoxDecoration?;
  }

  group('Fase 68 — color por vencimiento', () {
    testWidgets('una deuda vencida (enMora) se resalta en colorDanger', (
      WidgetTester tester,
    ) async {
      await _pumpSection(tester, [
        _cuotaFija(id: 'd1', nombre: 'Préstamo vencido', enMora: true),
      ]);

      final decoracion = decoracionDeFila(tester, 'Préstamo vencido');
      expect(decoracion, isNotNull);
      expect(decoracion!.color, colorDanger.withValues(alpha: 0.10));
      expect((decoracion.border as Border?)?.top.color, colorDanger);
    });

    testWidgets(
      'una deuda por vencer en 3 días o menos se resalta en colorWarning',
      (WidgetTester tester) async {
        final hoy = DateTime.now();
        await _pumpSection(tester, [
          _cuotaFija(
            id: 'd1',
            nombre: 'Préstamo por vencer',
            fechaVencimientoReal: hoy.add(const Duration(days: 2)),
          ),
        ]);

        final decoracion = decoracionDeFila(tester, 'Préstamo por vencer');
        expect(decoracion, isNotNull);
        expect(decoracion!.color, colorWarning.withValues(alpha: 0.10));
        expect((decoracion.border as Border?)?.top.color, colorWarning);
      },
    );

    testWidgets(
      'una deuda normal (vence en más de 3 días) no cambia de color',
      (WidgetTester tester) async {
        final hoy = DateTime.now();
        await _pumpSection(tester, [
          _cuotaFija(
            id: 'd1',
            nombre: 'Préstamo normal',
            fechaVencimientoReal: hoy.add(const Duration(days: 10)),
          ),
        ]);

        final decoracion = decoracionDeFila(tester, 'Préstamo normal');
        expect(decoracion?.color, isNull);
        expect(decoracion?.border, isNull);
      },
    );
  });

  group('Fase 68 — "Debo a {nick}" para deudas vinculadas a un amigo', () {
    testWidgets(
      'con amigoUsuarioId, muestra "Debo a {nick}" resuelto vía amigosProvider',
      (WidgetTester tester) async {
        await _pumpSection(
          tester,
          [
            _cuotaFija(
              id: 'd1',
              nombre: 'Préstamo de un amigo',
              amigoUsuarioId: 'user-2',
            ),
          ],
          amigos: const [
            PerfilPublico(usuarioId: 'user-2', nick: 'jherson23'),
          ],
        );

        expect(find.text('Debo a jherson23'), findsOneWidget);
      },
    );

    testWidgets('sin amigoUsuarioId, no muestra ninguna línea "Debo a"', (
      WidgetTester tester,
    ) async {
      await _pumpSection(tester, [
        _cuotaFija(id: 'd1', nombre: 'Préstamo normal'),
      ]);

      expect(find.textContaining('Debo a'), findsNothing);
    });
  });
}
