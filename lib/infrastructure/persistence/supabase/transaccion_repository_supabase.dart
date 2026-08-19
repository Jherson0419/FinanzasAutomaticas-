import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/transaccion.dart';
import '../../../domain/repositories/transaccion_repository.dart';
import 'enum_mapeo_supabase.dart';
import 'supabase_errores.dart';

/// Adapter de `TransaccionRepository` sobre la tabla `transacciones` de
/// Supabase (Fase 21).
class TransaccionRepositorySupabase implements TransaccionRepository {
  final SupabaseClient _client;

  TransaccionRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Transaccion>> obtenerTodas() {
    return conManejoDeErroresSupabase('transacciones.obtenerTodas', () async {
      final filas = await _client
          .from('transacciones')
          .select()
          .eq('user_id', _userId);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<Transaccion?> obtenerPorId(String id) {
    return conManejoDeErroresSupabase('transacciones.obtenerPorId', () async {
      final fila = await _client
          .from('transacciones')
          .select()
          .eq('user_id', _userId)
          .eq('id', id)
          .maybeSingle();
      return fila == null ? null : aDominio(fila);
    });
  }

  @override
  Future<List<Transaccion>> obtenerPorCuenta(String cuentaId) {
    return conManejoDeErroresSupabase(
      'transacciones.obtenerPorCuenta',
      () async {
        final filas = await _client
            .from('transacciones')
            .select()
            .eq('user_id', _userId)
            .eq('cuenta_id', cuentaId);
        return filas.map(aDominio).toList();
      },
    );
  }

  @override
  Future<List<Transaccion>> obtenerPorCategoria(String categoriaId) {
    return conManejoDeErroresSupabase(
      'transacciones.obtenerPorCategoria',
      () async {
        final filas = await _client
            .from('transacciones')
            .select()
            .eq('user_id', _userId)
            .eq('categoria_id', categoriaId);
        return filas.map(aDominio).toList();
      },
    );
  }

  @override
  Future<List<Transaccion>> obtenerPorRangoFecha(
    DateTime desde,
    DateTime hasta,
  ) {
    return conManejoDeErroresSupabase(
      'transacciones.obtenerPorRangoFecha',
      () async {
        final filas = await _client
            .from('transacciones')
            .select()
            .eq('user_id', _userId)
            .gte('fecha', desde.toIso8601String())
            .lte('fecha', hasta.toIso8601String());
        return filas.map(aDominio).toList();
      },
    );
  }

  @override
  Future<List<Transaccion>> obtenerRecientes(int limite) {
    return conManejoDeErroresSupabase(
      'transacciones.obtenerRecientes',
      () async {
        final filas = await _client
            .from('transacciones')
            .select()
            .eq('user_id', _userId)
            .order('fecha', ascending: false)
            .limit(limite);
        return filas.map(aDominio).toList();
      },
    );
  }

  @override
  Future<void> crear(Transaccion transaccion) {
    return conManejoDeErroresSupabase('transacciones.crear', () async {
      await _client.from('transacciones').insert(aFila(transaccion));
    });
  }

  @override
  Future<void> actualizar(Transaccion transaccion) {
    return conManejoDeErroresSupabase('transacciones.actualizar', () async {
      await _client
          .from('transacciones')
          .update(aFila(transaccion))
          .eq('user_id', _userId)
          .eq('id', transaccion.id);
    });
  }

  @override
  Future<void> eliminar(String id) {
    return conManejoDeErroresSupabase('transacciones.eliminar', () async {
      await _client
          .from('transacciones')
          .delete()
          .eq('user_id', _userId)
          .eq('id', id);
    });
  }

  @visibleForTesting
  Map<String, dynamic> aFila(Transaccion transaccion) {
    return {
      'id': transaccion.id,
      'user_id': _userId,
      'cuenta_id': transaccion.cuentaId,
      'categoria_id': transaccion.categoriaId,
      'monto': transaccion.monto,
      'moneda': monedaAFila(transaccion.moneda),
      'tipo': tipoTransaccionAFila(transaccion.tipo),
      'concepto': transaccion.concepto,
      'metodo_pago': metodoPagoAFila(transaccion.metodoPago),
      'es_recurrente': transaccion.esRecurrente,
      'comprobante_url': transaccion.comprobanteUrl,
      'fuente_captura': fuenteCapturaAFila(transaccion.fuenteCaptura),
      'data_raw': transaccion.dataRaw,
      'fecha': transaccion.fecha.toIso8601String(),
    };
  }

  @visibleForTesting
  Transaccion aDominio(Map<String, dynamic> fila) {
    return Transaccion(
      id: fila['id'] as String,
      cuentaId: fila['cuenta_id'] as String,
      categoriaId: fila['categoria_id'] as String,
      monto: (fila['monto'] as num).toDouble(),
      moneda: monedaDeFila(fila['moneda'] as String),
      tipo: tipoTransaccionDeFila(fila['tipo'] as String),
      concepto: fila['concepto'] as String,
      metodoPago: metodoPagoDeFila(fila['metodo_pago'] as String),
      esRecurrente: fila['es_recurrente'] as bool,
      comprobanteUrl: fila['comprobante_url'] as String?,
      fuenteCaptura: fuenteCapturaDeFila(fila['fuente_captura'] as String),
      dataRaw: fila['data_raw'] as String?,
      fecha: DateTime.parse(fila['fecha'] as String),
    );
  }
}
