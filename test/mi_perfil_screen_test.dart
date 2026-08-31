import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/mensaje_push.dart';
import 'package:finanzas_automaticas/domain/entities/pago_deuda.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/domain/repositories/auth_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/categoria_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/cuenta_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/pago_deuda_repository.dart';
import 'package:finanzas_automaticas/domain/entities/perfil.dart';
import 'package:finanzas_automaticas/domain/entities/tema_app.dart';
import 'package:finanzas_automaticas/domain/repositories/perfil_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/preferencias_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/push_notification_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/token_dispositivo_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/transaccion_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/eliminar_cuenta_de_usuario.dart';
import 'package:finanzas_automaticas/presentation/screens/mi_perfil_screen.dart';
import 'package:finanzas_automaticas/presentation/shared/selector_avatar.dart';
import 'package:finanzas_automaticas/presentation/state/providers.dart';

class _FakePreferenciasRepository implements PreferenciasRepository {
  String? nombre;
  _FakePreferenciasRepository({this.nombre});

  @override
  Future<String?> obtenerNombre() async => nombre;
  @override
  Future<void> guardarNombre(String nombre) async => this.nombre = nombre;
  @override
  Future<bool> onboardingCompletado() async => true;
  @override
  Future<void> marcarOnboardingCompletado() async {}
  TemaApp temaActual = TemaApp.oscuro;
  @override
  Future<TemaApp> obtenerTema() async => temaActual;
  @override
  Future<void> guardarTema(TemaApp tema) async => temaActual = tema;
  // Fase 24: `MiPerfilScreen` ya no lee ni escribe la API key de Gemini —
  // se mantienen estos dos overrides solo porque el puerto los sigue
  // exigiendo (compatibilidad con `GeminiConsejosRepository`, desconectado
  // pero no borrado).
  @override
  Future<String?> obtenerApiKeyGemini() async => null;
  @override
  Future<void> guardarApiKeyGemini(String apiKey) async {}
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
  Future<void> limpiarTodo() async => limpiarTodoLlamado = true;

  bool limpiarTodoLlamado = false;
}

class _FakePerfilRepository implements PerfilRepository {
  _FakePerfilRepository({
    String? nick,
    this.avatarId,
    this.instagram,
    this.nombreCompleto,
    this.celular,
    this.otraRedSocial,
  }) : _nick = nick;

  String? _nick;
  String? avatarId;
  String? instagram;
  String? nombreCompleto;
  String? celular;
  String? otraRedSocial;

  /// Extensión con la que se llamó `subirFotoAvatar` por última vez — para
  /// verificar en los tests que `_extensionDeFoto` la dedujo bien.
  String? extensionSubida;

  @override
  Future<Perfil> obtenerPerfil() async => Perfil(
    nick: _nick,
    avatarId: avatarId,
    instagram: instagram,
    nombreCompleto: nombreCompleto,
    celular: celular,
    otraRedSocial: otraRedSocial,
  );

  @override
  Future<bool> nickDisponible(String nick) async => true;

  @override
  Future<void> guardarNick(String nick) async => _nick = nick;

  @override
  Future<void> guardarAvatarId(String avatarId) async =>
      this.avatarId = avatarId;

  @override
  Future<String> subirFotoAvatar(
    List<int> bytes, {
    required String extension,
  }) async {
    extensionSubida = extension;
    return 'https://storage.example.com/avatares/usuario-de-prueba/avatar.$extension';
  }

  @override
  Future<void> guardarInstagram(String? instagram) async =>
      this.instagram = instagram;

  @override
  Future<void> guardarNombreCompleto(String? nombreCompleto) async =>
      this.nombreCompleto = nombreCompleto;

  @override
  Future<void> guardarCelular(String? celular) async => this.celular = celular;

  @override
  Future<void> guardarOtraRedSocial(String? otraRedSocial) async =>
      this.otraRedSocial = otraRedSocial;
}

/// Fake de `ImagePickerPlatform` (Fase 56) — el punto de extensión oficial
/// del paquete `image_picker` para no depender de canales de plataforma
/// reales en tests. [archivoAEntregar] es lo que "elige" el usuario
/// simulado en la galería; `null` simula cerrar el selector sin elegir
/// nada.
class _FakeImagePickerPlatform extends ImagePickerPlatform {
  XFile? archivoAEntregar;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => archivoAEntregar;
}

