import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/mensaje_consejo.dart';
import '../../domain/repositories/chat_consejos_repository.dart';
import '../../domain/repositories/consejos_financieros_repository.dart'
    show LimiteDiarioConsejosError;
import '../../domain/usecases/dto/resumen_para_consejos.dart';

/// Adapter de `ChatConsejosRepository` (Fase 30) — reemplaza al flujo de un
/// solo turno de la Fase 24 (`ConsejosFinancierosRepository.generarConsejos`,
/// que llamaba a esta misma Edge Function con un contrato distinto).
///
/// `obtenerHistorial()` lee `mensajes_consejos` directo contra Supabase
/// (hay política de `SELECT` para el dueño de la fila) — la Edge Function
/// solo hace falta para escribir, porque esa tabla no tiene política de
/// `INSERT` para el cliente (ver el SQL del reporte de la Fase 30, mismo
/// criterio que `uso_consejos` desde la Fase 24). `enviarMensaje()` invoca
/// la Edge Function `generar-consejos`, que guarda tanto el mensaje del
/// usuario como la respuesta del asistente antes de responder con éxito.
class EdgeFunctionConsejosRepository implements ChatConsejosRepository {
  final SupabaseClient _client;

  EdgeFunctionConsejosRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  @override
  Future<List<MensajeConsejo>> obtenerHistorial() async {
    final filas = await _client
        .from('mensajes_consejos')
        .select()
        .eq('user_id', _userId)
        .order('created_at');
    return filas.map(aDominio).toList();
  }

  @override
  Future<void> enviarMensaje({
    required String mensaje,
    bool esPrimerMensaje = false,
    ResumenParaConsejos? resumen,
  }) async {
    final FunctionResponse respuesta;
    try {
      respuesta = await _client.functions.invoke(
        'generar-consejos',
        body: {
          'mensaje': mensaje,
          'esPrimerMensaje': esPrimerMensaje,
          if (resumen != null) 'resumen': _resumenAJson(resumen),
        },
      );
    } on FunctionsHttpException catch (error) {
      if (error.status == 429) {
        throw LimiteDiarioConsejosError();
      }
      debugPrint('EdgeFunctionConsejosRepository: ${error.details}');
      throw StateError(
        'No se pudo enviar tu mensaje en este momento. Intenta de nuevo '
        'más tarde.',
      );
    } on FunctionException catch (error) {
      debugPrint('EdgeFunctionConsejosRepository: ${error.details}');
      throw StateError(
        'No se pudo conectar con el servicio de consejos. Revisa tu '
        'conexión a internet e intenta de nuevo.',
      );
    } catch (error) {
      debugPrint('EdgeFunctionConsejosRepository: $error');
      throw StateError(
        'No se pudo enviar tu mensaje en este momento. Intenta de nuevo '
        'más tarde.',
      );
    }

    final data = respuesta.data;
    final texto = data is Map ? data['respuesta'] : null;
    if (texto is! String || texto.trim().isEmpty) {
      throw StateError('No se pudo interpretar la respuesta del servidor.');
    }
  }

  Map<String, dynamic> _resumenAJson(ResumenParaConsejos resumen) {
    return {
      'deudasActivas': [
        for (final deuda in resumen.deudasActivas)
          {
            'tipoDeuda': deuda.tipoDeuda.name,
            'montoTotal': deuda.montoTotal,
            'montoPagado': deuda.montoPagado,
            'interesTotal': deuda.interesTotal,
            'moneda': deuda.moneda.name,
          },
      ],
      'ingresosPorCategoriaMes': _categoriasAJson(
        resumen.ingresosPorCategoriaMes,
      ),
      'gastosPorCategoriaMes': _categoriasAJson(resumen.gastosPorCategoriaMes),
      'saldoTotalPorMoneda': {
        for (final entry in resumen.saldoTotalPorMoneda.entries)
          entry.key.name: entry.value,
      },
      'tarjetasCredito': [
        for (final tarjeta in resumen.tarjetasCredito)
          {
            'montoUsado': tarjeta.montoUsado,
            'lineaTotal': tarjeta.lineaTotal,
            'creditoDisponible': tarjeta.creditoDisponible,
            'moneda': tarjeta.moneda.name,
          },
      ],
    };
  }

  List<Map<String, dynamic>> _categoriasAJson(
    List<CategoriaMontoConsejo> categorias,
  ) {
    return [
      for (final c in categorias)
        {
          'categoriaNombre': c.categoriaNombre,
          'monto': c.monto,
          'moneda': c.moneda.name,
        },
    ];
  }

  /// Público solo para poder testear el mapeo de columnas sin red real.
  @visibleForTesting
  MensajeConsejo aDominio(Map<String, dynamic> fila) {
    return MensajeConsejo(
      id: fila['id'] as String,
      rol: RolMensajeConsejo.values.byName(fila['rol'] as String),
      contenido: fila['contenido'] as String,
      fecha: DateTime.parse(fila['created_at'] as String),
    );
  }
}
