import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/notificacion.dart';
import 'package:finanzas_automaticas/domain/repositories/notificacion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/notificaciones_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeNotificacionRepository implements NotificacionRepository {
  _FakeNotificacionRepository(this.notificaciones);

  List<Notificacion> notificaciones;
  final List<String> marcadasLeidas = [];

  @override
  Future<List<Notificacion>> obtenerTodas() async => notificaciones;

  @override
  Future<void> marcarLeida(String id) async {
    marcadasLeidas.add(id);
    notificaciones = [
      for (final n in notificaciones)
        if (n.id == id)
          Notificacion(
            id: n.id,
            tipo: n.tipo,
            mensaje: n.mensaje,
            data: n.data,
            leida: true,
            createdAt: n.createdAt,
          )
        else
          n,
    ];
  }
}

Future<_FakeNotificacionRepository> _pumpScreen(
  WidgetTester tester,
  List<Notificacion> notificaciones,
) async {
  final fake = _FakeNotificacionRepository(notificaciones);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [notificacionRepositoryProvider.overrideWithValue(fake)],
      child: const MaterialApp(home: NotificacionesScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

Notificacion _notificacion({
  String id = 'notif-1',
  bool leida = false,
  String mensaje = 'jherson23 aceptó tu solicitud de amistad',
}) {
  return Notificacion(
    id: id,
    tipo: 'solicitud_aceptada',
    mensaje: mensaje,
    leida: leida,
    createdAt: DateTime(2026, 1, 5),
  );
}

void main() {
  testWidgets('sin notificaciones muestra el mensaje vacío', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, []);

    expect(find.text('No tienes notificaciones todavía.'), findsOneWidget);
  });

  testWidgets('muestra el mensaje de cada notificación', (
    WidgetTester tester,
  ) async {
    await _pumpScreen(tester, [_notificacion()]);

    expect(
      find.text('jherson23 aceptó tu solicitud de amistad'),
      findsOneWidget,
    );
  });

  testWidgets('tocar una notificación no leída la marca como leída', (
    WidgetTester tester,
  ) async {
    final fake = await _pumpScreen(tester, [_notificacion(leida: false)]);

    await tester.tap(
      find.text('jherson23 aceptó tu solicitud de amistad'),
    );
    await tester.pumpAndSettle();

    expect(fake.marcadasLeidas, ['notif-1']);
  });

  testWidgets('tocar una notificación ya leída no vuelve a llamar a marcarLeida', (
    WidgetTester tester,
  ) async {
    final fake = await _pumpScreen(tester, [_notificacion(leida: true)]);

    await tester.tap(
      find.text('jherson23 aceptó tu solicitud de amistad'),
    );
    await tester.pumpAndSettle();

    expect(fake.marcadasLeidas, isEmpty);
  });
}
