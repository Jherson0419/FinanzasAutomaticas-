import '../abono_capital.dart';
import '../cronograma_cuotas.dart';
import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../entities/pago_deuda.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import 'registrar_pago_deuda.dart';

/// Un adelanto se cortó a la mitad: [registradas] de [solicitadas] cuotas
/// quedaron guardadas (cada una con su efecto en la deuda y la cuenta) y
/// el resto no. [causa] es el error de la primera que falló.
class AdelantoCuotasIncompleto implements Exception {
  final int registradas;
  final int solicitadas;
  final Object causa;

  const AdelantoCuotasIncompleto({
    required this.registradas,
    required this.solicitadas,
    required this.causa,
  });

  String get mensaje =>
      'Se registraron $registradas de $solicitadas cuotas. La siguiente '
      'falló: $causa';

  @override
  String toString() => mensaje;
}

/// Fase 84 — adelantar N cuotas = registrar N pagos de cuota consecutivos
/// (las siguientes pendientes del cronograma), cada uno por el monto de la
/// cuota. Reusa [RegistrarPagoDeuda] para que cada pago aplique las mismas
/// reglas (moneda, cuenta, estado, notificación al amigo).
///
/// Valida TODO antes de registrar el primero; si aun así uno falla a la
/// mitad (p. ej. sin red en Supabase), lanza [AdelantoCuotasIncompleto]
/// con cuántas quedaron registradas — no se deshacen (no hay transacción
/// entre repositorios, y cada pago ya es correcto por sí solo).
///
/// Si el banco cobra menos por adelantar, el usuario debe registrar el
/// monto real con un pago normal (lo avisa la pantalla).
class RegistrarAdelantoCuotas {
  final DeudaRepository _deudaRepository;
  final PagoDeudaRepository _pagoDeudaRepository;
  final CuentaRepository _cuentaRepository;
  final RegistrarPagoDeuda _registrarPago;

  RegistrarAdelantoCuotas({
    required DeudaRepository deudaRepository,
    required PagoDeudaRepository pagoDeudaRepository,
    required CuentaRepository cuentaRepository,
    required RegistrarPagoDeuda registrarPagoDeuda,
  }) : _deudaRepository = deudaRepository,
       _pagoDeudaRepository = pagoDeudaRepository,
       _cuentaRepository = cuentaRepository,
       _registrarPago = registrarPagoDeuda;

  Future<List<PagoDeuda>> call({
    required String deudaId,
    required int cantidad,
    String? cuentaId,
    DateTime? fechaPago,
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
    final cuota = deuda.montoCuota;
    if (deuda.estructuraPago != EstructuraPago.cuotasFijas || cuota == null) {
      throw StateError(
        'Adelantar cuotas solo aplica a deudas en cuotas fijas.',
      );
    }
    final restantes = cuotasRestantes(deuda);
    if (cantidad < 1 || cantidad > restantes) {
      throw ArgumentError(
        restantes == 0
            ? 'Esta deuda ya no tiene cuotas pendientes.'
            : 'Puedes adelantar entre 1 y $restantes cuotas.',
      );
    }
    final pendientes = generarCronogramaCuotas(
      deuda,
      await _pagoDeudaRepository.obtenerPorDeuda(deudaId),
    ).where((c) => !c.pagada).take(cantidad).toList();
    if (pendientes.length < cantidad) {
      throw StateError(
        'El cronograma solo tiene ${pendientes.length} cuotas pendientes.',
      );
    }
    if (cuentaId != null) {
      final cuenta = await _cuentaRepository.obtenerPorId(cuentaId);
      if (cuenta == null) {
        throw ArgumentError('La cuenta $cuentaId no existe');
      }
      if (deuda.meDeben && cuenta.tipo == TipoCuenta.credito) {
        throw StateError(
          'Un cobro no se puede recibir en una tarjeta de crédito.',
        );
      }
      if (cuenta.moneda != deuda.moneda) {
        throw StateError(
          'La cuenta está en ${cuenta.moneda.name.toUpperCase()} pero la '
          'deuda está en ${deuda.moneda.name.toUpperCase()}.',
        );
      }
    }

    final fecha = fechaPago ?? DateTime.now();
    final pagos = <PagoDeuda>[];
    for (final c in pendientes) {
      try {
        pagos.add(
          await _registrarPago(
            deudaId: deudaId,
            cuentaId: cuentaId,
            // Fase 84b: la última cuota puede ser menor (tras un abono).
            montoPagado: c.montoEsperado,
            numeroCuota: c.numero,
            fechaPago: fecha,
          ),
        );
      } catch (e) {
        throw AdelantoCuotasIncompleto(
          registradas: pagos.length,
          solicitadas: cantidad,
          causa: e is StateError
              ? e.message
              : (e is ArgumentError ? e.message : e),
        );
      }
    }
    return pagos;
  }
}
