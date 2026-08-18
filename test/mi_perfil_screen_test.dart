import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_cuenta_de_usuario.dart';
import 'package:finanzas_automaticas/presentation/screens/mi_perfil_screen.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakePreferenciasRepository implements PreferenciasRepository {
  String? nombre;
  String? apiKey;
  _FakePreferenciasRepository({this.nombre, this.apiKey});

  @override
  Future<String?> obtenerNombre() async => nombre;
  @override
  Future<void> guardarNombre(String nombre) async => this.nombre = nombre;
  @override
  Future<bool> onboardingCompletado() async => true;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  @override
  Future<String?> obtenerApiKeyGemini() async => apiKey;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async => this.apiKey = apiKey;
  @override
  Future<String?> obtenerPinHash() async => null;
  @override
  Future<void> guardarPinHash(String hash) async {}
  @override
  Future<bool> obtenerBloqueoBiometricoActivo() async => false;
  @override
  Future<void> guardarBloqueoBiometricoActivo(bool activo) async {}
  @override
  Future<bool> bloqueoOmitido() async => false;
  @override
  Future<void> marcarBloqueoOmitido() async {}
  @override
  Future<bool> datosEnLaNube() async => true;
  @override
  Future<void> marcarDatosEnLaNube() async {}
  @override
  Future<void> limpiarTodo() async => limpiarTodoLlamado = true;

  bool limpiarTodoLlamado = false;
}

/// Repositorios financieros "vacíos" — a `MiPerfilScreen` no le importa qué
/// hay dentro, solo si `EliminarCuentaDeUsuario` termina bien o lanza. Con
/// listas vacías, cada paso del caso de uso no tiene nada que borrar y pasa
/// directo al borrado de la cuenta de autenticación.
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

class _PagoDeudaRepositoryVacia implements PagoDeudaRepository {
  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) async => const [];
  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) async => const [];
  @override
  Future<void> crear(PagoDeuda pago) async {}
  @override
  Future<void> eliminar(String id) async {}
}

class _FakeAuthRepository implements AuthRepository {
  final bool fallaAlEliminar;
  bool eliminarCuentaLlamado = false;
  bool _haySesion = true;
  _FakeAuthRepository({this.fallaAlEliminar = false});

  @override
  bool get haySesionActiva => _haySesion;
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
  Future<void> cerrarSesion() async => _haySesion = false;
  @override
  Future<void> eliminarCuenta() async {
    eliminarCuentaLlamado = true;
    if (fallaAlEliminar) {
      throw StateError('No se pudo eliminar la cuenta: falla simulada.');
    }
    _haySesion = false;
  }
}

/// Arma el `ProviderScope` de `MiPerfilScreen` con un `Navigator` real
/// debajo (necesario para poder verificar que "Eliminar mi cuenta" hace
/// pop de la pantalla al terminar con éxito) y el `AuthRepository` fake
/// dado, para poder distinguir el caso feliz del caso de error.
typedef _EliminarCuentaFixture = ({
  _FakeAuthRepository authRepo,
  _FakePreferenciasRepository preferenciasRepo,
});

Future<_EliminarCuentaFixture> _pumpPerfilConEliminarCuenta(
  WidgetTester tester, {
  bool fallaAlEliminar = false,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final authRepo = _FakeAuthRepository(fallaAlEliminar: fallaAlEliminar);
  final preferenciasRepo = _FakePreferenciasRepository();
  final eliminarCuentaDeUsuario = EliminarCuentaDeUsuario(
    cuentaRepository: _CuentaRepositoryVacia(),
    categoriaRepository: _CategoriaRepositoryVacia(),
    deudaRepository: _DeudaRepositoryVacia(),
    transaccionRepository: _TransaccionRepositoryVacia(),
    pagoDeudaRepository: _PagoDeudaRepositoryVacia(),
    authRepository: authRepo,
  );

  // `popUntil((route) => route.isFirst)` (usado por `_eliminarCuenta`, igual
  // que `_cerrarSesion`) solo tiene efecto si `MiPerfilScreen` es la
  // SEGUNDA ruta de la pila, como en la app real (se llega empujándola
  // desde el dashboard) — con una sola ruta no hay nada que popear.
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenciasRepositoryProvider.overrideWithValue(preferenciasRepo),
        eliminarCuentaDeUsuarioProvider.overrideWithValue(
          eliminarCuentaDeUsuario,
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MiPerfilScreen()),
                ),
                child: const Text('abrir perfil'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('abrir perfil'));
  await tester.pumpAndSettle();
  return (authRepo: authRepo, preferenciasRepo: preferenciasRepo);
}

