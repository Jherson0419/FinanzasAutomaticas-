import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
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

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas = [];

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async {
    final indice = deudas.indexWhere((d) => d.id == deuda.id);
    if (indice != -1) deudas[indice] = deuda;
  }

  @override
  Future<void> crear(Deuda deuda) async => deudas.add(deuda);

  @override
  Future<void> eliminar(String id) async =>
      deudas.removeWhere((d) => d.id == id);

  @override
  Future<Deuda?> obtenerPorId(String id) async {
    for (final d in deudas) {
      if (d.id == id) return d;
    }
    return null;
  }

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas;

  @override
  Future<List<Deuda>> obtenerActivas() async =>
      deudas.where((d) => d.estado == EstadoDeuda.activa).toList();
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
        deudaRepositoryProvider.overrideWithValue(_FakeDeudaRepository()),
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

Future<void> _aceptarFechaPorDefecto(WidgetTester tester, String campo) async {
  await tester.tap(find.text(campo));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('los campos de crédito solo aparecen al elegir tipo Crédito', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('Línea de crédito'), findsNothing);
    expect(find.text('Fecha de corte'), findsNothing);
    expect(find.text('Fecha de pago'), findsNothing);
    expect(find.text('Pago mínimo (opcional)'), findsNothing);

    await _seleccionarTipoCredito(tester);

    expect(find.text('Línea de crédito'), findsOneWidget);
    expect(find.text('Fecha de corte'), findsOneWidget);
    expect(find.text('Fecha de pago'), findsOneWidget);
    expect(find.text('Pago mínimo (opcional)'), findsOneWidget);
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
      await _aceptarFechaPorDefecto(tester, 'Fecha de corte');
      await _aceptarFechaPorDefecto(tester, 'Fecha de pago');
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
      expect(creada.fechaCorte, isNotNull);
      expect(creada.fechaPago, isNotNull);

      await tester.pumpAndSettle();
    },
  );

  group('Fase 65 — Pago mínimo (opcional)', () {
    testWidgets(
      'Guardar sigue habilitado sin llenar "Pago mínimo" (es opcional)',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
          'Visa BCP',
        );
        await _seleccionarTipoCredito(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Línea de crédito'),
          '2000',
        );
        await _aceptarFechaPorDefecto(tester, 'Fecha de corte');
        await _aceptarFechaPorDefecto(tester, 'Fecha de pago');
        await tester.pump();

        final boton = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(boton.onPressed, isNotNull);

        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump();

        expect(fakeCuentaCreada(tester).pagoMinimo, isNull);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'llenar "Pago mínimo" con un valor válido lo guarda en la cuenta',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
          'Visa BCP',
        );
        await _seleccionarTipoCredito(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Línea de crédito'),
          '2000',
        );
        await _aceptarFechaPorDefecto(tester, 'Fecha de corte');
        await _aceptarFechaPorDefecto(tester, 'Fecha de pago');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Pago mínimo (opcional)'),
          '120',
        );
        await tester.pump();

        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump();

        expect(fakeCuentaCreada(tester).pagoMinimo, 120);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'un "Pago mínimo" inválido (0 o negativo) muestra error y deshabilita Guardar',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
          'Visa BCP',
        );
        await _seleccionarTipoCredito(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Línea de crédito'),
          '2000',
        );
        await _aceptarFechaPorDefecto(tester, 'Fecha de corte');
        await _aceptarFechaPorDefecto(tester, 'Fecha de pago');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Pago mínimo (opcional)'),
          '0',
        );
        await tester.pump();

        expect(find.text('Ingresa un monto mayor a 0.'), findsOneWidget);
        final boton = tester.widget<FilledButton>(find.byType(FilledButton));
        expect(boton.onPressed, isNull);
      },
    );
  });
}

Cuenta fakeCuentaCreada(WidgetTester tester) {
  final element = tester.element(find.byType(CuentaNuevaScreen));
  final container = ProviderScope.containerOf(element);
  final repo =
      container.read(cuentaRepositoryProvider) as _FakeCuentaRepository;
  return repo.cuentas.values.first;
}
