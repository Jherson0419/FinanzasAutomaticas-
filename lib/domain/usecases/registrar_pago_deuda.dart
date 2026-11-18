import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import '../abono_capital.dart';
import '../costo_deuda.dart';
import '../cronograma_cuotas.dart';
import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../entities/pago_deuda.dart';
import '../repositories/amistad_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../saldo_deuda.dart';

class RegistrarPagoDeuda {
  final PagoDeudaRepository _pagoDeudaRepository;
  final DeudaRepository _deudaRepository;
  final CuentaRepository _cuentaRepository;
  final AmistadRepository _amistadRepository;
  final Uuid _uuid;

  RegistrarPagoDeuda({
    required PagoDeudaRepository pagoDeudaRepository,
    required DeudaRepository deudaRepository,
    required CuentaRepository cuentaRepository,
    required AmistadRepository amistadRepository,
    Uuid? uuid,
  }) : _pagoDeudaRepository = pagoDeudaRepository,
       _deudaRepository = deudaRepository,
       _cuentaRepository = cuentaRepository,
       _amistadRepository = amistadRepository,
       _uuid = uuid ?? const Uuid();

  /// Si [cuentaId] es `null`, el pago se trata como retroactivo: ya ocurrió
  /// antes y no debe descontarse de ninguna cuenta ni validarse contra su
  /// moneda.
  Future<PagoDeuda> call({
    required String deudaId,
    String? cuentaId,
    required double montoPagado,
    double? montoCapital,
    double? montoInteres,
    int? numeroCuota,
    DateTime? fechaPago,
    TipoPagoDeuda tipo = TipoPagoDeuda.cuota,
    int? cuotasRestantesSegunBanco,
    double? montoUltimaCuotaSegunBanco,
  }) async {
    final deuda = await _deudaRepository.obtenerPorId(deudaId);
    if (deuda == null) {
      throw ArgumentError('La deuda $deudaId no existe');
    }
    if (deuda.estado == EstadoDeuda.pagada) {
      throw StateError('La deuda "${deuda.nombreDeuda}" ya está pagada');
    }
    if (deuda.cuentaId != null) {
      throw StateError(
        'Esta deuda se actualiza automáticamente desde los movimientos de '
        'la tarjeta, no se registra un pago aquí.',
      );
    }

    final esAbono = tipo == TipoPagoDeuda.abonoCapital;
    EstimacionAbono? estimacion;
    if (esAbono) {
      estimacion = _validarAbono(
        deuda,
        monto: montoPagado,
        numeroCuota: numeroCuota,
        cuotasRestantesSegunBanco: cuotasRestantesSegunBanco,
        montoUltimaCuotaSegunBanco: montoUltimaCuotaSegunBanco,
      );
    } else if (cuotasRestantesSegunBanco != null ||
        montoUltimaCuotaSegunBanco != null) {
      throw ArgumentError(
        'Los datos "según tu banco" solo aplican a un abono a capital',
      );
    }

    // Pago secuencial obligatorio (Fase 58): solo aplica a `cuotasFijas` con
    // un `numeroCuota` explícito y no retroactivo — un pago retroactivo
    // (`cuentaId == null`) existe justamente para registrar historial pasado
    // que pudo quedar desordenado, y `pagoLibre` no tiene cuotas numeradas.
    // Fase 84: un abono a capital no es una cuota, queda fuera de la regla.
    if (!esAbono &&
        deuda.estructuraPago == EstructuraPago.cuotasFijas &&
        cuentaId != null &&
        numeroCuota != null) {
      final pagosExistentes = await _pagoDeudaRepository.obtenerPorDeuda(
        deudaId,
      );
      final cronogramaActual = generarCronogramaCuotas(deuda, pagosExistentes);
      for (final cuotaProgramada in cronogramaActual) {
        if (cuotaProgramada.numero >= numeroCuota) break;
        if (!cuotaProgramada.pagada) {
          throw StateError(
            'Debes pagar primero la cuota ${cuotaProgramada.numero} antes '
            'de esta',
          );
        }
      }
    }

    var cuenta = cuentaId == null
        ? null
        : await _cuentaRepository.obtenerPorId(cuentaId);
    if (cuentaId != null) {
      if (cuenta == null) {
        throw ArgumentError('La cuenta $cuentaId no existe');
      }
      // Fase 83: un cobro entra a una cuenta de fondos, nunca a una tarjeta
      // de crédito (la pantalla ya no la ofrece; esto lo garantiza).
      if (deuda.meDeben && cuenta.tipo == TipoCuenta.credito) {
        throw StateError(
          'Un cobro no se puede recibir en una tarjeta de crédito. Elige '
          'una cuenta de débito, efectivo o billetera.',
        );
      }
      if (cuenta.moneda != deuda.moneda) {
        throw StateError(
          'La cuenta está en ${cuenta.moneda.name.toUpperCase()} pero la deuda '
          'está en ${deuda.moneda.name.toUpperCase()} — no se puede registrar '
          'el pago',
        );
      }
    }

    final pago = PagoDeuda(
      id: _uuid.v4(),
      deudaId: deudaId,
      cuentaId: cuentaId,
      montoPagado: montoPagado,
      montoCapital: montoCapital,
      montoInteres: montoInteres,
      fechaPago: fechaPago ?? DateTime.now(),
      // Fase 84: un abono no corresponde a ninguna cuota.
      numeroCuota: esAbono ? null : numeroCuota,
      tipo: tipo,
    );

    await _pagoDeudaRepository.crear(pago);

    final nuevoMontoPagado = deuda.montoPagado + montoPagado;
    final esCuotasFijas = deuda.estructuraPago == EstructuraPago.cuotasFijas;

    // Fase 84: un abono no suma una cuota pagada; recorta el total de
    // cuotas (estimación, o lo que diga el banco) y acumula lo abonado.
    var base = deuda;
    if (esAbono) {
      final pagadas = deuda.numeroCuotasPagadas ?? 0;
      final est = estimacion!;
      final restantes =
          cuotasRestantesSegunBanco ?? est.cuotasRestantesDespues;
      final nuevoTotalCuotas = pagadas + restantes;
      final abonado = deuda.montoAbonadoCapital + montoPagado;
      // Fase 84b — última cuota: lo que diga el banco manda; si no, la
      // estimación, salvo que el banco haya dado OTRO número de cuotas
      // (entonces no se adivina F: queda la cuota normal).
      final double? ultima;
      if (restantes == 0) {
        ultima = null;
      } else if (montoUltimaCuotaSegunBanco != null) {
        ultima =
            montoUltimaCuotaSegunBanco > est.cuota - toleranciaUltimaCuota
            ? null
            : montoUltimaCuotaSegunBanco;
      } else if (cuotasRestantesSegunBanco == null ||
          cuotasRestantesSegunBanco == est.cuotasRestantesDespues) {
        ultima = est.ultimaCuotaDespues;
      } else {
        ultima = null;
      }
      // Al PRIMER abono se congela la TEA (en %): con el nuevo número de
      // cuotas ya no se puede despejar (ver `tasaEfectivaAnual`). En los
      // siguientes, `null` en copyWith conserva la ya congelada. En cuotas
      // fijas `tasaInteres` siempre es `null` hasta aquí (`RegistrarDeuda`
      // y `EditarDeuda` no la guardan), así que no pisa nada del usuario.
      final esPrimerAbono = deuda.montoAbonadoCapital <= 0;
      final tea = esPrimerAbono ? tasaEfectivaAnual(deuda) : null;
      base = deuda.copyWith(
        numeroCuotasTotal: nuevoTotalCuotas,
        montoAbonadoCapital: abonado,
        tasaInteres: tea == null ? null : tea * 100,
        montoUltimaCuota: ultima,
        sinMontoUltimaCuota: ultima == null,
      );
      base = base.copyWith(interesTotal: totalAPagar(base) - deuda.montoTotal);
    }

    // Fase 79: contra `totalAPagar` (en cuotas fijas = cuota × número de
    // cuotas, capital + interés), no contra `montoTotal` (el capital) —
    // antes una deuda en cuotas con interés quedaba "pagada" con cuotas
    // pendientes.
    final seSaldo = estaSaldada(base, montoPagado: nuevoMontoPagado);

    DateTime? proximaFechaPago = deuda.proximaFechaPago;
    DateTime? fechaVencimientoFinal;
    if (esCuotasFijas) {
      final pagosActualizados = await _pagoDeudaRepository.obtenerPorDeuda(
        deudaId,
      );
      final cronograma = generarCronogramaCuotas(base, pagosActualizados);
      proximaFechaPago = proximaFechaPagoDesdeCronograma(cronograma);
      // Tras un abono la última cuota llega antes.
      if (esAbono) {
        fechaVencimientoFinal = fechaVencimientoFinalDesdeCronograma(
          cronograma,
        );
      }
    }

    // Fase 79: `copyWith` (ahora cubre todos los campos) en vez de
    // reconstruir `Deuda` a mano — la reconstrucción manual olvidaba
    // `amigoUsuarioId` y lo borraba en el primer pago.
    await _deudaRepository.actualizar(
      base.copyWith(
        montoPagado: nuevoMontoPagado,
        numeroCuotasPagadas: esCuotasFijas && !esAbono
            ? (deuda.numeroCuotasPagadas ?? 0) + 1
            : null,
        fechaVencimientoFinal: fechaVencimientoFinal,
        // Sin cuotas pendientes, `proximaFechaPago` pasa a `null`.
        proximaFechaPago: proximaFechaPago,
        sinProximaFechaPago: proximaFechaPago == null,
        // Si el pago salda la deuda, ya no tiene sentido que siga marcada
        // en mora — evita que quede "atascada" con enMora/diasMora viejos.
        enMora: seSaldo ? false : null,
        diasMora: seSaldo ? 0 : null,
        estado: seSaldo ? EstadoDeuda.pagada : null,
      ),
    );

    // Fase 82: en una deuda "me deben" este pago es un COBRO — el dinero
    // ENTRA a la cuenta elegida ("Recibir en"), en vez de salir. Sin cuenta
    // (cobro retroactivo) no se mueve ningún saldo, igual que un pago
    // retroactivo. La validación de moneda de arriba aplica igual.
    if (cuenta != null) {
      final saldo = deuda.meDeben
          ? cuenta.saldoActual + montoPagado
          : cuenta.saldoActual - montoPagado;
      await _cuentaRepository.actualizar(cuenta.copyWith(saldoActual: saldo));
    }

    // Fase 64: si la deuda está vinculada a un amigo de Finzo, se le avisa
    // del pago (RPC `notificar_pago_a_amigo`). El pago ya quedó guardado
    // arriba — si esta notificación falla (sin red, RPC caído, etc.) no
    // debe revertirlo ni propagarse como si el pago hubiera fallado, solo
    // se registra el error: es secundaria frente al pago en sí.
    //
    // Fase 82: SOLO si yo le debo al amigo. En un cobro ("me deben") el
    // mensaje del RPC diría que "pagó" quien en realidad recibe el dinero.
    if (deuda.amigoUsuarioId != null &&
        deuda.direccion == DireccionDeuda.debo) {
      try {
        await _amistadRepository.notificarPago(
          amigoUsuarioId: deuda.amigoUsuarioId!,
          monto: montoPagado,
          nombreDeuda: deuda.nombreDeuda,
        );
      } catch (error) {
        developer.log(
          'No se pudo notificar el pago al amigo: $error',
          name: 'RegistrarPagoDeuda',
        );
      }
    }

    return pago;
  }

