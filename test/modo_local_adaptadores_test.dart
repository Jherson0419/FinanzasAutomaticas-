import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/mensaje_consejo.dart';
import 'package:finanzas_automaticas/domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/categoria_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/amistad_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/auth_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/datos_locales_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/notificacion_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/perfil_repository_local.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/local/servicios_nube_local.dart';
import 'package:finanzas_automaticas/presentation/shared/mensajes_error.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('AuthRepositoryLocal', () {
    const auth = AuthRepositoryLocal();

    test('siempre hay sesión activa', () {
      expect(auth.haySesionActiva, isTrue);
    });

    test('las operaciones de nube lanzan UnsupportedError con mensaje claro', () async {
      for (final operacion in <Future<void> Function()>[
        () => auth.iniciarSesion(email: 'a@b.c', password: 'x'),
        () => auth.crearCuenta(email: 'a@b.c', password: 'x'),
        auth.iniciarSesionConGoogle,
        auth.cerrarSesion,
        () => auth.enviarLinkRecuperacion(email: 'a@b.c'),
        () => auth.actualizarContrasena(nuevaContrasena: 'x'),
        auth.eliminarCuenta,
      ]) {
        await expectLater(
          operacion(),
          throwsA(
            isA<UnsupportedError>().having(
              mensajeDeError,
              'mensaje',
              contains('Disponible con la nube'),
            ),
          ),
        );
      }
    });
  });

  group('PerfilRepositoryLocal', () {
    test('guarda nick, avatar y demás campos en SharedPreferences', () async {
      final repo = PerfilRepositoryLocal(prefs);
      expect((await repo.obtenerPerfil()).nick, isNull);

      await repo.guardarNick('jherson');
      await repo.guardarAvatarId('cohete');
      await repo.guardarNombreCompleto('Jherson V.');
      await repo.guardarInstagram('@jv');
      await repo.guardarCelular('+51987654321');
      await repo.guardarOtraRedSocial('tiktok');

      // Una instancia nueva lee lo mismo: persiste, no está en memoria.
      final perfil = await PerfilRepositoryLocal(prefs).obtenerPerfil();
      expect(perfil.nick, 'jherson');
      expect(perfil.avatarId, 'cohete');
      expect(perfil.nombreCompleto, 'Jherson V.');
      expect(perfil.instagram, '@jv');
      expect(perfil.celular, '+51987654321');
      expect(perfil.otraRedSocial, 'tiktok');
      expect(
        prefs.getKeys().every((k) => k.startsWith('modo_local.')),
        isTrue,
      );
    });

    test('guardar null borra el campo opcional', () async {
      final repo = PerfilRepositoryLocal(prefs);
      await repo.guardarInstagram('@jv');
      await repo.guardarInstagram(null);
      expect((await repo.obtenerPerfil()).instagram, isNull);
    });

    test('nickDisponible siempre es true (no consulta ningún servidor)', () async {
      final repo = PerfilRepositoryLocal(prefs);
      await repo.guardarNick('ocupado');
      expect(await repo.nickDisponible('ocupado'), isTrue);
    });

    test('subir una foto requiere la nube', () async {
      await expectLater(
        PerfilRepositoryLocal(prefs).subirFotoAvatar([1, 2], extension: 'jpg'),
        throwsUnsupportedError,
      );
    });
  });

  group('AmistadRepositoryLocal', () {
    const repo = AmistadRepositoryLocal();

    test('las lecturas devuelven vacío', () async {
      expect(await repo.obtenerAmigos(), isEmpty);
      expect(await repo.obtenerSolicitudesRecibidas(), isEmpty);
      expect(await repo.buscarPorNick('alguien'), isNull);
    });

    test('las escrituras lanzan "No disponible en modo local"', () async {
      for (final operacion in <Future<void> Function()>[
        () => repo.enviarSolicitud('u1'),
        () => repo.aceptarSolicitud('s1'),
        () => repo.rechazarSolicitud('s1'),
        () => repo.notificarPago(
          amigoUsuarioId: 'u1',
          monto: 10,
          nombreDeuda: 'x',
        ),
      ]) {
        await expectLater(
          operacion(),
          throwsA(
            isA<UnsupportedError>().having(
              mensajeDeError,
              'mensaje',
              contains('No disponible en modo local'),
            ),
          ),
        );
      }
    });
  });

  group('NotificacionRepositoryLocal', () {
    final item = NotificacionVencimientoPendiente(
      deudaId: 'd1',
      fecha: DateTime(2026, 11, 20),
      tipo: 'cuota_por_vencer',
    );

    test('genera, persiste como JSON y usa el nombre de la deuda', () async {
      final repo = NotificacionRepositoryLocal(
        prefs,
        nombreDeuda: (id) async => id == 'd1' ? 'Préstamo personal' : null,
      );
      await repo.generarNotificacionesVencimiento([item]);

      final todas = await NotificacionRepositoryLocal(prefs).obtenerTodas();
      expect(todas, hasLength(1));
      expect(todas.single.tipo, 'cuota_por_vencer');
      expect(todas.single.mensaje, contains('Préstamo personal'));
      expect(todas.single.leida, isFalse);
      expect(todas.single.data, {
        'deuda_id': 'd1',
        'fecha': '2026-11-20',
        'tipo': 'cuota_por_vencer',
      });
      expect(prefs.getString(NotificacionRepositoryLocal.clave), isNotNull);
    });

    test('no duplica la misma deuda+fecha+tipo (igual que el RPC)', () async {
      final repo = NotificacionRepositoryLocal(prefs);
      await repo.generarNotificacionesVencimiento([item]);
      await repo.generarNotificacionesVencimiento([item, item]);
      await repo.generarNotificacionesVencimiento([
        NotificacionVencimientoPendiente(
          deudaId: 'd1',
          fecha: DateTime(2026, 11, 20),
          tipo: 'cuota_vencida',
        ),
      ]);

      expect(await repo.obtenerTodas(), hasLength(2));
    });

    test('marcarLeida persiste y obtenerTodas ordena de más nueva a más vieja', () async {
      var reloj = DateTime(2026, 11, 1);
      final repo = NotificacionRepositoryLocal(prefs, ahora: () => reloj);
      await repo.generarNotificacionesVencimiento([item]);
      reloj = DateTime(2026, 11, 2);
      await repo.generarNotificacionesVencimiento([
        NotificacionVencimientoPendiente(
          deudaId: 'd2',
          fecha: DateTime(2026, 11, 25),
          tipo: 'cuota_por_vencer',
        ),
      ]);

      final todas = await repo.obtenerTodas();
      expect(todas.first.data!['deuda_id'], 'd2');

      await repo.marcarLeida(todas.last.id);
      final releidas = await NotificacionRepositoryLocal(prefs).obtenerTodas();
      expect(releidas.last.leida, isTrue);
      expect(releidas.first.leida, isFalse);
    });

    test('lista vacía no escribe nada', () async {
      await NotificacionRepositoryLocal(prefs)
          .generarNotificacionesVencimiento(const []);
      expect(prefs.getKeys(), isEmpty);
    });
  });

  group('servicios de nube en modo local', () {
    test('automatización lanza (no hay webhook que mostrar)', () async {
      const repo = AutomatizacionRepositoryLocal();
      await expectLater(repo.obtenerTokenWebhook(), throwsUnsupportedError);
      await expectLater(repo.regenerarTokenWebhook(), throwsUnsupportedError);
    });

    test('token de dispositivo y push son no-op', () async {
      const token = TokenDispositivoRepositoryLocal();
      await token.guardarToken(token: 't', plataforma: 'ios');
      await token.eliminarToken('t');

      const push = PushNotificationRepositoryLocal();
      expect(await push.solicitarPermiso(), isFalse);
      expect(await push.obtenerToken(), isNull);
      expect(await push.mensajeInicial(), isNull);
      expect(await push.onTokenRefresh.isEmpty, isTrue);
      expect(await push.onMensajePrimerPlano.isEmpty, isTrue);
      expect(await push.onMensajeAbierto.isEmpty, isTrue);
    });

    test('consejos responde siempre con el aviso fijo', () async {
      final chat = ChatConsejosRepositoryLocal();
      await chat.enviarMensaje(mensaje: '', esPrimerMensaje: true);
      await chat.enviarMensaje(mensaje: '¿Cómo ahorro?');

      final historial = await chat.obtenerHistorial();
      expect(historial.map((m) => m.rol), [
        RolMensajeConsejo.asistente,
        RolMensajeConsejo.usuario,
        RolMensajeConsejo.asistente,
      ]);
      expect(historial[1].contenido, '¿Cómo ahorro?');
      expect(
        historial.where((m) => m.rol == RolMensajeConsejo.asistente).map(
          (m) => m.contenido,
        ),
        everyElement(ChatConsejosRepositoryLocal.respuestaFija),
      );
      expect(ChatConsejosRepositoryLocal.respuestaFija, contains('requieren la nube'));
    });
  });

  group('DatosLocalesRepositoryLocal.borrarTodo', () {
    test('vacía Drift (salvo categorías predeterminadas) y solo las claves modo_local.*', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final cuentas = CuentaRepositoryDrift(db);
      final categorias = CategoriaRepositoryDrift(db);
      final predeterminadas = (await categorias.obtenerTodas()).length;

      await cuentas.crear(
        const Cuenta(
          id: 'c1',
          nombre: 'Efectivo',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.pen,
          saldoActual: 10,
        ),
      );
      await categorias.crear(
        const Categoria(
          id: 'propia',
          nombre: 'Mascotas',
          tipo: TipoCategoria.gasto,
          iconName: 'pets',
        ),
      );
      await PerfilRepositoryLocal(prefs).guardarNick('jherson');
      await prefs.setString('ultima_generacion_notificaciones_vencimiento', 'x');
      // Claves de producción que NO deben tocarse.
      await prefs.setBool('datos_en_la_nube', true);
      await prefs.setString('tema_app', 'claro');

      await DatosLocalesRepositoryLocal(db, prefs).borrarTodo();

      expect(await cuentas.obtenerTodas(), isEmpty);
      expect(await categorias.obtenerTodas(), hasLength(predeterminadas));
      expect((await PerfilRepositoryLocal(prefs).obtenerPerfil()).nick, isNull);
      expect(prefs.containsKey('ultima_generacion_notificaciones_vencimiento'), isFalse);
      expect(prefs.getBool('datos_en_la_nube'), isTrue);
      expect(prefs.getString('tema_app'), 'claro');
    });
  });

  test('mensajeDeError quita el prefijo "Unsupported operation"', () {
    expect(mensajeDeError(UnsupportedError('Hola')), 'Hola');
  });
}
