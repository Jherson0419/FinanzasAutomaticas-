import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_cuenta.dart';
import 'package:finanzas_automaticas/presentation/screens/cuenta_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/screens/dashboard/widgets/wallet_account_card.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeCuentaRepository implements CuentaRepository {
  final Map<String, Cuenta> cuentas = {};

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
  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerTodas() async => [];
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime inicio,
    DateTime fin,
  ) async => [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => [];
}

class _FakePagoDeudaRepository implements PagoDeudaRepository {
  @override
  Future<void> crear(PagoDeuda pago) async {}
  @override
  Future<void> eliminar(String id) async {}
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => [];
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => [];
}

class _FakeDeudaRepository implements DeudaRepository {
  final List<Deuda> deudas = [];

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

Future<void> _pump(WidgetTester tester, Cuenta cuenta) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: WalletAccountCard(cuenta: cuenta))),
  );
}

Future<_FakeCuentaRepository> _pumpScreen(
  WidgetTester tester, {
  String? cuentaId,
  _FakeCuentaRepository? fake,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = fake ?? _FakeCuentaRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(repo),
        deudaRepositoryProvider.overrideWithValue(_FakeDeudaRepository()),
      ],
      child: MaterialApp(home: CuentaNuevaScreen(cuentaId: cuentaId)),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> _seleccionarTipoCredito(WidgetTester tester) async {
  await tester.tap(find.text('Efectivo').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Crédito').last);
  await tester.pumpAndSettle();
}

void main() {
  group('RegistrarCuenta/EditarCuenta — ultimosDigitos (Fase 57)', () {
    test('RegistrarCuenta guarda ultimosDigitos para cualquier tipo', () async {
      final fake = _FakeCuentaRepository();
      final registrarCuenta = RegistrarCuenta(
        cuentaRepository: fake,
        deudaRepository: _FakeDeudaRepository(),
      );

      final cuenta = await registrarCuenta(
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        ultimosDigitos: '4821',
      );

      expect(cuenta.ultimosDigitos, '4821');
      expect(fake.cuentas[cuenta.id]!.ultimosDigitos, '4821');
    });

    test('RegistrarCuenta deja ultimosDigitos en null si no se pasa', () async {
      final fake = _FakeCuentaRepository();
      final registrarCuenta = RegistrarCuenta(
        cuentaRepository: fake,
        deudaRepository: _FakeDeudaRepository(),
      );

      final cuenta = await registrarCuenta(
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
      );

      expect(cuenta.ultimosDigitos, isNull);
    });

    test('EditarCuenta actualiza ultimosDigitos', () async {
      final fake = _FakeCuentaRepository()
        ..cuentas['c1'] = const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 100,
          ultimosDigitos: '1111',
        );
      final editarCuenta = EditarCuenta(
        cuentaRepository: fake,
        transaccionRepository: _FakeTransaccionRepository(),
        pagoDeudaRepository: _FakePagoDeudaRepository(),
        deudaRepository: _FakeDeudaRepository(),
      );

      final actualizada = await editarCuenta(
        cuentaId: 'c1',
        nombre: 'Ahorros',
        tipo: TipoCuenta.debito,
        moneda: Moneda.pen,
        ultimosDigitos: '2222',
      );

      expect(actualizada.ultimosDigitos, '2222');
    });
  });

  group('WalletAccountCard — ultimosDigitos (Fase 57)', () {
    testWidgets('muestra "•••• 4821" junto al tipo de cuenta (no compacto)', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 100,
          ultimosDigitos: '4821',
        ),
      );

      expect(find.textContaining('•••• 4821'), findsOneWidget);
    });

    testWidgets('sin ultimosDigitos no muestra ningún "••••"', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 100,
        ),
      );

      expect(find.textContaining('••••'), findsNothing);
    });
  });

  group('CuentaFormulario — campo de últimos dígitos (Fase 57)', () {
    testWidgets('el campo aparece para cualquier tipo de cuenta (no solo crédito)', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.text('Últimos 4 dígitos (opcional)'), findsOneWidget);
    });

    testWidgets('un valor que no son 4 dígitos numéricos bloquea Guardar', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
        'Ahorros',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Últimos 4 dígitos (opcional)'),
        '12a4',
      );
      await tester.pump();

      expect(
        find.text('Deben ser exactamente 4 dígitos numéricos.'),
        findsOneWidget,
      );
      final boton = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(boton.onPressed, isNull);
    });

    testWidgets('guarda los últimos dígitos al crear la cuenta', (
      WidgetTester tester,
    ) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
        'Ahorros',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Últimos 4 dígitos (opcional)'),
        '4821',
      );
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();

      expect(fake.cuentas.values.first.ultimosDigitos, '4821');
      await tester.pumpAndSettle();
    });

    testWidgets('el campo vacío guarda ultimosDigitos como null', (
      WidgetTester tester,
    ) async {
      final fake = await _pumpScreen(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
        'Ahorros',
      );
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      await tester.pump();

      expect(fake.cuentas.values.first.ultimosDigitos, isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('en modo edición precarga el valor existente', (
      WidgetTester tester,
    ) async {
      final fake = _FakeCuentaRepository()
        ..cuentas['c1'] = const Cuenta(
          id: 'c1',
          nombre: 'Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 100,
          ultimosDigitos: '9911',
        );

      await _pumpScreen(tester, cuentaId: 'c1', fake: fake);

      final campo = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Últimos 4 dígitos (opcional)'),
      );
      expect(campo.controller!.text, '9911');
    });
  });

  group('CuentaFormulario — "Saldo utilizado" en crédito (Fase 57)', () {
    testWidgets(
      'el campo de saldo se llama "Saldo utilizado" cuando el tipo es Crédito',
      (WidgetTester tester) async {
        await _pumpScreen(tester);

        expect(find.text('Saldo inicial'), findsOneWidget);

        await _seleccionarTipoCredito(tester);

        expect(find.text('Saldo inicial'), findsNothing);
        expect(find.text('Saldo utilizado'), findsOneWidget);
      },
    );

    testWidgets(
      'guardar con "Saldo utilizado" 800 crea la cuenta con saldoActual -800',
      (WidgetTester tester) async {
        final fake = await _pumpScreen(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
          'Visa BCP',
        );
        await _seleccionarTipoCredito(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Línea de crédito'),
          '2000',
        );
        await tester.tap(find.text('Fecha de corte'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Fecha de pago'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Saldo utilizado'),
          '800',
        );
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump();

        expect(fake.cuentas.values.first.saldoActual, -800);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'una cuenta que no es crédito guarda el saldo inicial tal cual (positivo)',
      (WidgetTester tester) async {
        final fake = await _pumpScreen(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
          'Ahorros',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Saldo inicial'),
          '800',
        );
        await tester.pump();
        await tester.tap(find.byType(FilledButton));
        await tester.pump();
        await tester.pump();

        expect(fake.cuentas.values.first.saldoActual, 800);
        await tester.pumpAndSettle();
      },
    );
  });
}
