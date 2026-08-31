import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/mensaje_push.dart';
import 'package:finanzas_automaticas/domain/entities/notificacion.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/notificacion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'package:finanzas_automaticas/presentation/app.dart';
import 'package:finanzas_automaticas/presentation/screens/notificaciones_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _NotificacionRepositoryVacio implements NotificacionRepository {
  @override
  Future<List<Notificacion>> obtenerTodas() async => [];
  @override
  Future<void> marcarLeida(String id) async {}
  @override
  Future<void> generarNotificacionesVencimiento(
    List<NotificacionVencimientoPendiente> items,
  ) async {}
}

/// Fase 71 — verifica que `FinanzasAutomaticasApp` reacciona a los 2
/// streams de `PushNotificationRepository` que expone directamente (sin
/// pasar por Firebase real): un mensaje en primer plano muestra un
/// `SnackBar`, y uno que abrió la app (tocado en segundo plano) navega a
/// `NotificacionesScreen`. `haySesionActivaProvider` en `false` evita
/// tocar Supabase — mismo criterio que `app_theme_mode_test.dart`.
Future<
  ({StreamController<MensajePush> primerPlano, StreamController<MensajePush> abierto})
>
_pumpApp(WidgetTester tester) async {
  final controladorPrimerPlano = StreamController<MensajePush>.broadcast();
  final controladorAbierto = StreamController<MensajePush>.broadcast();
  addTearDown(controladorPrimerPlano.close);
  addTearDown(controladorAbierto.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        haySesionActivaProvider.overrideWithValue(false),
        temaProvider.overrideWithValue(TemaApp.oscuro),
        notificacionRepositoryProvider.overrideWithValue(
          _NotificacionRepositoryVacio(),
        ),
        mensajePushPrimerPlanoProvider.overrideWith(
          (ref) => controladorPrimerPlano.stream,
        ),
        mensajePushAbiertoProvider.overrideWith(
          (ref) => controladorAbierto.stream,
        ),
      ],
      child: const FinanzasAutomaticasApp(),
    ),
  );
  await tester.pump();

  return (primerPlano: controladorPrimerPlano, abierto: controladorAbierto);
}

void main() {
  testWidgets(
    'un mensaje push en primer plano muestra un SnackBar con su texto',
    (WidgetTester tester) async {
      final controladores = await _pumpApp(tester);

      controladores.primerPlano.add(
        const MensajePush(
          titulo: 'Nueva notificación',
          cuerpo: 'jherson23 te vinculó una deuda de 500.00',
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('jherson23 te vinculó una deuda de 500.00'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'un mensaje push sin cuerpo (solo data) muestra un aviso genérico',
    (WidgetTester tester) async {
      final controladores = await _pumpApp(tester);

      controladores.primerPlano.add(
        const MensajePush(data: {'tipo': 'cuota_vencida'}),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Tienes una notificación nueva'), findsOneWidget);
    },
  );

  testWidgets(
    'tocar una notificación push (app en segundo plano) navega a '
    'NotificacionesScreen',
    (WidgetTester tester) async {
      final controladores = await _pumpApp(tester);

      controladores.abierto.add(
        const MensajePush(titulo: 'Aviso', cuerpo: 'Tocaste la notificación'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NotificacionesScreen), findsOneWidget);
    },
  );
}
