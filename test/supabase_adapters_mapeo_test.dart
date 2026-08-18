import 'package:flutter_test/flutter_test.dart';
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
/// `aDominio`/`aFila` (`@visibleForTesting`), que son funciones puras de
/// mapeo de columnas. Es el mismo motivo por el que
/// `SupabaseAuthRepository`/`GeminiConsejosRepository` de fases anteriores
/// son testeables sin red: la lógica de negocio (aquí, el mapeo) está
/// separada de la llamada HTTP en sí.
final _clienteFalso = SupabaseClient(
  'https://example.supabase.co',
  'clave-de-prueba',
);

void main() {
  group('CuentaRepositorySupabase', () {
    final repo = CuentaRepositorySupabase(_clienteFalso);

    test('aDominio mapea columnas snake_case a Cuenta', () {
      final cuenta = repo.aDominio({
        'id': 'cta-1',
        'user_id': 'user-1',
        'nombre': 'BCP Ahorros',
        'tipo': 'debito',
        'moneda': 'pen',
        'saldo_actual': 1234.5,
      });

      expect(cuenta.id, 'cta-1');
      expect(cuenta.nombre, 'BCP Ahorros');
      expect(cuenta.tipo, TipoCuenta.debito);
      expect(cuenta.moneda, Moneda.pen);
      expect(cuenta.saldoActual, 1234.5);
    });

    test('aDominio castea saldo_actual entero (num) a double', () {
      final cuenta = repo.aDominio({
        'id': 'cta-1',
        'user_id': 'user-1',
        'nombre': 'Efectivo',
        'tipo': 'efectivo',
        'moneda': 'usd',
        'saldo_actual': 100,
      });

      expect(cuenta.saldoActual, 100.0);
    });
  });

  group('CategoriaRepositorySupabase', () {
    final repo = CategoriaRepositorySupabase(_clienteFalso);

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

    test('aDominio mapea columnas snake_case a Transaccion', () {
      final transaccion = repo.aDominio({
        'id': 'tx-1',
        'user_id': 'user-1',
        'cuenta_id': 'cta-1',
        'categoria_id': 'cat-1',
        'monto': 25.5,
        'moneda': 'pen',
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
      expect(transaccion.tipo, TipoTransaccion.gasto);
      expect(transaccion.metodoPago, MetodoPago.efectivo);
      expect(transaccion.fuenteCaptura, FuenteCaptura.manual);
      expect(transaccion.fecha, DateTime.parse('2026-03-01T12:00:00.000Z'));
    });
  });

  group('DeudaRepositorySupabase', () {
    final repo = DeudaRepositorySupabase(_clienteFalso);

    test('aDominio mapea una deuda cuotasFijas completa', () {
      final deuda = repo.aDominio({
        'id': 'deuda-1',
        'user_id': 'user-1',
        'nombre_deuda': 'Préstamo auto',
        'tipo_deuda': 'prestamoVehicular',
        'tipo_acreedor': 'entidadFinanciera',
        'nombre_acreedor': 'BCP',
        'moneda': 'pen',
        'monto_total': 10000.0,
        'monto_pagado': 2000.0,
        'tiene_interes': true,
        'tasa_interes': null,
        'tipo_tasa': null,
        'estructura_pago': 'cuotasFijas',
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
      expect(deuda.estructuraPago, EstructuraPago.cuotasFijas);
      expect(deuda.periodicidadCuotas, PeriodicidadCuota.mensual);
      expect(deuda.numeroCuotasTotal, 12);
      expect(
        deuda.proximaFechaPago,
        DateTime.parse('2026-04-01T00:00:00.000Z'),
      );
      expect(deuda.estado, EstadoDeuda.activa);
    });

    test('aDominio mapea una deuda pagoLibre con campos nulos', () {
      final deuda = repo.aDominio({
        'id': 'deuda-2',
        'user_id': 'user-1',
        'nombre_deuda': 'Tarjeta',
        'tipo_deuda': 'tarjetaCredito',
        'tipo_acreedor': 'entidadFinanciera',
        'nombre_acreedor': 'BBVA',
        'moneda': 'usd',
        'monto_total': 500.0,
        'monto_pagado': 0.0,
        'tiene_interes': true,
        'tasa_interes': 45.0,
        'tipo_tasa': 'variable',
        'estructura_pago': 'pagoLibre',
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
