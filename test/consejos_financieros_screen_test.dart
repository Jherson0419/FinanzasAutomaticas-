import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/mensaje_consejo.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/chat_consejos_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/consejos_financieros_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/armar_resumen_para_consejos.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/resumen_para_consejos.dart';
import 'package:finanzas_automaticas/presentation/screens/consejos_financieros_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _CuentaRepositoryVacia implements CuentaRepository {
  @override
  Future<List<Cuenta>> obtenerTodas() async => const [];
  @override
  Future<Cuenta?> obtenerPorId(String id) async => null;
  @override
  Future<void> crear(Cuenta cuenta) async {}
  @override
  Future<void> actualizar(Cuenta cuenta) async {}
  @override
  Future<void> eliminar(String id) async {}
}

class _CategoriaRepositoryVacia implements CategoriaRepository {
  @override
  Future<List<Categoria>> obtenerTodas() async => const [];
  @override
  Future<Categoria?> obtenerPorId(String id) async => null;
  @override
  Future<void> crear(Categoria categoria) async {}
  @override
  Future<void> actualizar(Categoria categoria) async {}
  @override
  Future<void> eliminar(String id) async {}
}

class _DeudaRepositoryVacia implements DeudaRepository {
  @override
  Future<List<Deuda>> obtenerTodas() async => const [];
  @override
  Future<List<Deuda>> obtenerActivas() async => const [];
  @override
  Future<Deuda?> obtenerPorId(String id) async => null;
  @override
  Future<void> crear(Deuda deuda) async {}
  @override
  Future<void> actualizar(Deuda deuda) async {}
  @override
  Future<void> eliminar(String id) async {}
}

class _TransaccionRepositoryVacia implements TransaccionRepository {
  @override
  Future<List<Transaccion>> obtenerTodas() async => const [];
  @override
  Future<Transaccion?> obtenerPorId(String id) async => null;
  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      const [];
  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];
  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];
  @override
  Future<void> crear(Transaccion transaccion) async {}
  @override
  Future<void> actualizar(Transaccion transaccion) async {}
  @override
  Future<void> eliminar(String id) async {}
}

final _armarResumenVacio = ArmarResumenParaConsejos(
  deudaRepository: _DeudaRepositoryVacia(),
  transaccionRepository: _TransaccionRepositoryVacia(),
  categoriaRepository: _CategoriaRepositoryVacia(),
  cuentaRepository: _CuentaRepositoryVacia(),
);

class _FakeChatConsejosRepository implements ChatConsejosRepository {
  _FakeChatConsejosRepository({
    List<MensajeConsejo>? historialInicial,
    this.errorAlEnviar,
  }) : historial = List.of(historialInicial ?? const []);

  final List<MensajeConsejo> historial;
  final Object? errorAlEnviar;

  int llamadasEnviarMensaje = 0;
  bool? ultimoEsPrimerMensaje;
  String? ultimoMensaje;
  ResumenParaConsejos? ultimoResumen;

  @override
  Future<List<MensajeConsejo>> obtenerHistorial() async => List.of(historial);

  @override
  Future<void> enviarMensaje({
    required String mensaje,
    bool esPrimerMensaje = false,
    ResumenParaConsejos? resumen,
  }) async {
    llamadasEnviarMensaje++;
    ultimoEsPrimerMensaje = esPrimerMensaje;
    ultimoMensaje = mensaje;
    ultimoResumen = resumen;

    if (errorAlEnviar != null) throw errorAlEnviar!;

    final ahora = DateTime.now();
    final contenidoUsuario = esPrimerMensaje
        ? 'Hola, este es mi resumen financiero simulado.'
        : mensaje;
    historial.add(
      MensajeConsejo(
        id: 'u-$llamadasEnviarMensaje',
        rol: RolMensajeConsejo.usuario,
        contenido: contenidoUsuario,
        fecha: ahora,
      ),
    );
    historial.add(
      MensajeConsejo(
        id: 'a-$llamadasEnviarMensaje',
        rol: RolMensajeConsejo.asistente,
        contenido: 'Respuesta simulada $llamadasEnviarMensaje',
        fecha: ahora,
      ),
    );
  }
}