void main() {
  testWidgets(
    'precarga nombre y API key existentes, y guardarlos invoca al repositorio',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fake = _FakePreferenciasRepository(
        nombre: 'Jherson',
        apiKey: 'clave-vieja',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [preferenciasRepositoryProvider.overrideWithValue(fake)],
          child: const MaterialApp(home: MiPerfilScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Nombre'))
            .controller
            ?.text,
        'Jherson',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'API key de Gemini'),
        'clave-nueva',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(fake.apiKey, 'clave-nueva');
      expect(fake.nombre, 'Jherson');
    },
  );

  testWidgets('el campo de API key oculta el texto por defecto', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferenciasRepositoryProvider.overrideWithValue(
            _FakePreferenciasRepository(),
          ),
        ],
        child: const MaterialApp(home: MiPerfilScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final campoEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'API key de Gemini'),
        matching: find.byType(EditableText),
      ),
    );
    expect(campoEditable.obscureText, isTrue);
  });

  testWidgets(
    'el botón de confirmar "Eliminar mi cuenta" del diálogo permanece '
    'deshabilitado hasta escribir ELIMINAR',
    (WidgetTester tester) async {
      await _pumpPerfilConEliminarCuenta(tester);

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Eliminar mi cuenta'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar mi cuenta'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      final botonConfirmar = tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Eliminar mi cuenta'),
        ),
      );
      expect(botonConfirmar.onPressed, isNull);

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'algo distinto',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(
                  FilledButton,
                  'Eliminar mi cuenta',
                ),
              ),
            )
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ELIMINAR',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.widgetWithText(
                  FilledButton,
                  'Eliminar mi cuenta',
                ),
              ),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'al confirmar la eliminación, borra los datos, la cuenta de auth, '
    'limpia las preferencias locales y sale de la pantalla',
    (WidgetTester tester) async {
      final fixture = await _pumpPerfilConEliminarCuenta(tester);

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Eliminar mi cuenta'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar mi cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ELIMINAR',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Eliminar mi cuenta'),
        ),
      );
      await tester.pumpAndSettle();

      expect(fixture.authRepo.eliminarCuentaLlamado, isTrue);
      expect(fixture.authRepo.haySesionActiva, isFalse);
      expect(fixture.preferenciasRepo.limpiarTodoLlamado, isTrue);
      expect(find.byType(MiPerfilScreen), findsNothing);
    },
  );

  testWidgets(
    'si falla la eliminación, muestra un diálogo de error, no limpia las '
    'preferencias locales y deja la pantalla lista para reintentar',
    (WidgetTester tester) async {
      final fixture = await _pumpPerfilConEliminarCuenta(
        tester,
        fallaAlEliminar: true,
      );

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Eliminar mi cuenta'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Eliminar mi cuenta'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'ELIMINAR',
      );
      await tester.pump();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Eliminar mi cuenta'),
        ),
      );
      // No se usa `pumpAndSettle`: el botón queda con un
      // `CircularProgressIndicator` indeterminado (animación infinita)
      // mientras el diálogo de error espera a que el usuario lo cierre, así
      // que nunca "se asienta". Unos pocos `pump` alcanzan para que se
      // resuelva la cadena de `Future`s y el diálogo termine de construirse.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(fixture.authRepo.eliminarCuentaLlamado, isTrue);
      expect(fixture.preferenciasRepo.limpiarTodoLlamado, isFalse);
      expect(find.text('No se pudo eliminar'), findsOneWidget);
      expect(find.byType(MiPerfilScreen), findsOneWidget);
    },
  );
}