/// Fake de `SharePlatform` (Fase 67): mismo patrón que `_FakeUrlLauncherPlatform`
/// en `supabase_auth_repository_test.dart` (Fase 59) —
/// `Fake` + `MockPlatformInterfaceMixin` es el mecanismo propio de
/// `plugin_platform_interface` para sustituir un `PlatformInterface` sin
/// tocar ningún canal de plataforma real. Permite comprobar CON QUÉ
/// `ShareParams` se llama `SharePlus.instance.share` — en particular, que
/// `sharePositionOrigin` viaja no nulo y no-cero (el bug de esta fase).
class _FakeSharePlatform extends Fake
    with MockPlatformInterfaceMixin
    implements SharePlatform {
  ShareParams? paramsRecibidos;

  @override
  Future<ShareResult> share(ShareParams params) async {
    paramsRecibidos = params;
    return const ShareResult('', ShareResultStatus.success);
  }
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
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() async => const [];
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
  final List<String> eventos;
  bool eliminarCuentaLlamado = false;
  bool _haySesion = true;
  _FakeAuthRepository({this.fallaAlEliminar = false, List<String>? eventos})
    : eventos = eventos ?? [];

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
  Future<void> cerrarSesion() async {
    eventos.add('cerrarSesion');
    _haySesion = false;
  }
  @override
  Future<void> iniciarSesionConGoogle() async {}
  @override
  Future<void> enviarLinkRecuperacion({required String email}) async {}
  @override
  Future<void> actualizarContrasena({required String nuevaContrasena}) async {}
  @override
  Future<void> eliminarCuenta() async {
    eliminarCuentaLlamado = true;
    if (fallaAlEliminar) {
      throw StateError('No se pudo eliminar la cuenta: falla simulada.');
    }
    _haySesion = false;
  }
}

/// Fase 71 — usado solo por el grupo de tests de "cerrar sesión borra el
/// token de push de este dispositivo".
class _FakePushNotificationRepository implements PushNotificationRepository {
  String? token = 'token-abc';

  @override
  String plataforma = 'ios';

  @override
  Future<bool> solicitarPermiso() async => true;

  @override
  Future<String?> obtenerToken() async => token;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Stream<MensajePush> get onMensajePrimerPlano => const Stream.empty();

  @override
  Stream<MensajePush> get onMensajeAbierto => const Stream.empty();

  @override
  Future<MensajePush?> mensajeInicial() async => null;
}

class _FakeTokenDispositivoRepository implements TokenDispositivoRepository {
  final List<String> eventos;
  String? tokenEliminado;
  _FakeTokenDispositivoRepository({List<String>? eventos})
    : eventos = eventos ?? [];

  @override
  Future<void> guardarToken({
    required String token,
    required String plataforma,
  }) async {}

