import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:finanzas_automaticas/domain/entities/cuenta.dart';
import 'package:finanzas_automaticas/domain/entities/deuda.dart';
import 'package:finanzas_automaticas/domain/entities/categoria.dart';
import 'package:finanzas_automaticas/domain/entities/transaccion.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/categoria_repository_supabase.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/cuenta_repository_supabase.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/deuda_repository_supabase.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/pago_deuda_repository_supabase.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/supabase/transaccion_repository_supabase.dart';

/// Cliente Supabase "de mentira": nunca se llama a ningún método que haga
/// red (no hay sign-in, no hay `.from(...).select()`) — solo existe para
/// poder instanciar los adapters y llamar directamente a sus métodos
/// `aDominio` (`@visibleForTesting`), que son funciones puras de mapeo de
/// columnas y no leen `auth.currentUser`.
final _clienteFalso = SupabaseClient(
  'https://example.supabase.co',
  'clave-de-prueba',
);

/// `aFila` sí necesita `auth.currentUser` (para escribir `user_id`) —
/// hasta la Fase 26 eso hacía que solo `aDominio` tuviera cobertura de
/// test (`aFila` nunca se probó), que es parte de cómo este bug pasó
/// desapercibido. Este helper arma una sesión válida sin red real: un JWT
/// con estructura correcta y sin expirar deja que `setSession` la acepte
/// localmente (`decodeJwt` no valida la firma, solo la estructura), y el
/// único llamado de red que hace falta (`GET .../auth/v1/user`) se
/// intercepta con un `http.Client` de prueba.
String _base64UrlSinPadding(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

Future<SupabaseClient> _clienteAutenticado(String userId) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'clave-de-prueba',
    httpClient: MockClient((request) async {
      return http.Response(
        jsonEncode({'id': userId}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );

  final exp =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  final jwt = [
    _base64UrlSinPadding({'alg': 'HS256', 'typ': 'JWT'}),
    _base64UrlSinPadding({'sub': userId, 'exp': exp, 'role': 'authenticated'}),
    _base64UrlSinPadding('firma-no-verificada-en-tests'),
  ].join('.');

  await client.auth.setSession('refresh-token-de-prueba', accessToken: jwt);
  return client;
}

void main() {
  group('CuentaRepositorySupabase', () {
    final repo = CuentaRepositorySupabase(_clienteFalso);
    late CuentaRepositorySupabase repoAutenticado;

    setUpAll(() async {
      repoAutenticado = CuentaRepositorySupabase(
        await _clienteAutenticado('user-1'),
      );
    });

    test(
      'aFila manda moneda/tipo en el formato EXACTO del CHECK real '
      '(Fase 26 — antes mandaba "pen"/"usd" y violaba cuentas_moneda_check)',
      () {
        final cuenta = const Cuenta(
          id: 'cta-1',
          nombre: 'BCP Ahorros',
          tipo: TipoCuenta.debito,
          moneda: Moneda.pen,
          saldoActual: 1234.5,
        );

        final fila = repoAutenticado.aFila(cuenta);

        expect(fila['moneda'], 'PEN');
        expect(fila['tipo'], 'debito');
      },
    );

    test('aFila mapea USD en mayúsculas también', () {
      final fila = repoAutenticado.aFila(
        const Cuenta(
          id: 'cta-2',
          nombre: 'Ahorros USD',
          tipo: TipoCuenta.efectivo,
          moneda: Moneda.usd,
          saldoActual: 0,
        ),
      );

      expect(fila['moneda'], 'USD');
    });

    test(
      'aDominio mapea columnas snake_case reales (moneda en MAYÚSCULAS) a Cuenta',
      () {
        final cuenta = repo.aDominio({
          'id': 'cta-1',
          'user_id': 'user-1',
          'nombre': 'BCP Ahorros',
          'tipo': 'debito',
          'moneda': 'PEN',
          'saldo_actual': 1234.5,
        });

        expect(cuenta.id, 'cta-1');
        expect(cuenta.nombre, 'BCP Ahorros');
        expect(cuenta.tipo, TipoCuenta.debito);
        expect(cuenta.moneda, Moneda.pen);
        expect(cuenta.saldoActual, 1234.5);
      },
    );

    test('aDominio castea saldo_actual entero (num) a double', () {
      final cuenta = repo.aDominio({
        'id': 'cta-1',
        'user_id': 'user-1',
        'nombre': 'Efectivo',
        'tipo': 'efectivo',
        'moneda': 'USD',
        'saldo_actual': 100,
      });

      expect(cuenta.saldoActual, 100.0);
    });

    test('un valor de moneda legacy en minúscula ya no se lee en silencio', () {
      expect(
        () => repo.aDominio({
          'id': 'cta-1',
          'user_id': 'user-1',
          'nombre': 'Efectivo',
          'tipo': 'efectivo',
          'moneda': 'pen',
          'saldo_actual': 100,
        }),
        throwsFormatException,
      );
    });

    test('Fase 57: aFila incluye ultimos_digitos', () {
      final fila = repoAutenticado.aFila(
        const Cuenta(
          id: 'cta-1',
          nombre: 'Visa BCP',
          tipo: TipoCuenta.credito,
          moneda: Moneda.pen,
          saldoActual: -100,
          lineaCredito: 2000,
          diaCorte: 10,
          diaPago: 20,
          ultimosDigitos: '4821',
        ),
      );

      expect(fila['ultimos_digitos'], '4821');
    });

    test('Fase 57: aDominio mapea ultimos_digitos cuando viene presente', () {
      final cuenta = repo.aDominio({
        'id': 'cta-1',
        'user_id': 'user-1',
        'nombre': 'Visa BCP',
        'tipo': 'debito',
        'moneda': 'PEN',
        'saldo_actual': 100,
        'ultimos_digitos': '4821',
      });

      expect(cuenta.ultimosDigitos, '4821');
    });

    test('Fase 57: aDominio deja ultimosDigitos en null si la columna no viene', () {
      final cuenta = repo.aDominio({
        'id': 'cta-1',
        'user_id': 'user-1',
        'nombre': 'Visa BCP',
        'tipo': 'debito',
        'moneda': 'PEN',
        'saldo_actual': 100,
      });

      expect(cuenta.ultimosDigitos, isNull);
    });
  });

  group('CategoriaRepositorySupabase', () {
    final repo = CategoriaRepositorySupabase(_clienteFalso);
    late CategoriaRepositorySupabase repoAutenticado;

    setUpAll(() async {
      repoAutenticado = CategoriaRepositorySupabase(
        await _clienteAutenticado('user-1'),
      );
    });

    test('aFila manda tipo en el formato EXACTO del CHECK real', () {
      final fila = repoAutenticado.aFila(
        const Categoria(
          id: 'cat-1',
          nombre: 'Mascotas',
          tipo: TipoCategoria.gasto,
          iconName: 'category',
        ),
      );

      expect(fila['tipo'], 'gasto');
    });

    test('aDominio mapea una categoría predeterminada (user_id null)', () {
      final categoria = repo.aDominio({
        'id': 'cat-1',
        'user_id': null,
        'nombre': 'Comida',
        'tipo': 'gasto',
        'icon_name': 'restaurant',
        'es_predeterminada': true,
      });

      expect(categoria.nombre, 'Comida');
      expect(categoria.tipo, TipoCategoria.gasto);
      expect(categoria.iconName, 'restaurant');
      expect(categoria.esPredeterminada, isTrue);
    });

    test('aDominio mapea una categoría propia (user_id no nulo)', () {
      final categoria = repo.aDominio({
        'id': 'cat-2',
        'user_id': 'user-1',
        'nombre': 'Mascotas',
        'tipo': 'gasto',
        'icon_name': 'category',
        'es_predeterminada': false,
      });

      expect(categoria.esPredeterminada, isFalse);
    });
  });

  group('TransaccionRepositorySupabase', () {
    final repo = TransaccionRepositorySupabase(_clienteFalso);
    late TransaccionRepositorySupabase repoAutenticado;

    setUpAll(() async {
      repoAutenticado = TransaccionRepositorySupabase(
        await _clienteAutenticado('user-1'),
      );
    });

    Transaccion transaccionFixture({
      Moneda moneda = Moneda.pen,
      TipoTransaccion tipo = TipoTransaccion.gasto,
      MetodoPago metodoPago = MetodoPago.efectivo,
      FuenteCaptura fuenteCaptura = FuenteCaptura.manual,
    }) => Transaccion(
      id: 'tx-1',
      cuentaId: 'cta-1',
      categoriaId: 'cat-1',
      monto: 25.5,
      moneda: moneda,
      tipo: tipo,
      concepto: 'Almuerzo',
      metodoPago: metodoPago,
      esRecurrente: false,
      fuenteCaptura: fuenteCaptura,
      fecha: DateTime.parse('2026-03-01T12:00:00.000Z'),
    );

    test(
      'aFila manda moneda/fuente_captura en el formato EXACTO del CHECK real '
      '(Fase 26 — antes mandaba "pen"/"notificacionAndroid"/"correoIOS"/"ocrIOS")',
      () {
        expect(
          repoAutenticado.aFila(
            transaccionFixture(moneda: Moneda.usd),
          )['moneda'],
          'USD',
        );
        expect(
          repoAutenticado.aFila(
            transaccionFixture(
              fuenteCaptura: FuenteCaptura.notificacionAndroid,
            ),
          )['fuente_captura'],
          'notificacion_android',
        );
        expect(
          repoAutenticado.aFila(
            transaccionFixture(fuenteCaptura: FuenteCaptura.correoIOS),
          )['fuente_captura'],
          'correo_ios',
        );
        expect(
          repoAutenticado.aFila(
            transaccionFixture(fuenteCaptura: FuenteCaptura.ocrIOS),
          )['fuente_captura'],
          'ocr_ios',
        );
      },
    );

    test('aFila manda tipo/metodo_pago en el formato del CHECK real', () {
      final fila = repoAutenticado.aFila(
        transaccionFixture(
          tipo: TipoTransaccion.ingreso,
          metodoPago: MetodoPago.yape,
        ),
      );

      expect(fila['tipo'], 'ingreso');
      expect(fila['metodo_pago'], 'yape');
    });

    test('aDominio mapea columnas snake_case reales a Transaccion', () {
      final transaccion = repo.aDominio({
        'id': 'tx-1',
        'user_id': 'user-1',
        'cuenta_id': 'cta-1',
        'categoria_id': 'cat-1',
        'monto': 25.5,
        'moneda': 'PEN',
        'tipo': 'gasto',
        'concepto': 'Almuerzo',
        'metodo_pago': 'efectivo',
        'es_recurrente': false,
        'comprobante_url': null,
        'fuente_captura': 'manual',
        'data_raw': null,
        'fecha': '2026-03-01T12:00:00.000Z',
      });

      expect(transaccion.cuentaId, 'cta-1');
      expect(transaccion.categoriaId, 'cat-1');
      expect(transaccion.monto, 25.5);
      expect(transaccion.moneda, Moneda.pen);
      expect(transaccion.tipo, TipoTransaccion.gasto);
      expect(transaccion.metodoPago, MetodoPago.efectivo);
      expect(transaccion.fuenteCaptura, FuenteCaptura.manual);
      expect(transaccion.fecha, DateTime.parse('2026-03-01T12:00:00.000Z'));
    });

    test('aDominio mapea fuente_captura snake_case real a FuenteCaptura '
        '(Fase 26 — antes "notificacion_android" no calzaba con byName)', () {
      final transaccion = repo.aDominio({
        'id': 'tx-2',
        'user_id': 'user-1',
        'cuenta_id': 'cta-1',
        'categoria_id': 'cat-1',
        'monto': 10.0,
        'moneda': 'PEN',
        'tipo': 'gasto',
        'concepto': 'Notificación capturada',
        'metodo_pago': 'yape',
        'es_recurrente': false,
        'comprobante_url': null,
        'fuente_captura': 'notificacion_android',
        'data_raw': 'texto crudo',
        'fecha': '2026-03-01T12:00:00.000Z',
      });

      expect(transaccion.fuenteCaptura, FuenteCaptura.notificacionAndroid);
    });
  });

  group('DeudaRepositorySupabase', () {
    final repo = DeudaRepositorySupabase(_clienteFalso);
    late DeudaRepositorySupabase repoAutenticado;

    setUpAll(() async {
      repoAutenticado = DeudaRepositorySupabase(
        await _clienteAutenticado('user-1'),
      );
    });

    Deuda deudaFixture({
      TipoDeuda tipoDeuda = TipoDeuda.prestamoPersonal,
      TipoAcreedor tipoAcreedor = TipoAcreedor.entidadFinanciera,
      Moneda moneda = Moneda.pen,
      TipoTasa? tipoTasa,
      EstructuraPago estructuraPago = EstructuraPago.cuotasFijas,
      PeriodicidadCuota? periodicidadCuotas = PeriodicidadCuota.mensual,
      EstadoDeuda estado = EstadoDeuda.activa,
    }) => Deuda(
      id: 'deuda-1',
      nombreDeuda: 'Préstamo',
      tipoDeuda: tipoDeuda,
      tipoAcreedor: tipoAcreedor,
      nombreAcreedor: 'BCP',
      moneda: moneda,
      montoTotal: 10000.0,
      montoPagado: 2000.0,
      tieneInteres: true,
      tipoTasa: tipoTasa,
      estructuraPago: estructuraPago,
      periodicidadCuotas: periodicidadCuotas,
      fechaInicio: DateTime.parse('2026-01-01T00:00:00.000Z'),
      enMora: false,
      estado: estado,
    );

    test(
      'aFila manda tipo_deuda/tipo_acreedor en snake_case EXACTO del CHECK '
      'real (Fase 26 — antes mandaba "prestamoVehicular"/"entidadFinanciera")',
      () {
        for (final (valor, esperado) in [
          (TipoDeuda.tarjetaCredito, 'tarjeta_credito'),
          (TipoDeuda.prestamoPersonal, 'prestamo_personal'),
          (TipoDeuda.prestamoVehicular, 'prestamo_vehicular'),
          (TipoDeuda.hipoteca, 'hipoteca'),
          (TipoDeuda.prestamoEstudiantil, 'prestamo_estudiantil'),
          (TipoDeuda.compraCuotas, 'compra_cuotas'),
          (TipoDeuda.deudaInformal, 'deuda_informal'),
          (TipoDeuda.otro, 'otro'),
        ]) {
          expect(
            repoAutenticado.aFila(deudaFixture(tipoDeuda: valor))['tipo_deuda'],
            esperado,
          );
        }

        expect(
          repoAutenticado.aFila(
            deudaFixture(tipoAcreedor: TipoAcreedor.personaNatural),
          )['tipo_acreedor'],
          'persona_natural',
        );
      },
    );

    test('aFila manda estructura_pago/estado en snake_case EXACTO del CHECK '
        'real (Fase 26 — antes mandaba "cuotasFijas"/"enMora")', () {
      expect(
        repoAutenticado.aFila(
          deudaFixture(estructuraPago: EstructuraPago.pagoLibre),
        )['estructura_pago'],
        'pago_libre',
      );
      expect(
        repoAutenticado.aFila(
          deudaFixture(estado: EstadoDeuda.enMora),
        )['estado'],
        'en_mora',
      );
    });

    test(
      'aFila manda moneda en mayúsculas y tipo_tasa/periodicidad tal cual',
      () {
        final fila = repoAutenticado.aFila(
          deudaFixture(
            moneda: Moneda.usd,
            tipoTasa: TipoTasa.variable,
            periodicidadCuotas: PeriodicidadCuota.quincenal,
          ),
        );

        expect(fila['moneda'], 'USD');
        expect(fila['tipo_tasa'], 'variable');
        expect(fila['periodicidad_cuotas'], 'quincenal');
      },
    );

    test(
      'aFila manda tipo_tasa/periodicidad_cuotas null cuando no aplican',
      () {
        final fila = repoAutenticado.aFila(
          deudaFixture(
            estructuraPago: EstructuraPago.pagoLibre,
            periodicidadCuotas: null,
            tipoTasa: null,
          ),
        );

        expect(fila['tipo_tasa'], isNull);
        expect(fila['periodicidad_cuotas'], isNull);
      },
    );

    test('aDominio mapea una deuda cuotasFijas completa desde columnas reales '
        '(snake_case, moneda en MAYÚSCULAS)', () {
      final deuda = repo.aDominio({
        'id': 'deuda-1',
        'user_id': 'user-1',
        'nombre_deuda': 'Préstamo auto',
        'tipo_deuda': 'prestamo_vehicular',
        'tipo_acreedor': 'entidad_financiera',
        'nombre_acreedor': 'BCP',
        'moneda': 'PEN',
        'monto_total': 10000.0,
        'monto_pagado': 2000.0,
        'tiene_interes': true,
        'tasa_interes': null,
        'tipo_tasa': null,
        'estructura_pago': 'cuotas_fijas',
        'numero_cuotas_total': 12,
        'numero_cuotas_pagadas': 2,
        'monto_cuota': 900.0,
        'pago_minimo': null,
        'periodicidad_cuotas': 'mensual',
        'interes_total': 800.0,
        'fecha_inicio': '2026-01-01T00:00:00.000Z',
        'fecha_vencimiento_final': null,
        'dia_pago': null,
        'proxima_fecha_pago': '2026-04-01T00:00:00.000Z',
        'en_mora': false,
        'dias_mora': null,
        'tasa_interes_moratorio': null,
        'estado': 'activa',
        'notas': null,
      });

      expect(deuda.nombreDeuda, 'Préstamo auto');
      expect(deuda.tipoDeuda, TipoDeuda.prestamoVehicular);
      expect(deuda.tipoAcreedor, TipoAcreedor.entidadFinanciera);
      expect(deuda.moneda, Moneda.pen);
      expect(deuda.estructuraPago, EstructuraPago.cuotasFijas);
      expect(deuda.periodicidadCuotas, PeriodicidadCuota.mensual);
      expect(deuda.numeroCuotasTotal, 12);
      expect(
        deuda.proximaFechaPago,
        DateTime.parse('2026-04-01T00:00:00.000Z'),
      );
      expect(deuda.estado, EstadoDeuda.activa);
    });

    test(
      'aDominio mapea "en_mora" snake_case real a EstadoDeuda.enMora '
      '(Fase 26 — antes "en_mora" no calzaba con byName y tronaba al leer)',
      () {
        final deuda = repo.aDominio({
          'id': 'deuda-3',
          'user_id': 'user-1',
          'nombre_deuda': 'Tarjeta vencida',
          'tipo_deuda': 'tarjeta_credito',
          'tipo_acreedor': 'entidad_financiera',
          'nombre_acreedor': 'BBVA',
          'moneda': 'PEN',
          'monto_total': 500.0,
          'monto_pagado': 0.0,
          'tiene_interes': false,
          'tasa_interes': null,
          'tipo_tasa': null,
          'estructura_pago': 'pago_libre',
          'numero_cuotas_total': null,
          'numero_cuotas_pagadas': null,
          'monto_cuota': null,
          'pago_minimo': null,
          'periodicidad_cuotas': null,
          'interes_total': null,
          'fecha_inicio': '2026-01-01T00:00:00.000Z',
          'fecha_vencimiento_final': null,
          'dia_pago': null,
          'proxima_fecha_pago': null,
          'en_mora': true,
          'dias_mora': 10,
          'tasa_interes_moratorio': null,
          'estado': 'en_mora',
          'notas': null,
        });

        expect(deuda.estado, EstadoDeuda.enMora);
      },
    );

    test('aDominio mapea una deuda pagoLibre con campos nulos', () {
      final deuda = repo.aDominio({
        'id': 'deuda-2',
        'user_id': 'user-1',
        'nombre_deuda': 'Tarjeta',
        'tipo_deuda': 'tarjeta_credito',
        'tipo_acreedor': 'entidad_financiera',
        'nombre_acreedor': 'BBVA',
        'moneda': 'USD',
        'monto_total': 500.0,
        'monto_pagado': 0.0,
        'tiene_interes': true,
        'tasa_interes': 45.0,
        'tipo_tasa': 'variable',
        'estructura_pago': 'pago_libre',
        'numero_cuotas_total': null,
        'numero_cuotas_pagadas': null,
        'monto_cuota': null,
        'pago_minimo': 50.0,
        'periodicidad_cuotas': null,
        'interes_total': null,
        'fecha_inicio': '2026-01-01T00:00:00.000Z',
        'fecha_vencimiento_final': null,
        'dia_pago': null,
        'proxima_fecha_pago': null,
        'en_mora': false,
        'dias_mora': null,
        'tasa_interes_moratorio': null,
        'estado': 'activa',
        'notas': 'nota libre',
      });

      expect(deuda.tipoTasa, TipoTasa.variable);
      expect(deuda.moneda, Moneda.usd);
      expect(deuda.periodicidadCuotas, isNull);
      expect(deuda.proximaFechaPago, isNull);
      expect(deuda.notas, 'nota libre');
    });
  });

  group('PagoDeudaRepositorySupabase', () {
    final repo = PagoDeudaRepositorySupabase(_clienteFalso);

    test('aDominio mapea un pago con desglose capital/interés', () {
      final pago = repo.aDominio({
        'id': 'pago-1',
        'user_id': 'user-1',
        'deuda_id': 'deuda-1',
        'cuenta_id': 'cta-1',
        'monto_pagado': 900.0,
        'monto_capital': 850.0,
        'monto_interes': 50.0,
        'fecha_pago': '2026-02-01T00:00:00.000Z',
        'numero_cuota': 1,
      });

      expect(pago.deudaId, 'deuda-1');
      expect(pago.cuentaId, 'cta-1');
      expect(pago.montoCapital, 850.0);
      expect(pago.montoInteres, 50.0);
      expect(pago.numeroCuota, 1);
    });

    test('aDominio mapea un pago retroactivo (cuenta_id nulo)', () {
      final pago = repo.aDominio({
        'id': 'pago-2',
        'user_id': 'user-1',
        'deuda_id': 'deuda-1',
        'cuenta_id': null,
        'monto_pagado': 300.0,
        'monto_capital': null,
        'monto_interes': null,
        'fecha_pago': '2025-06-01T00:00:00.000Z',
        'numero_cuota': null,
      });

      expect(pago.cuentaId, isNull);
      expect(pago.montoCapital, isNull);
    });
  });
}
