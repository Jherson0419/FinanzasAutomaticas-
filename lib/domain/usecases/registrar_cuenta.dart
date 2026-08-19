import 'package:uuid/uuid.dart';

import '../entities/cuenta.dart';
import '../repositories/cuenta_repository.dart';
import '../validacion_cuenta_credito.dart';

class RegistrarCuenta {
  final CuentaRepository _cuentaRepository;
  final Uuid _uuid;

  RegistrarCuenta({required CuentaRepository cuentaRepository, Uuid? uuid})
    : _cuentaRepository = cuentaRepository,
      _uuid = uuid ?? const Uuid();

  Future<Cuenta> call({
    required String nombre,
    required TipoCuenta tipo,
    required Moneda moneda,
    double saldoInicial = 0,
    double? lineaCredito,
    int? diaCorte,
    int? diaPago,
  }) async {
    validarCamposDeCredito(
      tipo: tipo,
      lineaCredito: lineaCredito,
      diaCorte: diaCorte,
      diaPago: diaPago,
    );

    final cuenta = Cuenta(
      id: _uuid.v4(),
      nombre: nombre,
      tipo: tipo,
      moneda: moneda,
      saldoActual: saldoInicial,
      lineaCredito: lineaCredito,
      diaCorte: diaCorte,
      diaPago: diaPago,
    );

    await _cuentaRepository.crear(cuenta);
    return cuenta;
  }
}