Future<_FakeChatConsejosRepository> _pumpScreen(
  WidgetTester tester, {
  List<MensajeConsejo>? historialInicial,
  Object? errorAlEnviar,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final fake = _FakeChatConsejosRepository(
    historialInicial: historialInicial,
    errorAlEnviar: errorAlEnviar,
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatConsejosRepositoryProvider.overrideWithValue(fake),
        armarResumenParaConsejosProvider.overrideWithValue(_armarResumenVacio),
      ],
      child: const MaterialApp(home: ConsejosFinancierosScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets(
    'sin historial, arma el resumen y envía el primer mensaje solo, sin que '
    'el usuario toque nada',
    (WidgetTester tester) async {
      final fake = await _pumpScreen(tester, historialInicial: const []);

      expect(fake.llamadasEnviarMensaje, 1);
      expect(fake.ultimoEsPrimerMensaje, isTrue);
      expect(fake.ultimoResumen, isNotNull);
      expect(find.text('Respuesta simulada 1'), findsOneWidget);
    },
  );

  testWidgets(
    'con historial ya existente, NO reenvía el primer mensaje y muestra la '
    'conversación tal cual',
    (WidgetTester tester) async {
      final historial = [
        MensajeConsejo(
          id: 'm1',
          rol: RolMensajeConsejo.usuario,
          contenido: 'Hola, este es mi resumen.',
          fecha: DateTime(2026, 1, 1),
        ),
        MensajeConsejo(
          id: 'm2',
          rol: RolMensajeConsejo.asistente,
          contenido: 'Hola, encantado de ayudarte.',
          fecha: DateTime(2026, 1, 1, 0, 1),
        ),
      ];

      final fake = await _pumpScreen(tester, historialInicial: historial);

      expect(fake.llamadasEnviarMensaje, 0);
      expect(find.text('Hola, este es mi resumen.'), findsOneWidget);
      expect(find.text('Hola, encantado de ayudarte.'), findsOneWidget);
    },
  );

  testWidgets('un mensaje de seguimiento se agrega al chat', (
    WidgetTester tester,
  ) async {
    final historial = [
      MensajeConsejo(
        id: 'm1',
        rol: RolMensajeConsejo.usuario,
        contenido: 'Primer mensaje',
        fecha: DateTime(2026, 1, 1),
      ),
      MensajeConsejo(
        id: 'm2',
        rol: RolMensajeConsejo.asistente,
        contenido: 'Primera respuesta',
        fecha: DateTime(2026, 1, 1, 0, 1),
      ),
    ];
    final fake = await _pumpScreen(tester, historialInicial: historial);

    await tester.enterText(find.byType(TextField), '¿Cómo ahorro más rápido?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(fake.llamadasEnviarMensaje, 1);
    expect(fake.ultimoEsPrimerMensaje, isFalse);
    expect(fake.ultimoMensaje, '¿Cómo ahorro más rápido?');
    expect(find.text('¿Cómo ahorro más rápido?'), findsOneWidget);
    expect(find.text('Respuesta simulada 1'), findsOneWidget);
  });

  testWidgets(
    'el error de límite diario se muestra como mensaje de sistema en el '
    'chat, sin romper la pantalla',
    (WidgetTester tester) async {
      final historial = [
        MensajeConsejo(
          id: 'm1',
          rol: RolMensajeConsejo.usuario,
          contenido: 'Primer mensaje',
          fecha: DateTime(2026, 1, 1),
        ),
        MensajeConsejo(
          id: 'm2',
          rol: RolMensajeConsejo.asistente,
          contenido: 'Primera respuesta',
          fecha: DateTime(2026, 1, 1, 0, 1),
        ),
      ];
      await _pumpScreen(
        tester,
        historialInicial: historial,
        errorAlEnviar: LimiteDiarioConsejosError(),
      );

      await tester.enterText(find.byType(TextField), 'Otro mensaje');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(
        find.text('Alcanzaste el límite de mensajes por hoy. Vuelve mañana.'),
        findsOneWidget,
      );
      // La pantalla sigue en pie, con su chrome normal — no un bloque de
      // error genérico que reemplace todo el árbol de widgets.
      expect(find.text('Consejos financieros'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );
}
