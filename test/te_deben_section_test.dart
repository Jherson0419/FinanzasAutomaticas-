import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/te_deben_section.dart';
import 'package:finanzas_automaticas/presentation/state/dashboard/dashboard_providers.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

Future<void> _pumpSection(
  WidgetTester tester, {
  List<DeudaDeAmigo> deudas = const [],
  List<PerfilPublico> amigos = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deudasQueMeDebenProvider.overrideWith((ref) async => deudas),
        amigosProvider.overrideWith((ref) async => amigos),
      ],
      child: const MaterialApp(home: Scaffold(body: TeDebenSection())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin deudas, no muestra nada (ni siquiera el encabezado)', (
    WidgetTester tester,
  ) async {
    await _pumpSection(tester);

    expect(find.text('TE DEBEN'), findsNothing);
  });

  testWidgets(
    'con una deuda, muestra "{nick} te debe {monto}" resuelto vía amigosProvider',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        deudas: const [
          DeudaDeAmigo(
            id: 'd1',
            deudorUsuarioId: 'user-2',
            nombreDeuda: 'Préstamo',
            montoAdeudado: 350,
            moneda: Moneda.pen,
          ),
        ],
        amigos: const [
          PerfilPublico(usuarioId: 'user-2', nick: 'jherson23'),
        ],
      );

      expect(find.text('TE DEBEN'), findsOneWidget);
      expect(find.text('jherson23 te debe S/ 350.00'), findsOneWidget);
    },
  );

  testWidgets(
    'si el deudor no aparece en amigosProvider (todavía no cargó), usa '
    '"Alguien" en vez de fallar',
    (WidgetTester tester) async {
      await _pumpSection(
        tester,
        deudas: const [
          DeudaDeAmigo(
            id: 'd1',
            deudorUsuarioId: 'user-2',
            nombreDeuda: 'Préstamo',
            montoAdeudado: 350,
            moneda: Moneda.pen,
          ),
        ],
      );

      expect(find.text('Alguien te debe S/ 350.00'), findsOneWidget);
    },
  );

  testWidgets('varias deudas se listan todas', (WidgetTester tester) async {
    await _pumpSection(
      tester,
      deudas: const [
        DeudaDeAmigo(
          id: 'd1',
          deudorUsuarioId: 'user-2',
          nombreDeuda: 'Préstamo 1',
          montoAdeudado: 100,
          moneda: Moneda.pen,
        ),
        DeudaDeAmigo(
          id: 'd2',
          deudorUsuarioId: 'user-3',
          nombreDeuda: 'Préstamo 2',
          montoAdeudado: 200,
          moneda: Moneda.pen,
        ),
      ],
      amigos: const [
        PerfilPublico(usuarioId: 'user-2', nick: 'jherson23'),
        PerfilPublico(usuarioId: 'user-3', nick: 'maria_dev'),
      ],
    );

    expect(find.text('jherson23 te debe S/ 100.00'), findsOneWidget);
    expect(find.text('maria_dev te debe S/ 200.00'), findsOneWidget);
  });
}
