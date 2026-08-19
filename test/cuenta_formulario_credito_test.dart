import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/cuenta_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas = {};

  @override
  Future<void> actualizar(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<void> crear(Cuenta cuenta) async => cuentas[cuenta.id] = cuenta;

  @override
  Future<Cuenta?> obtenerPorId(String id) async => cuentas[id];

  @override
  Future<List<Cuenta>> obtenerTodas() async => cuentas.values.toList();

  @override
  Future<void> eliminar(String id) async => cuentas.remove(id);
}

Future<_FakeCuentaRepository> _pumpScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeCuentaRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(fake),
      ],
      child: const MaterialApp(home: CuentaNuevaScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _seleccionarTipoCredito(WidgetTester tester) async {
  await tester.tap(find.text('Efectivo').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Crédito').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los campos de crédito solo aparecen al elegir tipo Crédito', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Línea de crédito'), findsNothing);
    expect(find.text('Día de corte'), findsNothing);
    expect(find.text('Día de pago'), findsNothing);

    await _seleccionarTipoCredito(tester);

    expect(find.text('Línea de crédito'), findsOneWidget);
    expect(find.text('Día de corte'), findsOneWidget);
    expect(find.text('Día de pago'), findsOneWidget);
  });

  testWidgets(
    'Guardar sigue deshabilitado con tipo Crédito hasta llenar los 3 campos',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
        'Visa BCP',
      );
      await _seleccionarTipoCredito(tester);
      await tester.pump();

      final botonSinCampos = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(botonSinCampos.onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Línea de crédito'),
        '2000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Día de corte'),
        '10',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Día de pago'),
        '20',
      );
      await tester.pump();

      final botonConCampos = tester.widget<FilledButton>(
        find.byType(FilledButton),
      );
      expect(botonConCampos.onPressed, isNotNull);

      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();

      final creada = fakeCuentaCreada(tester);
      expect(creada.lineaCredito, 2000);
      expect(creada.diaCorte, 10);
      expect(creada.diaPago, 20);

      await tester.pumpAndSettle();
    },
  );
}

Cuenta fakeCuentaCreada(WidgetTester tester) {
  final element = tester.element(find.byType(CuentaNuevaScreen));
  final container = ProviderScope.containerOf(element);
  final repo =
      container.read(cuentaRepositoryProvider) as _FakeCuentaRepository;
  return repo.cuentas.values.first;
}
