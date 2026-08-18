import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/cuenta.dart';
import '../../../domain/repositories/cuenta_repository.dart';
import 'supabase_errores.dart';

/// Adapter de `CuentaRepository` sobre la tabla `cuentas` de Supabase
/// (Fase 21). Columnas snake_case de `schema_finanzas_v3.sql`, mapeadas
/// 1:1 a los campos camelCase de [Cuenta]. Cada consulta filtra
/// explícitamente por `user_id` además de confiar en RLS — defensa en
/// profundidad, no porque RLS no alcance.
class CuentaRepositorySupabase implements CuentaRepository {
  final SupabaseClient _client;

  CuentaRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Cuenta>> obtenerTodas() {
    return conManejoDeErroresSupabase('cuentas.obtenerTodas', () async {
      final filas = await _client
          .from('cuentas')
          .select()
          .eq('user_id', _userId);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<Cuenta?> obtenerPorId(String id) {
    return conManejoDeErroresSupabase('cuentas.obtenerPorId', () async {
      final fila = await _client
          .from('cuentas')
          .select()
          .eq('user_id', _userId)
          .eq('id', id)
          .maybeSingle();
      return fila == null ? null : aDominio(fila);
    });
  }

  @override
  Future<void> crear(Cuenta cuenta) {
    return conManejoDeErroresSupabase('cuentas.crear', () async {
      await _client.from('cuentas').insert(aFila(cuenta));
    });
  }

  @override
  Future<void> actualizar(Cuenta cuenta) {
    return conManejoDeErroresSupabase('cuentas.actualizar', () async {
      await _client
          .from('cuentas')
          .update(aFila(cuenta))
          .eq('user_id', _userId)
          .eq('id', cuenta.id);
    });
  }

  @override
  Future<void> eliminar(String id) {
    return conManejoDeErroresSupabase('cuentas.eliminar', () async {
      await _client
          .from('cuentas')
          .delete()
          .eq('user_id', _userId)
          .eq('id', id);
    });
  }

  /// Público solo para poder testear el mapeo de columnas sin red real.
  @visibleForTesting
  Map<String, dynamic> aFila(Cuenta cuenta) {
    return {
      'id': cuenta.id,
      'user_id': _userId,
      'nombre': cuenta.nombre,
      'tipo': cuenta.tipo.name,
      'moneda': cuenta.moneda.name,
      'saldo_actual': cuenta.saldoActual,
    };
  }

  @visibleForTesting
  Cuenta aDominio(Map<String, dynamic> fila) {
    return Cuenta(
      id: fila['id'] as String,
      nombre: fila['nombre'] as String,
      tipo: TipoCuenta.values.byName(fila['tipo'] as String),
      moneda: Moneda.values.byName(fila['moneda'] as String),
      saldoActual: (fila['saldo_actual'] as num).toDouble(),
    );
  }
}
