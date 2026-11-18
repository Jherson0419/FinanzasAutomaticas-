import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finanzas_automaticas/domain/entities/amistad.dart';
import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/repositories/amistad_repository.dart';
import 'package:finanzas_automaticas/domain/repositories/deuda_repository.dart';
import 'package:finanzas_automaticas/domain/usecases/actualizar_estado_mora.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_cuenta.dart';
import 'package:finanzas_automaticas/domain/usecases/editar_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/registrar_pago_deuda.dart';
import 'package:finanzas_automaticas/domain/usecases/sincronizar_deuda_tarjeta.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/cuenta_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/pago_deuda_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/transaccion_repository_drift.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/deuda_repository_supabase.dart';

import 'helpers/deuda_campos.dart';

/// Fase 79 — dos errores en el flujo de pagos de deuda:
/// - A: `RegistrarPagoDeuda` perdía `amigoUsuarioId` al reconstruir la
///   `Deuda` a mano.
/// - B: en `cuotasFijas` con interés, `montoTotal` es el capital pero el
///   pago suma la cuota completa — la deuda quedaba "pagada" antes de
///   tiempo.

class _AmistadQueNoFalla implements AmistadRepository {
  @override
  Future<void> notificarPago({
    required String amigoUsuarioId,
    required double monto,
    required String nombreDeuda,
  }) async {}
  @override
  Future<PerfilPublico?> buscarPorNick(String nick) async => null;
  @override
  Future<void> enviarSolicitud(String paraUsuarioId) async {}
  @override
  Future<List<SolicitudRecibida>> obtenerSolicitudesRecibidas() async =>
      const [];
  @override
  Future<List<PerfilPublico>> obtenerAmigos() async => const [];
  @override
  Future<void> aceptarSolicitud(String solicitudId) async {}
  @override
  Future<void> rechazarSolicitud(String solicitudId) async {}
}

/// Envuelve un `DeudaRepository` y guarda la última `Deuda` que se mandó a
/// `actualizar` — lo que un adaptador Supabase recibiría para `aFila`.
class _DeudaRepositoryQueCaptura implements DeudaRepository {
  _DeudaRepositoryQueCaptura(this._real);
  final DeudaRepository _real;
  Deuda? ultimaActualizada;

  @override
  Future<void> actualizar(Deuda deuda) {
    ultimaActualizada = deuda;
    return _real.actualizar(deuda);
  }

  @override
  Future<void> crear(Deuda deuda) => _real.crear(deuda);
  @override
  Future<void> eliminar(String id) => _real.eliminar(id);
  @override
  Future<List<Deuda>> obtenerActivas() => _real.obtenerActivas();
  @override
  Future<Deuda?> obtenerPorId(String id) => _real.obtenerPorId(id);
  @override
  Future<List<Deuda>> obtenerTodas() => _real.obtenerTodas();
  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() =>
      _real.obtenerDeudasDondeSoyElAmigo();
}

