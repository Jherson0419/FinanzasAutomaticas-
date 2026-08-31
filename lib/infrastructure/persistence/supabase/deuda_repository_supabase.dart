import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/entities/deuda.dart';
import '../../../domain/repositories/deuda_repository.dart';
import 'enum_mapeo_supabase.dart';
import 'supabase_errores.dart';

/// Adapter de `DeudaRepository` sobre la tabla `deudas` de Supabase
/// (Fase 21).
class DeudaRepositorySupabase implements DeudaRepository {
  final SupabaseClient _client;

  DeudaRepositorySupabase(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<Deuda>> obtenerTodas() {
    return conManejoDeErroresSupabase('deudas.obtenerTodas', () async {
      final filas = await _client
          .from('deudas')
          .select()
          .eq('user_id', _userId);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<List<Deuda>> obtenerActivas() {
    return conManejoDeErroresSupabase('deudas.obtenerActivas', () async {
      final filas = await _client
          .from('deudas')
          .select()
          .eq('user_id', _userId)
          .inFilter('estado', [
            estadoDeudaAFila(EstadoDeuda.activa),
            estadoDeudaAFila(EstadoDeuda.enMora),
          ]);
      return filas.map(aDominio).toList();
    });
  }

  @override
  Future<Deuda?> obtenerPorId(String id) {
    return conManejoDeErroresSupabase('deudas.obtenerPorId', () async {
      final fila = await _client
          .from('deudas')
          .select()
          .eq('user_id', _userId)
          .eq('id', id)
          .maybeSingle();
      return fila == null ? null : aDominio(fila);
    });
  }

  @override
  Future<void> crear(Deuda deuda) {
    return conManejoDeErroresSupabase('deudas.crear', () async {
      await _client.from('deudas').insert(aFila(deuda));
    });
  }

  @override
  Future<void> actualizar(Deuda deuda) {
    return conManejoDeErroresSupabase('deudas.actualizar', () async {
      await _client
          .from('deudas')
          .update(aFila(deuda))
          .eq('user_id', _userId)
          .eq('id', deuda.id);
    });
  }

  @override
  Future<void> eliminar(String id) {
    return conManejoDeErroresSupabase('deudas.eliminar', () async {
      await _client.from('deudas').delete().eq('user_id', _userId).eq('id', id);
    });
  }

  /// Fase 68 — RLS de `deudas` deja leer filas ajenas cuando
  /// `amigo_usuario_id = auth.uid()` (política nueva, SQL en el reporte de
  /// esta fase); esta consulta pide solo las columnas que "Te deben"
  /// necesita, nunca la fila completa de una deuda que no es mía.
  @override
  Future<List<DeudaDeAmigo>> obtenerDeudasDondeSoyElAmigo() {
    return conManejoDeErroresSupabase(
      'deudas.obtenerDeudasDondeSoyElAmigo',
      () async {
        final filas = await _client
            .from('deudas')
            .select('id, user_id, nombre_deuda, monto_total, monto_pagado, moneda')
            .eq('amigo_usuario_id', _userId);
        return filas.map(aDominioDeudaDeAmigo).toList();
      },
    );
  }

  @visibleForTesting
  DeudaDeAmigo aDominioDeudaDeAmigo(Map<String, dynamic> fila) {
    return DeudaDeAmigo(
      id: fila['id'] as String,
      deudorUsuarioId: fila['user_id'] as String,
      nombreDeuda: fila['nombre_deuda'] as String,
      montoAdeudado:
          (fila['monto_total'] as num).toDouble() -
          (fila['monto_pagado'] as num).toDouble(),
      moneda: monedaDeFila(fila['moneda'] as String),
    );
  }

  @visibleForTesting
  Map<String, dynamic> aFila(Deuda deuda) {
    return {
      'id': deuda.id,
      'user_id': _userId,
      'nombre_deuda': deuda.nombreDeuda,
      'tipo_deuda': tipoDeudaAFila(deuda.tipoDeuda),
      'tipo_acreedor': tipoAcreedorAFila(deuda.tipoAcreedor),
      'nombre_acreedor': deuda.nombreAcreedor,
      'moneda': monedaAFila(deuda.moneda),
      'monto_total': deuda.montoTotal,
      'monto_pagado': deuda.montoPagado,
      'tiene_interes': deuda.tieneInteres,
      'tasa_interes': deuda.tasaInteres,
      'tipo_tasa': deuda.tipoTasa == null
          ? null
          : tipoTasaAFila(deuda.tipoTasa!),
      'estructura_pago': estructuraPagoAFila(deuda.estructuraPago),
      'numero_cuotas_total': deuda.numeroCuotasTotal,
      'numero_cuotas_pagadas': deuda.numeroCuotasPagadas,
      'monto_cuota': deuda.montoCuota,
      'pago_minimo': deuda.pagoMinimo,
      'periodicidad_cuotas': deuda.periodicidadCuotas == null
          ? null
          : periodicidadCuotaAFila(deuda.periodicidadCuotas!),
      'interes_total': deuda.interesTotal,
      'fecha_inicio': deuda.fechaInicio.toIso8601String(),
      'fecha_vencimiento_final': deuda.fechaVencimientoFinal?.toIso8601String(),
      'dia_pago': deuda.diaPago,
      'proxima_fecha_pago': deuda.proximaFechaPago?.toIso8601String(),
      'en_mora': deuda.enMora,
      'dias_mora': deuda.diasMora,
      'tasa_interes_moratorio': deuda.tasaInteresMoratorio,
      'estado': estadoDeudaAFila(deuda.estado),
      'notas': deuda.notas,
      'cuenta_id': deuda.cuentaId,
      'amigo_usuario_id': deuda.amigoUsuarioId,
    };
  }

  @visibleForTesting
  Deuda aDominio(Map<String, dynamic> fila) {
    return Deuda(
      id: fila['id'] as String,
      nombreDeuda: fila['nombre_deuda'] as String,
      tipoDeuda: tipoDeudaDeFila(fila['tipo_deuda'] as String),
      tipoAcreedor: tipoAcreedorDeFila(fila['tipo_acreedor'] as String),
      nombreAcreedor: fila['nombre_acreedor'] as String,
      moneda: monedaDeFila(fila['moneda'] as String),
      montoTotal: (fila['monto_total'] as num).toDouble(),
      montoPagado: (fila['monto_pagado'] as num).toDouble(),
      tieneInteres: fila['tiene_interes'] as bool,
      tasaInteres: (fila['tasa_interes'] as num?)?.toDouble(),
      tipoTasa: fila['tipo_tasa'] == null
          ? null
          : tipoTasaDeFila(fila['tipo_tasa'] as String),
      estructuraPago: estructuraPagoDeFila(fila['estructura_pago'] as String),
      numeroCuotasTotal: fila['numero_cuotas_total'] as int?,
      numeroCuotasPagadas: fila['numero_cuotas_pagadas'] as int?,
      montoCuota: (fila['monto_cuota'] as num?)?.toDouble(),
      pagoMinimo: (fila['pago_minimo'] as num?)?.toDouble(),
      periodicidadCuotas: fila['periodicidad_cuotas'] == null
          ? null
          : periodicidadCuotaDeFila(fila['periodicidad_cuotas'] as String),
      interesTotal: (fila['interes_total'] as num?)?.toDouble(),
      fechaInicio: DateTime.parse(fila['fecha_inicio'] as String),
      fechaVencimientoFinal: fila['fecha_vencimiento_final'] == null
          ? null
          : DateTime.parse(fila['fecha_vencimiento_final'] as String),
      diaPago: fila['dia_pago'] as int?,
      proximaFechaPago: fila['proxima_fecha_pago'] == null
          ? null
          : DateTime.parse(fila['proxima_fecha_pago'] as String),
      enMora: fila['en_mora'] as bool,
      diasMora: fila['dias_mora'] as int?,
      tasaInteresMoratorio: (fila['tasa_interes_moratorio'] as num?)
          ?.toDouble(),
      estado: estadoDeudaDeFila(fila['estado'] as String),
      notas: fila['notas'] as String?,
      cuentaId: fila['cuenta_id'] as String?,
      amigoUsuarioId: fila['amigo_usuario_id'] as String?,
    );
  }
}
