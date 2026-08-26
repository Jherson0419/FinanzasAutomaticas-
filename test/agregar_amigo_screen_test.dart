import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/agregar_amigo_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAmistadRepository implements AmistadRepository {
  _FakeAmistadRepository({this.resultadoBusqueda, this.errorAlEnviar});

  PerfilPublico? resultadoBusqueda;
  Object? errorAlEnviar;
  String? usuarioIdSolicitado;

  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => resultadoBusqueda;

  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {
    if (errorAlEnviar != null) throw errorAlEnviar!;
    usuarioIdSolicitado = paraUsuarioId;
  }

  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async => [];

  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => [];

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

Future<_FakeAmistadRepository> _pumpScreen(
  WidgetTester tester, {
  PerfilPublico? resultadoBusqueda,
  Object? errorAlEnviar,
  String? nickInicial,
}) async {
  final fake = _FakeAmistadRepository(
    resultadoBusqueda: resultadoBusqueda,
    errorAlEnviar: errorAlEnviar,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [amistadRepositoryProvider.overrideWithValue(fake)],
      child: MaterialApp(
        home: AgregarAmigoScreen(nickInicial: nickInicial),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets(
    'buscar un nick que existe muestra su tarjeta con nick y botón de enviar',
    (WidgetTester tester) async {
      await _pumpScreen(
        tester,
        resultadoBusqueda: const PerfilPublico(
          usuarioId: 'user-2',
          nick: 'jherson23',
          avatarId: null,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nick de tu amigo'),
        'jherson23',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await tester.pumpAndSettle();

      expect(find.text('@jherson23'), findsOneWidget);
      expect(find.text('Enviar solicitud'), findsOneWidget);
    },
  );

  testWidgets(
    'buscar un nick que no existe muestra el mensaje de no encontrado',
    (WidgetTester tester) async {
      await _pumpScreen(tester, resultadoBusqueda: null);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nick de tu amigo'),
        'nadie',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await tester.pumpAndSettle();

      expect(
        find.text('No se encontró ningún usuario con ese nick.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tocar "Enviar solicitud" envía al usuario encontrado y muestra confirmación',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(
        tester,
        resultadoBusqueda: const PerfilPublico(
          usuarioId: 'user-2',
          nick: 'jherson23',
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nick de tu amigo'),
        'jherson23',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(fake.usuarioIdSolicitado, 'user-2');
      expect(find.text('Solicitud enviada'), findsOneWidget);
    },
  );

  testWidgets(
    'un error al enviar la solicitud muestra el mensaje traducido en un SnackBar',
    (WidgetTester tester) async {
      await _pumpScreen(
        tester,
        resultadoBusqueda: const PerfilPublico(
          usuarioId: 'user-2',
          nick: 'jherson23',
        ),
        errorAlEnviar: StateError('Ya le enviaste una solicitud a este usuario.'),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nick de tu amigo'),
        'jherson23',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Buscar'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ya le enviaste una solicitud a este usuario.'),
        findsOneWidget,
      );
    },
  );

  group('Fase 64 — deep link finzo://agregar-amigo?nick=', () {
    testWidgets(
      'nickInicial prellena el campo y dispara la búsqueda sola',
      (WidgetTester tester) async {
        await _pumpScreen(
          tester,
          nickInicial: 'jherson23',
          resultadoBusqueda: const PerfilPublico(
            usuarioId: 'user-2',
            nick: 'jherson23',
          ),
        );

        expect(
          find.widgetWithText(TextFormField, 'jherson23'),
          findsOneWidget,
        );
        // Ya se ve la tarjeta de resultado sin haber tocado "Buscar" — solo
        // falta un toque en "Enviar solicitud".
        expect(find.text('@jherson23'), findsOneWidget);
        expect(find.text('Enviar solicitud'), findsOneWidget);
      },
    );

    testWidgets(
      'nickInicial nunca envía la solicitud sola, solo prepara la búsqueda',
      (WidgetTester tester) async {
        final fake = await _pumpScreen(
          tester,
          nickInicial: 'jherson23',
          resultadoBusqueda: const PerfilPublico(
            usuarioId: 'user-2',
            nick: 'jherson23',
          ),
        );

        expect(fake.usuarioIdSolicitado, isNull);
      },
    );

    testWidgets('sin nickInicial, el campo de búsqueda empieza vacío', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester);

      expect(find.text('No se encontró ningún usuario con ese nick.'), findsNothing);
      expect(find.text('Enviar solicitud'), findsNothing);
    });
  });
}