/// Mismo truco que `supabase_adapters_mapeo_test.dart`: sesión válida sin
/// red real para que `aFila` pueda leer `auth.currentUser`.
String _b64(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

Future<SupabaseClient> _clienteAutenticado(String userId) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'clave-de-prueba',
    httpClient: MockClient(
      (request) async => http.Response(
        jsonEncode({'id': userId}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ),
  );
  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  final jwt = [
    _b64({'alg': 'HS256', 'typ': 'JWT'}),
    _b64({'sub': userId, 'exp': exp, 'role': 'authenticated'}),
    _b64('firma-no-verificada-en-tests'),
  ].join('.');
  await client.auth.setSession('refresh-token-de-prueba', accessToken: jwt);
  return client;
}

void main() {
  late AppDatabase db;
  late _DeudaRepositoryQueCaptura deudas;
  late PagoDeudaRepositoryDrift pagos;
  late CuentaRepositoryDrift cuentas;
  late RegistrarPagoDeuda registrarPago;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    deudas = _DeudaRepositoryQueCaptura(DeudaRepositoryDrift(db));
    pagos = PagoDeudaRepositoryDrift(db);
    cuentas = CuentaRepositoryDrift(db);
    registrarPago = RegistrarPagoDeuda(
      pagoDeudaRepository: pagos,
      deudaRepository: deudas,
      cuentaRepository: cuentas,
      amistadRepository: _AmistadQueNoFalla(),
    );
  });

  tearDown(() => db.close());

  group('Error A — ida y vuelta: todo campo no tocado se conserva', () {
    test(
      'RegistrarPagoDeuda conserva amigoUsuarioId y el resto (Drift)',
      () async {
        final antes = deudaConTodosLosCampos(cuentaId: null);
        await deudas.crear(antes);

        await registrarPago(deudaId: antes.id, montoPagado: 50);

        final despues = (await deudas.obtenerPorId(antes.id))!;
        expect(despues.amigoUsuarioId, 'amigo-1');
        expect(despues.montoPagado, 150);
        expect(
          camposSin(despues, {'montoPagado'}),
          camposSin(antes, {'montoPagado'}),
        );
      },
    );

    test(
      'RegistrarPagoDeuda conserva amigo_usuario_id en Supabase (aFila)',
      () async {
        final repoSupabase = DeudaRepositorySupabase(
          await _clienteAutenticado('user-1'),
        );
        final antes = deudaConTodosLosCampos(cuentaId: null);
        await deudas.crear(antes);

        await registrarPago(deudaId: antes.id, montoPagado: 50);

        final fila = repoSupabase.aFila(deudas.ultimaActualizada!);
        expect(fila['amigo_usuario_id'], 'amigo-1');
        expect(fila['monto_pagado'], 150);
      },
    );

    test('EditarDeuda conserva pagos, mora, estado y amigo', () async {
      final antes = deudaConTodosLosCampos(
        cuentaId: null,
        estado: EstadoDeuda.enMora,
        enMora: true,
      );
      await deudas.crear(antes);

      await EditarDeuda(
        deudaRepository: deudas,
        pagoDeudaRepository: pagos,
      ).call(
        deudaId: antes.id,
        nombreDeuda: 'Nombre nuevo',
        tipoDeuda: antes.tipoDeuda,
        tipoAcreedor: antes.tipoAcreedor,
        nombreAcreedor: antes.nombreAcreedor,
        moneda: antes.moneda,
        montoTotal: antes.montoTotal,
        estructuraPago: antes.estructuraPago,
        tieneInteres: antes.tieneInteres,
        tasaInteres: antes.tasaInteres,
        tipoTasa: antes.tipoTasa,
        pagoMinimo: antes.pagoMinimo,
        numeroCuotasTotal: antes.numeroCuotasTotal,
        montoCuota: antes.montoCuota,
        fechaInicio: antes.fechaInicio,
        diaPago: antes.diaPago,
        notas: antes.notas,
        amigoUsuarioId: antes.amigoUsuarioId,
      );

      // En `pagoLibre`, EditarDeuda recalcula/anula a propósito los campos
      // propios de cuotas (periodicidad, interés total, cronograma).
      const recalculados = {
        'nombreDeuda',
        'periodicidadCuotas',
        'interesTotal',
        'fechaVencimientoFinal',
        'proximaFechaPago',
      };
      final despues = (await deudas.obtenerPorId(antes.id))!;
      expect(despues.nombreDeuda, 'Nombre nuevo');
      expect(camposSin(despues, recalculados), camposSin(antes, recalculados));
    });

    test('ActualizarEstadoMora solo toca enMora/diasMora/estado', () async {
      final antes = deudaConTodosLosCampos(
        estructuraPago: EstructuraPago.cuotasFijas,
        numeroCuotasPagadas: 0,
        fechaInicio: DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day - 40,
        ),
      );
      await deudas.crear(antes);

      await ActualizarEstadoMora(
        deudaRepository: deudas,
        pagoDeudaRepository: pagos,
      ).call();

      final despues = (await deudas.obtenerPorId(antes.id))!;
      expect(despues.estado, EstadoDeuda.enMora);
      const tocados = {'enMora', 'diasMora', 'estado'};
      expect(camposSin(despues, tocados), camposSin(antes, tocados));
    });

    test('SincronizarDeudaTarjeta solo toca montoTotal/montoPagado', () async {
      final antes = deudaConTodosLosCampos(cuentaId: 'tarjeta');
      await deudas.crear(antes);

      await SincronizarDeudaTarjeta(deudaRepository: deudas).call(
        const Cuenta(
          id: 'tarjeta',
          nombre: 'Visa',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -300,
          lineaCredito: 2000,
        ),
      );

      final despues = (await deudas.obtenerPorId(antes.id))!;
      expect(despues.montoTotal, 2000);
      expect(despues.montoPagado, 1700);
      // Fase 83: también copia la TCEA de la cuenta (aquí sin TCEA → sin
      // tasa y sin interés). Es un cambio buscado, no una pérdida.
      expect(despues.tasaInteres, isNull);
      expect(despues.tieneInteres, isFalse);
      const tocados = {
        'montoTotal',
        'montoPagado',
        'tasaInteres',
        'tieneInteres',
      };
      expect(camposSin(despues, tocados), camposSin(antes, tocados));
    });

    test('EditarCuenta solo toca nombreDeuda/montoTotal/montoPagado', () async {
      await cuentas.crear(
        Cuenta(
          id: 'tarjeta',
          nombre: 'Visa',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -300,
          lineaCredito: 2000,
          fechaCorte: DateTime(2026, 11, 10),
          fechaPago: DateTime(2026, 12, 5),
        ),
      );
      final antes = deudaConTodosLosCampos(cuentaId: 'tarjeta');
      await deudas.crear(antes);

      await EditarCuenta(
        cuentaRepository: cuentas,
        transaccionRepository: TransaccionRepositoryDrift(db),
        pagoDeudaRepository: pagos,
        deudaRepository: deudas,
      ).call(
        cuentaId: 'tarjeta',
        nombre: 'Visa Oro',
        tipo: TipoCuenta.credito,
        moneda: Moneda.pen,
        lineaCredito: 3000,
        fechaCorte: DateTime(2026, 11, 10),
        fechaPago: DateTime(2026, 12, 5),
      );

      final despues = (await deudas.obtenerPorId(antes.id))!;
      expect(despues.nombreDeuda, 'Visa Oro');
      // Fase 83: también copia la TCEA de la cuenta (aquí sin TCEA).
      expect(despues.tasaInteres, isNull);
      expect(despues.tieneInteres, isFalse);
      const tocados = {
        'nombreDeuda',
        'montoTotal',
        'montoPagado',
        'tasaInteres',
        'tieneInteres',
      };
      expect(camposSin(despues, tocados), camposSin(antes, tocados));
    });

    test('Deuda.copyWith() sin argumentos copia todos los campos', () {
      final original = deudaConTodosLosCampos();
      expect(camposDeuda(original.copyWith()), camposDeuda(original));
    });
  });

  group('Error B — cuotas fijas con interés no se saldan antes de tiempo', () {
    Deuda deudaCapital2000() => Deuda(
      id: 'laptop',
      nombreDeuda: 'Laptop',
      tipoDeuda: TipoDeuda.compraCuotas,
      tipoAcreedor: TipoAcreedor.comercio,
      nombreAcreedor: 'Tienda',
      moneda: Moneda.pen,
      montoTotal: 2000, // capital
      montoPagado: 0,
      tieneInteres: true,
      estructuraPago: EstructuraPago.cuotasFijas,
      numeroCuotasTotal: 12,
      numeroCuotasPagadas: 0,
      montoCuota: 210,
      periodicidadCuotas: PeriodicidadCuota.mensual,
      interesTotal: 520,
      fechaInicio: DateTime(2026, 1, 5),
      enMora: false,
      estado: EstadoDeuda.activa,
    );

    test(
      'capital 2,000 / 12 × 210: activa tras 10 y 11 pagos, pagada tras el 12',
      () async {
        await deudas.crear(deudaCapital2000());

        for (var cuota = 1; cuota <= 10; cuota++) {
          await registrarPago(
            deudaId: 'laptop',
            montoPagado: 210,
            numeroCuota: cuota,
          );
        }
        var deuda = (await deudas.obtenerPorId('laptop'))!;
        expect(deuda.montoPagado, 2100);
        expect(deuda.estado, EstadoDeuda.activa, reason: 'faltan 2 cuotas');

        await registrarPago(
          deudaId: 'laptop',
          montoPagado: 210,
          numeroCuota: 11,
        );
        deuda = (await deudas.obtenerPorId('laptop'))!;
        expect(deuda.estado, EstadoDeuda.activa, reason: 'falta 1 cuota');

        await registrarPago(
          deudaId: 'laptop',
          montoPagado: 210,
          numeroCuota: 12,
        );
        deuda = (await deudas.obtenerPorId('laptop'))!;
        expect(deuda.estado, EstadoDeuda.pagada);
        expect(deuda.numeroCuotasPagadas, 12);
      },
    );

    test('tolerancia de 0.01 por redondeo', () async {
      await deudas.crear(
        deudaConTodosLosCampos(cuentaId: null, montoTotal: 100, montoPagado: 0),
      );
      await registrarPago(deudaId: 'd1', montoPagado: 50);
      await registrarPago(deudaId: 'd1', montoPagado: 49.995);

      expect((await deudas.obtenerPorId('d1'))!.estado, EstadoDeuda.pagada);
    });

    test(
      '"Te deben" (DeudaDeAmigo.montoAdeudado) usa el saldo pendiente real',
      () {
        final repo = DeudaRepositorySupabase(
          SupabaseClient('https://example.supabase.co', 'clave-de-prueba'),
        );
        final deudaDeAmigo = repo.aDominioDeudaDeAmigo({
          'id': 'd1',
          'user_id': 'deudor',
          'nombre_deuda': 'Laptop',
          'monto_total': 2000,
          'monto_pagado': 630,
          'moneda': 'PEN',
          'estructura_pago': 'cuotas_fijas',
          'monto_cuota': 210,
          'numero_cuotas_total': 12,
        });
        expect(deudaDeAmigo.montoAdeudado, 1890);
      },
    );
  });
}
