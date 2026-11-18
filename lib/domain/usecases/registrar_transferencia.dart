import 'package:uuid/uuid.dart';

import '../calculo_saldo.dart';
import '../entities/cuenta.dart';
import '../entities/transaccion.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/transaccion_repository.dart';
import 'sincronizar_deuda_tarjeta.dart';

/// Concepto por defecto de los dos movimientos de una transferencia sin
/// nota.
const conceptoTransferencia = 'Transferencia';

/// Una transferencia falló a mitad: [hechos] dice qué alcanzó a quedar
/// escrito (no hay transacción compartida entre repositorios). Las
/// validaciones corren todas ANTES de escribir, así que esto solo ocurre
/// por un fallo de escritura (p. ej. sin conexión).
class TransferenciaIncompleta implements Exception {
  final String transferenciaId;
  final List<String> hechos;
  final Object causa;

  const TransferenciaIncompleta({
    required this.transferenciaId,
    required this.hechos,
    required this.causa,
  });

  String get mensaje => hechos.isEmpty
      ? 'No se registró la transferencia: $causa'
      : 'La transferencia quedó a medias (${hechos.join('; ')}). Revisa '
            'tus movimientos y bórrala si hace falta. Detalle: $causa';

  @override
  String toString() => mensaje;
}

/// Fase 85 — mueve dinero entre dos cuentas propias SIN contar como ingreso
/// ni gasto. Se guarda como dos movimientos ligados por `transferenciaId`:
/// la salida (resta en origen) y la entrada (suma en destino). Si alguna de
/// las cuentas es de crédito, su deuda vinculada se sincroniza igual que
/// con cualquier movimiento (pagar la tarjeta baja la deuda).
class RegistrarTransferencia {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final SincronizarDeudaTarjeta _sincronizarDeudaTarjeta;
  final Uuid _uuid;

  RegistrarTransferencia({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required DeudaRepository deudaRepository,
    Uuid? uuid,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _sincronizarDeudaTarjeta = SincronizarDeudaTarjeta(
         deudaRepository: deudaRepository,
       ),
       _uuid = uuid ?? const Uuid();

  /// Devuelve `(salida, entrada)`.
  Future<(Transaccion, Transaccion)> call({
    required String origenId,
    required String destinoId,
    required double monto,
    DateTime? fecha,
    String? nota,
  }) async {
    // 1. Todo se valida antes de escribir nada.
    if (monto.isNaN || monto.isInfinite || monto <= 0) {
      throw ArgumentError('El monto debe ser mayor a 0');
    }
    if (origenId == destinoId) {
      throw ArgumentError('Elige dos cuentas distintas');
    }
    final origen = await _cuentaRepository.obtenerPorId(origenId);
    if (origen == null) throw ArgumentError('La cuenta $origenId no existe');
    final destino = await _cuentaRepository.obtenerPorId(destinoId);
    if (destino == null) {
      throw ArgumentError('La cuenta $destinoId no existe');
    }
    if (origen.moneda != destino.moneda) {
      throw StateError(
        'Las cuentas están en monedas distintas '
        '(${origen.moneda.name.toUpperCase()} y '
        '${destino.moneda.name.toUpperCase()}): no se puede transferir',
      );
    }

    final transferenciaId = _uuid.v4();
    final cuando = fecha ?? DateTime.now();
    final notaLimpia = nota?.trim() ?? '';
    Transaccion cara(Cuenta cuenta, TipoTransaccion tipo) => Transaccion(
      id: _uuid.v4(),
      cuentaId: cuenta.id,
      categoriaId: null,
      monto: monto,
      moneda: cuenta.moneda,
      tipo: tipo,
      concepto: notaLimpia.isEmpty ? conceptoTransferencia : notaLimpia,
      metodoPago: MetodoPago.transferencia,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.manual,
      fecha: cuando,
      transferenciaId: transferenciaId,
    );
    final salida = cara(origen, TipoTransaccion.transferenciaSalida);
    final entrada = cara(destino, TipoTransaccion.transferenciaEntrada);

    // 2. Escritura, paso a paso; si algo falla se informa qué quedó hecho.
    final hechos = <String>[];
    try {
      await _transaccionRepository.crear(salida);
      hechos.add('salida registrada en ${origen.nombre}');
      await _aplicar(origen, salida);
      hechos.add('saldo de ${origen.nombre} actualizado');
      await _transaccionRepository.crear(entrada);
      hechos.add('entrada registrada en ${destino.nombre}');
      await _aplicar(destino, entrada);
      hechos.add('saldo de ${destino.nombre} actualizado');
    } catch (e) {
      throw TransferenciaIncompleta(
        transferenciaId: transferenciaId,
        hechos: hechos,
        causa: e,
      );
    }
    return (salida, entrada);
  }

  Future<void> _aplicar(Cuenta cuenta, Transaccion t) async {
    final actualizada = cuenta.copyWith(
      saldoActual: aplicarEfectoTransaccion(cuenta.saldoActual, t.tipo, t.monto),
    );
    await _cuentaRepository.actualizar(actualizada);
    await _sincronizarDeudaTarjeta(actualizada);
  }
}

/// Fase 85 — borra los DOS movimientos de una transferencia y revierte los
/// dos saldos (sincronizando la deuda de una tarjeta, si la hay). Si la
/// transferencia había quedado a medias, borra la cara que exista.
class EliminarTransferencia {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final SincronizarDeudaTarjeta _sincronizarDeudaTarjeta;

  EliminarTransferencia({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required DeudaRepository deudaRepository,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _sincronizarDeudaTarjeta = SincronizarDeudaTarjeta(
         deudaRepository: deudaRepository,
       );

  Future<void> call({required String transferenciaId}) async {
    final caras = (await _transaccionRepository.obtenerTodas())
        .where((t) => t.transferenciaId == transferenciaId)
        .toList();
    if (caras.isEmpty) {
      throw ArgumentError('La transferencia $transferenciaId no existe');
    }
    // Validar antes de escribir: las cuentas deben existir.
    final cuentas = <String, Cuenta>{};
    for (final t in caras) {
      final cuenta = await _cuentaRepository.obtenerPorId(t.cuentaId);
      if (cuenta == null) {
        throw ArgumentError('La cuenta ${t.cuentaId} no existe');
      }
      cuentas[t.cuentaId] = cuenta;
    }
    for (final t in caras) {
      // Releer por si ambas caras fueran de la misma cuenta (no debería).
      final cuenta = await _cuentaRepository.obtenerPorId(t.cuentaId) ??
          cuentas[t.cuentaId]!;
      final actualizada = cuenta.copyWith(
        saldoActual: revertirEfectoTransaccion(
          cuenta.saldoActual,
          t.tipo,
          t.monto,
        ),
      );
      await _cuentaRepository.actualizar(actualizada);
      await _sincronizarDeudaTarjeta(actualizada);
      await _transaccionRepository.eliminar(t.id);
    }
  }
}
