import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/pago_deuda.dart';
import '../../../domain/repositories/pago_deuda_repository.dart';
import 'supabase_errores.dart';

/// Adapter de `PagoDeudaRepository` sobre la tabla `pagos_deuda` de
/// Supabase (Fase 21). Sin `actualizar`/`eliminar`: el puerto tampoco los
/// define — un pago, una vez registrado, no se edita ni se borra desde la
/// app (igual que en el adapter Drift).
class PagoDeudaRepositorySupabase implements PagoDeudaRepository {
  final SupabaseClient _client;

  PagoDeudaRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<PagoDeuda>> obtenerPorDeuda(String deudaId) {
    return conManejoDeErroresSupabase('pagos_deuda.obtenerPorDeuda', () async {
      final filas = await _client
          .from('pagos_deuda')
          .select()
          .eq('user_id', _userId)
          .eq('deuda_id', deudaId);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<List<PagoDeuda>> obtenerPorCuenta(String cuentaId) {
    return conManejoDeErroresSupabase('pagos_deuda.obtenerPorCuenta', () async {
      final filas = await _client
          .from('pagos_deuda')
          .select()
          .eq('user_id', _userId)
          .eq('cuenta_id', cuentaId);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<void> crear(PagoDeuda pago) {
    return conManejoDeErroresSupabase('pagos_deuda.crear', () async {
      await _client.from('pagos_deuda').insert(aFila(pago));
    });
  }

  @override
  Future<void> eliminar(String id) {
    return conManejoDeErroresSupabase('pagos_deuda.eliminar', () async {
      await _client
          .from('pagos_deuda')
          .delete()
          .eq('user_id', _userId)
          .eq('id', id);
    });
  }

  @visibleForTesting
  Map<String, dynamic> aFila(PagoDeuda pago) {
    return {
      'id': pago.id,
      'user_id': _userId,
      'deuda_id': pago.deudaId,
      'cuenta_id': pago.cuentaId,
      'monto_pagado': pago.montoPagado,
      'monto_capital': pago.montoCapital,
      'monto_interes': pago.montoInteres,
      'fecha_pago': pago.fechaPago.toIso8601String(),
      'numero_cuota': pago.numeroCuota,
    };
  }

  @visibleForTesting
  PagoDeuda aDominio(Map<String, dynamic> fila) {
    return PagoDeuda(
      id: fila['id'] as String,
      deudaId: fila['deuda_id'] as String,
      cuentaId: fila['cuenta_id'] as String?,
      montoPagado: (fila['monto_pagado'] as num).toDouble(),
      montoCapital: (fila['monto_capital'] as num?)?.toDouble(),
      montoInteres: (fila['monto_interes'] as num?)?.toDouble(),
      fechaPago: DateTime.parse(fila['fecha_pago'] as String),
      numeroCuota: fila['numero_cuota'] as int?,
    );
  }
}