  /// Fase 84 — reglas de un abono a capital. Devuelve la estimación de
  /// cuotas restantes (que [cuotasRestantesSegunBanco] puede reemplazar).
  EstimacionAbono _validarAbono(
    Deuda deuda, {
    required double monto,
    required int? numeroCuota,
    required int? cuotasRestantesSegunBanco,
    required double? montoUltimaCuotaSegunBanco,
  }) {
    if (deuda.estructuraPago != EstructuraPago.cuotasFijas) {
      throw StateError(
        'El abono a capital solo aplica a deudas en cuotas fijas. En una '
        'deuda de pago libre, registra el pago normal.',
      );
    }
    if (deuda.meDeben) {
      throw StateError(
        'Un abono a capital solo se registra en deudas que tú debes.',
      );
    }
    if (numeroCuota != null) {
      throw ArgumentError('Un abono a capital no corresponde a una cuota');
    }
    if (monto <= 0) {
      throw ArgumentError('El abono debe ser mayor a 0');
    }
    final estimacion = estimarAbonoCapital(deuda, monto);
    if (estimacion == null) {
      throw StateError(
        'A la deuda le faltan datos de cuotas (cuota o número de cuotas).',
      );
    }
    if (estimacion.cuotasRestantesAntes == 0) {
      throw StateError('Esta deuda ya no tiene cuotas pendientes.');
    }
    if (monto > saldoPendiente(deuda) + toleranciaSaldoDeuda) {
      throw StateError('El abono supera lo que falta pagar de la deuda.');
    }
    final banco = cuotasRestantesSegunBanco;
    if (banco != null &&
        (banco < 0 || banco > estimacion.cuotasRestantesAntes)) {
      throw ArgumentError(
        'Las cuotas que te quedan según tu banco deben estar entre 0 y '
        '${estimacion.cuotasRestantesAntes}.',
      );
    }
    final ultimaBanco = montoUltimaCuotaSegunBanco;
    if (ultimaBanco != null) {
      if (ultimaBanco <= 0 ||
          ultimaBanco > estimacion.cuota + toleranciaUltimaCuota) {
        throw ArgumentError(
          'La última cuota según tu banco debe ser mayor a 0 y no mayor a '
          'la cuota (${estimacion.cuota.toStringAsFixed(2)}).',
        );
      }
      final quedan = banco ?? estimacion.cuotasRestantesDespues;
      if (quedan == 0) {
        throw ArgumentError(
          'Si el abono salda la deuda, no queda una última cuota.',
        );
      }
    }
    return estimacion;
  }
}
