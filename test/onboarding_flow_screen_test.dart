import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/entities/perfil.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/perfil_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/presentation/screens/root_screen.dart';
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
  final Map<String, Deuda> deudas = {};

  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];

  @override
  Future<void> actualizar(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<void> crear(Deuda deuda) async => deudas[deuda.id] = deuda;

  @override
  Future<List<Deuda>> obtenerActivas() async => deudas.values
      .where(
        (d) => d.estado == EstadoDeuda.activa || d.estado == EstadoDeuda.enMora,
      )
      .toList();

  @override
  Future<Deuda?> obtenerPorId(String id) async => deudas[id];

  @override
  Future<List<Deuda>> obtenerTodas() async => deudas.values.toList();

  @override
  Future<void> eliminar(String id) async => deudas.remove(id);
}

class _FakeCategoriaRepository implements CategoriaRepository {
  @override
  Future<Categoria?> obtenerPorId(String id) async => null;

  @override
  Future<List<Categoria>> obtenerTodas() async => const [];

  @override
  Future<void> crear(Categoria categoria) async {}

  @override
  Future<void> actualizar(Categoria categoria) async {}

  @override
  Future<void> eliminar(String id) async {}
}

class _FakeTransaccionRepository implements TransaccionRepository {
  final Map<String, Transaccion> transacciones = {};

  @override
  Future<void> crear(Transaccion transaccion) async =>
      transacciones[transaccion.id] = transaccion;

  @override
  Future<void> actualizar(Transaccion transaccion) async =>
      transacciones[transaccion.id] = transaccion;

  @override
  Future<void> eliminar(String id) async => transacciones.remove(id);

  @override
  Future<Transaccion?> obtenerPorId(String id) async => transacciones[id];

  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) async =>
      transacciones.values.where((t) => t.cuentaId == cuentaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) async =>
      transacciones.values.where((t) => t.categoriaId == categoriaId).toList();

  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) async => const [];

  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) async => const [];

  @override
  Future<List<Transaccion>> obtenerTodas() async =>
      transacciones.values.toList();
}

class _FakePreferenciasRepository implements PreferenciasRepository {
  String? _nombre;
  bool _completado = false;
  String? _apiKeyGemini;

  @override
  Future<String?> obtenerNombre() async => _nombre;

  @override
  Future<void> guardarNombre(String nombre) async => _nombre = nombre;

  @override
  Future<bool> onboardingCompletado() async => _completado;

  @override
  Future<void> marcarOnboardingCompletado() async => _completado = true;
  @override
  Future<TemaApp> obtenerTema() async => TemaApp.oscuro;
  @override
  Future<void> guardarTema(TemaApp tema) async {}

  @override
  Future<String?> obtenerApiKeyGemini() async => _apiKeyGemini;

  @override
  Future<void> guardarApiKeyGemini(String apiKey) async =>
      _apiKeyGemini = apiKey;

  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<bool> recordarSesion() async => true;
  @override
  Future<void> guardarRecordarSesion(bool recordar) async {}
  @override
  Future<DateTime?> ultimaGeneracionNotificacionesVencimiento() async => null;
  @override
  Future<void> guardarUltimaGeneracionNotificacionesVencimiento(
    DateTime fecha,
  ) async {}
  @override
  Future<void> limpiarTodo() async {}
}

class _FakePerfilRepository implements PerfilRepository {
  String? nick;

  @override
  Future<Perfil> obtenerPerfil() async => Perfil(nick: nick);

  @override
  Future<bool> nickDisponible(String nick) async => true;

  @override
  Future<void> guardarNick(String nick) async => this.nick = nick;

  @override
  Future<void> guardarAvatarId(String avatarId) async {}

  @override
  Future<String> subirFotoAvatar(
    List<int> bytes, {
    required String extension,
  }) async => 'https://storage.example.com/avatares/prueba.$extension';

  @override
  Future<void> guardarInstagram(String? instagram) async {}

  @override
  Future<void> guardarNombreCompleto(String? nombreCompleto) async {}

  @override
  Future<void> guardarCelular(String? celular) async {}

  @override
  Future<void> guardarOtraRedSocial(String? otraRedSocial) async {}
}

class _FakeAuthRepository implements AuthRepository {
  @override
  bool get haySesionActiva => true;

  @override
  Future<void> iniciarSesion({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> crearCuenta({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> cerrarSesion() async {}

  @override
  Future<void> iniciarSesionConGoogle() async {}

  @override
  Future<void> enviarLinkRecuperacion({required String email}) async {}

  @override
  Future<void> actualizarContrasena({required String nuevaContrasena}) async {}

  @override
  Future<void> eliminarCuenta() async {}
}

void main() {
  testWidgets(
    'al completar el wizard, onboardingCompletado() devuelve true y no '
    'vuelve a mostrarse en un relanzamiento simulado',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeCuentas = _FakeCuentaRepository();
      final fakeDeudas = _FakeDeudaRepository();
      final fakeCategorias = _FakeCategoriaRepository();
      final fakeTransacciones = _FakeTransaccionRepository();
      final fakePreferencias = _FakePreferenciasRepository();
      final fakePerfil = _FakePerfilRepository();

      final overrides = [
        datosEnLaNubeProvider.overrideWithValue(false),
        cuentaRepositoryProvider.overrideWithValue(fakeCuentas),
        deudaRepositoryProvider.overrideWithValue(fakeDeudas),
        categoriaRepositoryProvider.overrideWithValue(fakeCategorias),
        transaccionRepositoryProvider.overrideWithValue(fakeTransacciones),
        preferenciasRepositoryProvider.overrideWithValue(fakePreferencias),
        perfilRepositoryProvider.overrideWithValue(fakePerfil),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      ];

      // --- Primer "lanzamiento": recorre el wizard completo. ---
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Paso 0: bienvenida.
      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Comenzar'));
      await tester.pumpAndSettle();

      // Paso 1: nombre.
      await tester.enterText(find.byType(TextFormField), 'Jherson');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      // Paso 2: nick (Fase 31) — el fake nunca reporta un nick como
      // tomado, así que basta esperar a que pase el debounce.
      await tester.enterText(find.byType(TextFormField), 'jherson_v');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('Disponible'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      // Paso 3: cuentas (obligatorio agregar al menos una).
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la cuenta'),
        'Efectivo',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(fakeCuentas.cuentas.length, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      // Paso 4: deudas (se omite).
      await tester.tap(find.widgetWithText(TextButton, 'Omitir por ahora'));
      await tester.pumpAndSettle();
      expect(fakeDeudas.deudas, isEmpty);

      // Paso 5: resumen.
      expect(find.text('Jherson'), findsOneWidget);
      expect(find.text('@jherson_v'), findsOneWidget);
      expect(find.text('Sin deudas registradas.'), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Empezar a usar la app'),
      );
      await tester.pumpAndSettle();

      expect(await fakePreferencias.onboardingCompletado(), isTrue);
      expect(await fakePreferencias.obtenerNombre(), 'Jherson');
      expect(fakePerfil.nick, 'jherson_v');
      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsNothing,
      );

      // --- "Relanzamiento" simulado: nuevo ProviderScope, mismos fakes. ---
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(home: RootScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SALDO TOTAL'), findsOneWidget);
      expect(
        find.text('Bienvenido a Finzo: Finanzas Automáticas'),
        findsNothing,
      );
    },
  );
}