  @override
  Future<void> eliminarToken(String token) async {
    eventos.add('eliminarToken');
    tokenEliminado = token;
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
        perfilRepositoryProvider.overrideWithValue(_FakePerfilRepository()),
        temaProvider.overrideWithValue(TemaApp.oscuro),
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

/// Arma el `ProviderScope` de `MiPerfilScreen` sola (sin `Navigator` extra
/// debajo) — usado por los tests que no necesitan verificar "pop" al salir.
Future<_FakePerfilRepository> _pumpPerfilScreen(
  WidgetTester tester, {
  _FakePreferenciasRepository? preferencias,
  _FakePerfilRepository? perfil,
}) async {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final perfilRepo = perfil ?? _FakePerfilRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferenciasRepositoryProvider.overrideWithValue(
          preferencias ?? _FakePreferenciasRepository(),
        ),
        perfilRepositoryProvider.overrideWithValue(perfilRepo),
        temaProvider.overrideWithValue(TemaApp.oscuro),
      ],
      child: const MaterialApp(home: MiPerfilScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return perfilRepo;
}

/// Fase 56: reemplaza `ImagePickerPlatform.instance` por un fake que
/// entrega [archivoAEntregar] antes de pumpear la pantalla, y lo restaura
/// al terminar el test — mismo patrón oficial de `image_picker` para
/// probar sin canales de plataforma reales.
Future<_FakePerfilRepository> _pumpPerfilScreenConFotoElegida(
  WidgetTester tester, {
  required XFile? archivoAEntregar,
}) async {
  final platformOriginal = ImagePickerPlatform.instance;
  ImagePickerPlatform.instance = _FakeImagePickerPlatform()
    ..archivoAEntregar = archivoAEntregar;
  addTearDown(() => ImagePickerPlatform.instance = platformOriginal);

  return _pumpPerfilScreen(
    tester,
    perfil: _FakePerfilRepository(nick: 'jherson_v'),
  );
}

void main() {
  testWidgets(
    'precarga el nombre existente, y guardarlo invoca al repositorio',
    (WidgetTester tester) async {
      final fake = _FakePreferenciasRepository(nombre: 'Jherson');
      await _pumpPerfilScreen(tester, preferencias: fake);

      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Nombre'))
            .controller
            ?.text,
        'Jherson',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Jherson V.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(fake.nombre, 'Jherson V.');
    },
  );

  testWidgets(
    'ya no muestra el campo de API key de Gemini (Fase 24: la API key es '
    'del distribuidor, vía Edge Function, nunca del usuario)',
    (WidgetTester tester) async {
      await _pumpPerfilScreen(tester);

      expect(
        find.widgetWithText(TextFormField, 'API key de Gemini'),
        findsNothing,
      );
      expect(find.text('Consejos financieros con IA'), findsNothing);
    },
  );

  testWidgets(
    'el nick precargado se muestra de solo lectura (sin campo editable)',
    (WidgetTester tester) async {
      await _pumpPerfilScreen(
        tester,
        perfil: _FakePerfilRepository(nick: 'jherson_v'),
      );

      expect(find.text('@jherson_v'), findsOneWidget);
      expect(find.text('El nick no se puede cambiar'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nick'), findsNothing);
    },
  );

  testWidgets(
    'precarga el avatar ya guardado (no el de por defecto) al abrir la '
    'pantalla',
    (WidgetTester tester) async {
      await _pumpPerfilScreen(
        tester,
        perfil: _FakePerfilRepository(nick: 'jherson_v', avatarId: 'rayo'),
      );

      final circulo = tester.widget<AvatarCirculo>(
        find.byType(AvatarCirculo).first,
      );
      expect(circulo.avatarId, 'rayo');
    },
  );

  testWidgets(
    'precarga el Instagram ya guardado en el campo, sin dejarlo vacío',
    (WidgetTester tester) async {
      await _pumpPerfilScreen(
        tester,
        perfil: _FakePerfilRepository(
          nick: 'jherson_v',
          instagram: '@jherson.finanzas',
        ),
      );

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Instagram (opcional)'),
            )
            .controller
            ?.text,
        '@jherson.finanzas',
      );
    },
  );

  testWidgets(
    'tocar el avatar abre la galería, sube la foto elegida y guarda la URL '
    'devuelta',
    (WidgetTester tester) async {
      final perfilRepo = await _pumpPerfilScreenConFotoElegida(
        tester,
        archivoAEntregar: XFile.fromData(
          Uint8List.fromList([1, 2, 3]),
          path: 'foto.jpg',
          mimeType: 'image/jpeg',
        ),
      );

      await tester.tap(find.byType(AvatarCirculo).first);
      await tester.pumpAndSettle();

      expect(perfilRepo.extensionSubida, 'jpg');
      expect(
        perfilRepo.avatarId,
        'https://storage.example.com/avatares/usuario-de-prueba/avatar.jpg',
      );
    },
  );

  testWidgets(
    'si el usuario cierra la galería sin elegir nada, el avatar no cambia',
    (WidgetTester tester) async {
      final perfilRepo = await _pumpPerfilScreenConFotoElegida(
        tester,
        archivoAEntregar: null,
      );

      await tester.tap(find.byType(AvatarCirculo).first);
      await tester.pumpAndSettle();

      expect(perfilRepo.avatarId, isNull);
    },
  );

  testWidgets('guardar Instagram invoca a PerfilRepository.guardarInstagram', (
    WidgetTester tester,
  ) async {
    final perfilRepo = await _pumpPerfilScreen(
      tester,
      perfil: _FakePerfilRepository(nick: 'jherson_v'),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Instagram (opcional)'),
      '@jherson.finanzas',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(perfilRepo.instagram, '@jherson.finanzas');
  });

  testWidgets(
    'Fase 56: precarga nombre completo/celular/otra red social ya '
    'guardados, y guardarlos invoca a PerfilRepository',
    (WidgetTester tester) async {
      final perfilRepo = await _pumpPerfilScreen(
        tester,
        perfil: _FakePerfilRepository(
          nick: 'jherson_v',
          nombreCompleto: 'Jherson Vásquez Castillo',
          celular: '+51987654321',
          otraRedSocial: '@jherson_tt',
        ),
      );

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Nombre completo (opcional)'),
            )
            .controller
            ?.text,
        'Jherson Vásquez Castillo',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Celular (opcional)'),
            )
            .controller
            ?.text,
        '+51987654321',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Otra red social (opcional)'),
            )
            .controller
            ?.text,
        '@jherson_tt',
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo (opcional)'),
        'Jherson V. C.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(perfilRepo.nombreCompleto, 'Jherson V. C.');
      expect(perfilRepo.celular, '+51987654321');
      expect(perfilRepo.otraRedSocial, '@jherson_tt');
    },
  );

