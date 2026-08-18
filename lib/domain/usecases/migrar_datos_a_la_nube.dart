import '../entities/pago_deuda.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';

/// Se lanza cuando un paso de la migración falla — lleva el nombre del
/// paso para que la UI pueda mostrar en qué se quedó ("Subiendo deudas...")
/// y para que el reintento tenga contexto. Nunca se atrapa a mitad de
/// camino para "seguir de todos modos": si un paso falla, los pasos
/// siguientes no se ejecutan y no se toca nada local.
class MigracionFallidaException implements Exception {
  final String paso;
  final Object causa;

  const MigracionFallidaException(this.paso, this.causa);

  @override
  String toString() => 'Falló la migración en "$paso": $causa';
}

/// Sube TODOS los datos financieros locales (Drift) a Supabase,
/// preservando los mismos IDs (uuid string en ambos lados, así que las
/// relaciones por FK no necesitan remapeo). Orden de inserción obligatorio
/// por dependencias: cuentas → categorías propias → deudas →
/// transacciones → pagos de deuda.
///
/// No borra nada local — eso es responsabilidad de `MigrarDatosScreen`,
/// y solo después de que este caso de uso termine sin lanzar ninguna
/// excepción. Al terminar de subir, vuelve a contar en Supabase y compara
/// contra los conteos locales antes de darse por exitoso.
class MigrarDatosALaNube {
  final CuentaRepository _cuentaRepositoryLocal;
  final CategoriaRepository _categoriaRepositoryLocal;
  final DeudaRepository _deudaRepositoryLocal;
  final TransaccionRepository _transaccionRepositoryLocal;
  final PagoDeudaRepository _pagoDeudaRepositoryLocal;
  final CuentaRepository _cuentaRepositoryNube;
  final CategoriaRepository _categoriaRepositoryNube;
  final DeudaRepository _deudaRepositoryNube;
  final TransaccionRepository _transaccionRepositoryNube;
  final PagoDeudaRepository _pagoDeudaRepositoryNube;

  MigrarDatosALaNube({
    required CuentaRepository cuentaRepositoryLocal,
    required CategoriaRepository categoriaRepositoryLocal,
    required DeudaRepository deudaRepositoryLocal,
    required TransaccionRepository transaccionRepositoryLocal,
    required PagoDeudaRepository pagoDeudaRepositoryLocal,
    required CuentaRepository cuentaRepositoryNube,
    required CategoriaRepository categoriaRepositoryNube,
    required DeudaRepository deudaRepositoryNube,
    required TransaccionRepository transaccionRepositoryNube,
    required PagoDeudaRepository pagoDeudaRepositoryNube,
  }) : _cuentaRepositoryLocal = cuentaRepositoryLocal,
       _categoriaRepositoryLocal = categoriaRepositoryLocal,
       _deudaRepositoryLocal = deudaRepositoryLocal,
       _transaccionRepositoryLocal = transaccionRepositoryLocal,
       _pagoDeudaRepositoryLocal = pagoDeudaRepositoryLocal,
       _cuentaRepositoryNube = cuentaRepositoryNube,
       _categoriaRepositoryNube = categoriaRepositoryNube,
       _deudaRepositoryNube = deudaRepositoryNube,
       _transaccionRepositoryNube = transaccionRepositoryNube,
       _pagoDeudaRepositoryNube = pagoDeudaRepositoryNube;

  Future<void> call({void Function(String etapa)? onProgreso}) async {
    final cuentas = await _cuentaRepositoryLocal.obtenerTodas();
    final categoriasPropias = (await _categoriaRepositoryLocal.obtenerTodas())
        .where((c) => !c.esPredeterminada)
        .toList();
    final deudas = await _deudaRepositoryLocal.obtenerTodas();
    final transacciones = await _transaccionRepositoryLocal.obtenerTodas();
    final pagos = <PagoDeuda>[
      for (final deuda in deudas)
        ...await _pagoDeudaRepositoryLocal.obtenerPorDeuda(deuda.id),
    ];

    onProgreso?.call('Subiendo cuentas...');
    await _migrarPaso('cuentas', cuentas, _cuentaRepositoryNube.crear);

    onProgreso?.call('Subiendo categorías...');
    await _migrarPaso(
      'categorías',
      categoriasPropias,
      _categoriaRepositoryNube.crear,
    );

    onProgreso?.call('Subiendo deudas...');
    await _migrarPaso('deudas', deudas, _deudaRepositoryNube.crear);

    onProgreso?.call('Subiendo transacciones...');
    await _migrarPaso(
      'transacciones',
      transacciones,
      _transaccionRepositoryNube.crear,
    );

    onProgreso?.call('Subiendo pagos de deuda...');
    await _migrarPaso('pagos de deuda', pagos, _pagoDeudaRepositoryNube.crear);

    onProgreso?.call('Verificando...');
    await _verificar(
      cuentas: cuentas.length,
      categorias: categoriasPropias.length,
      deudas: deudas.length,
      transacciones: transacciones.length,
      pagos: pagos.length,
    );
  }

  Future<void> _migrarPaso<T>(
    String nombrePaso,
    List<T> registros,
    Future<void> Function(T) crear,
  ) async {
    for (final registro in registros) {
      try {
        await crear(registro);
      } catch (error) {
        throw MigracionFallidaException(nombrePaso, error);
      }
    }
  }

  Future<void> _verificar({
    required int cuentas,
    required int categorias,
    required int deudas,
    required int transacciones,
    required int pagos,
  }) async {
    Future<void> comparar(
      String nombre,
      int esperado,
      Future<int> Function() contarEnNube,
    ) async {
      final int enNube;
      try {
        enNube = await contarEnNube();
      } catch (error) {
        throw MigracionFallidaException('verificación de $nombre', error);
      }
      if (enNube < esperado) {
        throw MigracionFallidaException(
          'verificación de $nombre',
          'se esperaban $esperado registros en la nube, se encontraron $enNube',
        );
      }
    }

    await comparar(
      'cuentas',
      cuentas,
      () async => (await _cuentaRepositoryNube.obtenerTodas()).length,
    );
    await comparar('categorías', categorias, () async {
      final todas = await _categoriaRepositoryNube.obtenerTodas();
      return todas.where((c) => !c.esPredeterminada).length;
    });
    await comparar(
      'deudas',
      deudas,
      () async => (await _deudaRepositoryNube.obtenerTodas()).length,
    );
    await comparar(
      'transacciones',
      transacciones,
      () async => (await _transaccionRepositoryNube.obtenerTodas()).length,
    );
    await comparar('pagos de deuda', pagos, () async {
      final deudasNube = await _deudaRepositoryNube.obtenerTodas();
      var total = 0;
      for (final deuda in deudasNube) {
        total += (await _pagoDeudaRepositoryNube.obtenerPorDeuda(
          deuda.id,
        )).length;
      }
      return total;
    });
  }
}
