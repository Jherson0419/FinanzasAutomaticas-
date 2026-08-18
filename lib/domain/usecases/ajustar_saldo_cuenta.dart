import 'package:uuid/uuid.dart';

import '../calculo_saldo.dart';
import '../entities/categoria.dart';
import '../entities/transaccion.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/transaccion_repository.dart';

/// Nombre de las categorías "Ajuste de saldo" (ingreso y gasto) sembradas
/// por `AppDatabase` — ver `_seedCategoriasAjuste`.
const nombreCategoriaAjusteSaldo = 'Ajuste de saldo';

/// Ajusta `Cuenta.saldoActual` a un valor real indicado por el usuario,
/// registrando la diferencia como una `Transaccion` más (no sobrescribe el
/// saldo directamente) — así el ajuste queda trazable en el historial,
/// igual que cualquier otro movimiento.
class AjustarSaldoCuenta {
  final CuentaRepository _cuentaRepository;
  final TransaccionRepository _transaccionRepository;
  final CategoriaRepository _categoriaRepository;
  final Uuid _uuid;

  AjustarSaldoCuenta({
    required CuentaRepository cuentaRepository,
    required TransaccionRepository transaccionRepository,
    required CategoriaRepository categoriaRepository,
    Uuid? uuid,
  }) : _cuentaRepository = cuentaRepository,
       _transaccionRepository = transaccionRepository,
       _categoriaRepository = categoriaRepository,
       _uuid = uuid ?? const Uuid();

  /// Devuelve la `Transaccion` de ajuste creada, o `null` si `saldoReal` ya
  /// coincidía con el saldo actual (no se crea ningún movimiento de S/ 0).
  Future<Transaccion?> call({
    required String cuentaId,
    required double saldoReal,
  }) async {
    final cuenta = await _cuentaRepository.obtenerPorId(cuentaId);
    if (cuenta == null) {
      throw ArgumentError('La cuenta $cuentaId no existe');
    }

    final diferencia = saldoReal - cuenta.saldoActual;
    if (diferencia == 0) return null;

    final tipo = diferencia > 0
        ? TipoTransaccion.ingreso
        : TipoTransaccion.gasto;
    final tipoCategoriaEsperado = tipo == TipoTransaccion.ingreso
        ? TipoCategoria.ingreso
        : TipoCategoria.gasto;

    final categorias = await _categoriaRepository.obtenerTodas();
    Categoria? categoriaAjuste;
    for (final categoria in categorias) {
      if (categoria.nombre == nombreCategoriaAjusteSaldo &&
          categoria.tipo == tipoCategoriaEsperado) {
        categoriaAjuste = categoria;
        break;
      }
    }
    if (categoriaAjuste == null) {
      throw StateError(
        'No se encontró la categoría "$nombreCategoriaAjusteSaldo" '
        'de tipo ${tipoCategoriaEsperado.name}',
      );
    }

    final transaccion = Transaccion(
      id: _uuid.v4(),
      cuentaId: cuentaId,
      categoriaId: categoriaAjuste.id,
      monto: diferencia.abs(),
      moneda: cuenta.moneda,
      tipo: tipo,
      concepto: nombreCategoriaAjusteSaldo,
      metodoPago: MetodoPago.otro,
      esRecurrente: false,
      fuenteCaptura: FuenteCaptura.ajuste,
      fecha: DateTime.now(),
    );

    await _transaccionRepository.crear(transaccion);
    await _cuentaRepository.actualizar(
      cuenta.copyWith(
        saldoActual: aplicarEfectoTransaccion(
          cuenta.saldoActual,
          tipo,
          diferencia.abs(),
        ),
      ),
    );

    return transaccion;
  }
}