  testWidgets(
    'Fase 56: un celular con formato inválido muestra error inline y '
    'deshabilita Guardar',
    (WidgetTester tester) async {
      await _pumpPerfilScreen(
        tester,
        perfil: _FakePerfilRepository(nick: 'jherson_v'),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Celular (opcional)'),
        'no-es-un-numero',
      );
      await tester.pump();

      expect(find.text('Formato de celular inválido'), findsOneWidget);
      final boton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar'),
      );
      expect(boton.onPressed, isNull);
    },
  );

  testWidgets('el selector de Apariencia guarda el TemaApp elegido', (
    WidgetTester tester,
  ) async {
    final preferencias = _FakePreferenciasRepository();
    await _pumpPerfilScreen(tester, preferencias: preferencias);

    expect(preferencias.temaActual, TemaApp.oscuro);

    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();

    expect(preferencias.temaActual, TemaApp.claro);
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

  group('Fase 67 — "Compartir mi perfil" pasa sharePositionOrigin', () {
    late SharePlatform plataformaOriginal;
    late _FakeSharePlatform fakeShare;

    setUp(() {
      plataformaOriginal = SharePlatform.instance;
      fakeShare = _FakeSharePlatform();
      SharePlatform.instance = fakeShare;
    });

    tearDown(() {
      SharePlatform.instance = plataformaOriginal;
    });

    testWidgets(
      'tocar "Compartir mi perfil" comparte con un sharePositionOrigin no '
      'nulo y no-cero (antes faltaba, y iOS lo exige)',
      (WidgetTester tester) async {
        await _pumpPerfilScreen(
          tester,
          perfil: _FakePerfilRepository(nick: 'jherson_v'),
        );

        await tester.tap(find.text('Compartir mi perfil'));
        await tester.pumpAndSettle();

        final params = fakeShare.paramsRecibidos;
        expect(params, isNotNull);
        expect(params!.sharePositionOrigin, isNotNull);
        expect(params.sharePositionOrigin, isNot(Rect.zero));
        expect(params.text, contains('finzo://agregar-amigo?nick=jherson_v'));
      },
    );
  });

  group('Fase 71 — cerrar sesión elimina el token de push de este dispositivo', () {
    Future<
      ({
        _FakeAuthRepository authRepo,
        _FakeTokenDispositivoRepository tokenRepo,
        List<String> eventos,
      })
    >
    pumpParaCerrarSesion(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final eventos = <String>[];
      final authRepo = _FakeAuthRepository(eventos: eventos);
      final tokenRepo = _FakeTokenDispositivoRepository(eventos: eventos);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(authRepo),
            pushNotificationRepositoryProvider.overrideWithValue(
              _FakePushNotificationRepository(),
            ),
            tokenDispositivoRepositoryProvider.overrideWithValue(tokenRepo),
            preferenciasRepositoryProvider.overrideWithValue(
              _FakePreferenciasRepository(),
            ),
            perfilRepositoryProvider.overrideWithValue(_FakePerfilRepository()),
            temaProvider.overrideWithValue(TemaApp.oscuro),
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

      return (authRepo: authRepo, tokenRepo: tokenRepo, eventos: eventos);
    }

    testWidgets(
      'confirmar "Cerrar sesión" elimina el token de este dispositivo antes '
      'de cerrar la sesión de Supabase',
      (WidgetTester tester) async {
        final fixture = await pumpParaCerrarSesion(tester);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Cerrar sesión'));
        await tester.pumpAndSettle();

        expect(fixture.tokenRepo.tokenEliminado, 'token-abc');
        expect(fixture.authRepo.haySesionActiva, isFalse);
        expect(fixture.eventos, ['eliminarToken', 'cerrarSesion']);
      },
    );

    testWidgets('cancelar el diálogo no elimina ningún token ni cierra sesión', (
      WidgetTester tester,
    ) async {
      final fixture = await pumpParaCerrarSesion(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(fixture.tokenRepo.tokenEliminado, isNull);
      expect(fixture.authRepo.haySesionActiva, isTrue);
    });
  });
}
