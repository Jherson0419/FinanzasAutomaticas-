import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/placeholders/deuda_nueva_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

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
  Future<List<Deuda>> obtenerActivas() async => deudas;

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas;
}

class _FakeAmistadRepository implements AmistadRepository {
  _FakeAmistadRepository({this.amigos = const []});

  final List<PerfilPublico> amigos;

  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;
  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {}
  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async => [];
  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => amigos;
  @override
  Future<void> aceptarSolicitud(String solicitudId) async {}
  @override
  Future<void> rechazarSolicitud(String solicitudId) async {}
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}
}

Future<_FakeDeudaRepository> _pumpScreen(
  WidgetTester tester, {
  List<PerfilPublico> amigos = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fakeDeudas = _FakeDeudaRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deudaRepositoryProvider.overrideWithValue(fakeDeudas),
        amistadRepositoryProvider.overrideWithValue(
          _FakeAmistadRepository(amigos: amigos),
        ),
      ],
      child: const MaterialApp(home: DeudaNuevaScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fakeDeudas;
}

void main() {
  testWidgets(
    'el switch "¿Es un amigo de Finzo?" solo aparece con tipoAcreedor personaNatural',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      expect(find.text('¿Es un amigo de Finzo?'), findsNothing);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<TipoAcreedor>, 'Tipo de acreedor'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persona natural').last);
      await tester.pumpAndSettle();

      expect(find.text('¿Es un amigo de Finzo?'), findsOneWidget);
    },
  );

  testWidgets(
    'sin amigos agregados, activar el switch muestra el mensaje en vez de un selector',
    (WidgetTester tester) async {
      await _pumpScreen(tester);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<TipoAcreedor>, 'Tipo de acreedor'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persona natural').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Es un amigo de Finzo?'));
      await tester.pumpAndSettle();

      expect(
        find.text('Todavía no tienes amigos agregados en Finzo.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'seleccionar un amigo y guardar crea la deuda con amigoUsuarioId',
    (WidgetTester tester) async {
      final fakeDeudas = await _pumpScreen(
        tester,
        amigos: const [
          PerfilPublico(usuarioId: 'user-amigo', nick: 'jherson23'),
        ],
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la deuda'),
        'Préstamo de un amigo',
      );
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<TipoAcreedor>, 'Tipo de acreedor'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Persona natural').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre del acreedor'),
        'jherson23',
      );
      await tester.tap(find.text('Pago libre'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto total'),
        '100',
      );

      await tester.tap(find.text('¿Es un amigo de Finzo?'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Selecciona a tu amigo',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('@jherson23').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(fakeDeudas.deudas, hasLength(1));
      expect(fakeDeudas.deudas.single.amigoUsuarioId, 'user-amigo');
    },
  );
}
