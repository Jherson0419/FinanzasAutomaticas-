import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/mis_amigos_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeAmistadRepository implements AmistadRepository {
  _FakeAmistadRepository({
    List<SolicitudRecibida> solicitudes = const [],
    List<PerfilPublico> amigos = const [],
  }) : solicitudesRecibidas = List.of(solicitudes),
       amigosAceptados = List.of(amigos);

  List<SolicitudRecibida> solicitudesRecibidas;
  List<PerfilPublico> amigosAceptados;
  String? ultimaSolicitudAceptada;
  String? ultimaSolicitudRechazada;

  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;

  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {}

  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      solicitudesRecibidas;

  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => amigosAceptados;

  @override
  Future<void> aceptarSolicitud(String solicitudId) async {
    ultimaSolicitudAceptada = solicitudId;
    final solicitud = solicitudesRecibidas.firstWhere(
      (s) => s.solicitudId == solicitudId,
    );
    solicitudesRecibidas = solicitudesRecibidas
        .where((s) => s.solicitudId != solicitudId)
        .toList();
    amigosAceptados = [...amigosAceptados, solicitud.deQuien];
  }

  @override
  Future<void> rechazarSolicitud(String solicitudId) async {
    ultimaSolicitudRechazada = solicitudId;
    solicitudesRecibidas = solicitudesRecibidas
        .where((s) => s.solicitudId != solicitudId)
        .toList();
  }

  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}
}

Future<_FakeAmistadRepository> _pumpScreen(
  WidgetTester tester, {
  List<SolicitudRecibida> solicitudes = const [],
  List<PerfilPublico> amigos = const [],
}) async {
  final fake = _FakeAmistadRepository(
    solicitudes: solicitudes,
    amigos: amigos,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [amistadRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: MisAmigosScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('sin solicitudes ni amigos muestra los 2 mensajes vacíos', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester);

    expect(find.text('No tienes solicitudes pendientes.'), findsOneWidget);
    expect(find.text('Todavía no tienes amigos agregados.'), findsOneWidget);
  });

  testWidgets('muestra las solicitudes recibidas con nick', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      solicitudes: const [
        SolicitudRecibida(
          solicitudId: 'sol-1',
          deQuien: PerfilPublico(usuarioId: 'user-2', nick: 'jherson23'),
        ),
      ],
    );

    expect(find.text('@jherson23'), findsOneWidget);
    expect(find.byTooltip('Aceptar'), findsOneWidget);
    expect(find.byTooltip('Rechazar'), findsOneWidget);
  });

  testWidgets('muestra la lista de amigos ya aceptados', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(
      tester,
      amigos: const [PerfilPublico(usuarioId: 'user-3', nick: 'maria_dev')],
    );

    expect(find.text('@maria_dev'), findsOneWidget);
  });

  testWidgets(
    'aceptar una solicitud la mueve de "recibidas" a "amigos"',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(
        tester,
        solicitudes: const [
          SolicitudRecibida(
            solicitudId: 'sol-1',
            deQuien: PerfilPublico(usuarioId: 'user-2', nick: 'jherson23'),
          ),
        ],
      );

      await tester.tap(find.byTooltip('Aceptar'));
      await tester.pumpAndSettle();

      expect(fake.ultimaSolicitudAceptada, 'sol-1');
      expect(find.text('No tienes solicitudes pendientes.'), findsOneWidget);
      expect(find.text('@jherson23'), findsOneWidget);
      expect(find.text('Solicitud aceptada'), findsOneWidget);
    },
  );

  testWidgets('rechazar una solicitud la quita de "recibidas"', (
    WidgetTester tester,
  ) async {
    final fake = await _pumpScreen(
      tester,
      solicitudes: const [
        SolicitudRecibida(
          solicitudId: 'sol-1',
          deQuien: PerfilPublico(usuarioId: 'user-2', nick: 'jherson23'),
        ),
      ],
    );

    await tester.tap(find.byTooltip('Rechazar'));
    await tester.pumpAndSettle();

    expect(fake.ultimaSolicitudRechazada, 'sol-1');
    expect(find.text('No tienes solicitudes pendientes.'), findsOneWidget);
    expect(find.text('@jherson23'), findsNothing);
  });
}
