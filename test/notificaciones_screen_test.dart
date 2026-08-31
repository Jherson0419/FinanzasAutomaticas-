import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/notificacion.dart';
import 'package:finanzas_automaticas/domain/repositories/notificacion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'package:finanzas_automaticas/presentation/screens/notificaciones_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakeNotificacionRepository implements NotificacionRepository {
  _FakeNotificacionRepository(this.notificaciones);

  List<Notificacion> notificaciones;
  final List<String> marcadasLeidas = [];

  @override
  Future<List<Notificacion>> obtenerTodas() async => notificaciones;

  @override
  Future<void> generarNotificacionesVencimiento(
    List<NotificacionVencimientoPendiente> items,
  ) async {}

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

  group('Fase 69 — ícono por tipo de notificación', () {
    testWidgets(
      '"gasto_tarjeta" (Fase 69, trigger de transacciones) usa el ícono de tarjeta',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'gasto_tarjeta',
            mensaje: 'Gastaste 150.00 con tu tarjeta Visa BCP',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
        ]);

        expect(find.byIcon(Icons.credit_card), findsOneWidget);
      },
    );

    testWidgets(
      '"ingreso_recibido" (Fase 69, trigger de transacciones) usa el ícono de ahorro',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'ingreso_recibido',
            mensaje: 'Recibiste 500.00 en BCP Cuenta sueldo',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
        ]);

        expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      },
    );

    testWidgets(
      '"pago_deuda_amigo" (Fase 64) usa el ícono de pago, "solicitud_aceptada" '
      '(Fase 63) el de personas',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'pago_deuda_amigo',
            mensaje: 'jherson23 te registró un pago de 100.00 en "Préstamo"',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
          _notificacion(id: 'n2'),
        ]);

        expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
        expect(find.byIcon(Icons.people_alt_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'un tipo desconocido (futuro, todavía no mapeado) usa el ícono genérico '
      'en vez de fallar',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'tipo_futuro_sin_mapear',
            mensaje: 'Algo pasó',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
        ]);

        expect(find.byIcon(Icons.notifications_none), findsOneWidget);
      },
    );

    testWidgets(
      'Fase 70: "solicitud_recibida" usa el ícono de agregar persona',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'solicitud_recibida',
            mensaje: 'jherson23 te envió una solicitud de amistad',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
        ]);

        expect(find.byIcon(Icons.person_add_alt_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Fase 70: "cuota_por_vencer" usa el ícono de reloj, "cuota_vencida" el '
      'de alerta',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'cuota_por_vencer',
            mensaje: 'Tu deuda "Préstamo BCP" vence pronto',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
          Notificacion(
            id: 'n2',
            tipo: 'cuota_vencida',
            mensaje: 'Tu deuda "Préstamo BCP" está vencida',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
        ]);

        expect(find.byIcon(Icons.schedule), findsOneWidget);
        expect(find.byIcon(Icons.error_outline), findsOneWidget);
      },
    );

    testWidgets(
      'Fase 70: "deuda_pagada" usa el ícono de check, "deuda_amigo_pagada" '
      'el de celebración',
      (WidgetTester tester) async {
        await _pumpScreen(tester, [
          Notificacion(
            id: 'n1',
            tipo: 'deuda_pagada',
            mensaje: '¡Terminaste de pagar "Préstamo BCP"! 🎉',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
          Notificacion(
            id: 'n2',
            tipo: 'deuda_amigo_pagada',
            mensaje: 'jherson23 terminó de pagarte "Préstamo"',
            leida: false,
            createdAt: DateTime(2026, 1, 5),
          ),
        ]);

        expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
        expect(find.byIcon(Icons.celebration_outlined), findsOneWidget);
      },
    );

    testWidgets('Fase 71: "deuda_vinculada" usa el ícono de enlace', (
      WidgetTester tester,
    ) async {
      await _pumpScreen(tester, [
        Notificacion(
          id: 'n1',
          tipo: 'deuda_vinculada',
          mensaje: 'jherson23 te vinculó una deuda de 500.00',
          leida: false,
          createdAt: DateTime(2026, 1, 5),
        ),
      ]);

      expect(find.byIcon(Icons.link), findsOneWidget);
    });
  });
}
