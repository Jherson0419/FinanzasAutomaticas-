import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/entities/notificacion.dart';
import '../../../domain/repositories/notificacion_repository.dart';
import '../../../domain/usecases/dto/notificacion_vencimiento_pendiente.dart';
import 'modo_local.dart';

/// Resuelve el nombre de una deuda para armar el texto de la notificación.
typedef NombreDeudaPorId = Future<String?> Function(String deudaId);

/// `NotificacionRepository` del modo local (Fase 78), persistido como una
/// lista JSON en `SharedPreferences`.
///
/// Replica lo que en la nube hace el RPC `generar_notificaciones_vencimiento`:
/// nunca duplica una notificación con el mismo `deuda_id`+`fecha`+`tipo`
/// dentro de `data`. El resto de tipos (`solicitud_aceptada`,
/// `pago_deuda_amigo`, `gasto_tarjeta`…) los crean triggers de Postgres, así
/// que en modo local simplemente no aparecen.
class NotificacionRepositoryLocal implements NotificacionRepository {
  static const clave = '${prefijoModoLocal}notificaciones';

  final SharedPreferences _prefs;
  final NombreDeudaPorId? _nombreDeuda;
  final Uuid _uuid;
  final DateTime Function() _ahora;

  NotificacionRepositoryLocal(
    this._prefs, {
    NombreDeudaPorId? nombreDeuda,
    Uuid? uuid,
    DateTime Function()? ahora,
  }) : _nombreDeuda = nombreDeuda,
       _uuid = uuid ?? const Uuid(),
       _ahora = ahora ?? DateTime.now;

  @override
  Future<List<Notificacion>> obtenerTodas() async {
    final todas = _leer().map(_aDominio).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return todas;
  }

  @override
  Future<void> marcarLeida(String id) async {
    final filas = _leer();
    for (final fila in filas) {
      if (fila['id'] == id) fila['leida'] = true;
    }
    await _escribir(filas);
  }

  @override
  Future<void> generarNotificacionesVencimiento(
    List<NotificacionVencimientoPendiente> items,
  ) async {
    if (items.isEmpty) return;
    final filas = _leer();
    final existentes = {
      for (final fila in filas)
        if (fila['data'] case final Map<String, dynamic> data)
          _claveDedupe(data['deuda_id'], data['fecha'], fila['tipo']),
    };

    for (final item in items) {
      final fecha = _fechaIso(item.fecha);
      final claveItem = _claveDedupe(item.deudaId, fecha, item.tipo);
      if (!existentes.add(claveItem)) continue;

      final nombre = await _nombreDeuda?.call(item.deudaId);
      filas.add({
        'id': _uuid.v4(),
        'tipo': item.tipo,
        'mensaje': _mensaje(item.tipo, nombre),
        'data': {'deuda_id': item.deudaId, 'fecha': fecha, 'tipo': item.tipo},
        'leida': false,
        'created_at': _ahora().toIso8601String(),
      });
    }
    await _escribir(filas);
  }

  String _mensaje(String tipo, String? nombreDeuda) {
    final deuda = nombreDeuda == null ? 'una deuda' : '"$nombreDeuda"';
    return switch (tipo) {
      'cuota_vencida' => 'Tienes una cuota vencida de $deuda',
      'cuota_por_vencer' => 'Se acerca el vencimiento de una cuota de $deuda',
      _ => 'Tienes una notificación de $deuda',
    };
  }

  String _claveDedupe(Object? deudaId, Object? fecha, Object? tipo) =>
      '$deudaId|$fecha|$tipo';

  String _fechaIso(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';

  List<Map<String, dynamic>> _leer() {
    final crudo = _prefs.getString(clave);
    if (crudo == null) return [];
    return (jsonDecode(crudo) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _escribir(List<Map<String, dynamic>> filas) =>
      _prefs.setString(clave, jsonEncode(filas));

  Notificacion _aDominio(Map<String, dynamic> fila) => Notificacion(
    id: fila['id'] as String,
    tipo: fila['tipo'] as String,
    mensaje: fila['mensaje'] as String,
    data: fila['data'] as Map<String, dynamic>?,
    leida: fila['leida'] as bool,
    createdAt: DateTime.parse(fila['created_at'] as String),
  );
}
