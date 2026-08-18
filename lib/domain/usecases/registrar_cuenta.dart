import 'package:uuid/uuid.dart';

import '../entities/cuenta.dart';
import '../repositories/cuenta_repository.dart';

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
  }) async {
    final cuenta = Cuenta(
      id: _uuid.v4(),
      nombre: nombre,
      tipo: tipo,
      moneda: moneda,
      saldoActual: saldoInicial,
    );

    await _cuentaRepository.crear(cuenta);
    return cuenta;
  }
}
