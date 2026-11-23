import '../entities/cuenta.dart';
import '../entities/deuda.dart';
import '../entities/pago_deuda.dart';
import '../entities/transaccion.dart';
import '../repositories/categoria_repository.dart';
import '../repositories/cuenta_repository.dart';
import '../repositories/deuda_repository.dart';
import '../repositories/pago_deuda_repository.dart';
import '../repositories/transaccion_repository.dart';

/// Qué se subió en una migración (o hasta dónde llegó si falló): por paso,
/// cuántos registros se SUBIERON en esta corrida y cuántos YA ESTABAN en la
/// nube (de una corrida anterior) y por eso se saltaron.
class ResumenMigracion {
  final Map<String, int> subidos;
  final Map<String, int> yaEstaban;

  /// Transferencias que YA estaban a medias en el teléfono (una sola
  /// cara): se suben tal cual, sin inventar la otra (Fase 88).
  final List<String> transferenciasIncompletasLocales;

  const ResumenMigracion({
    this.subidos = const {},
    this.yaEstaban = const {},
    this.transferenciasIncompletasLocales = const [],
  });

  /// "cuentas: 3 subidas (1 ya estaba); deudas: 0 subidas; …"
  String get descripcion {
    final pasos = {...subidos.keys, ...yaEstaban.keys};
    if (pasos.isEmpty) return 'no se subió nada';
    return [
      for (final p in pasos)
        '$p: ${subidos[p] ?? 0} '
            '${(subidos[p] ?? 0) == 1 ? 'subido' : 'subidos'}'
            '${(yaEstaban[p] ?? 0) > 0 ? ' (${yaEstaban[p]} ya estaban)' : ''}',
    ].join('; ');
  }
}

/// Se lanza cuando un paso de la migración falla — lleva el nombre del
/// paso para que la UI pueda mostrar en qué se quedó ("Subiendo deudas...")
/// y para que el reintento tenga contexto. Nunca se atrapa a mitad de
/// camino para "seguir de todos modos": si un paso falla, los pasos
/// siguientes no se ejecutan y no se toca nada local.
///
/// Fase 88: [resumen] dice EXACTAMENTE qué quedó subido hasta el fallo, y
/// [detalle] explica casos especiales (p. ej. una transferencia deshecha).
class MigracionFallidaException implements Exception {
  final String paso;
  final Object causa;
  final ResumenMigracion resumen;
  final String? detalle;

  const MigracionFallidaException(
    this.paso,
    this.causa, {
    this.resumen = const ResumenMigracion(),
    this.detalle,
  });

  @override
  String toString() =>
      'Falló la migración en "$paso": $causa. '
      'Hasta ahí: ${resumen.descripcion}.'
      '${detalle == null ? '' : ' $detalle'}';
}

/// Sube TODOS los datos financieros locales (Drift) a Supabase,
/// preservando los mismos IDs (uuid string en ambos lados, así que las
/// relaciones por FK no necesitan remapeo). Orden de inserción obligatorio
/// por dependencias: cuentas → categorías propias → deudas →
/// transacciones → pagos de deuda.
///
/// Se suben las entidades completas: los campos de las Fases 82–85
/// (`direccion`, `montoAbonadoCapital`, `montoUltimaCuota`, `tcea`, el tipo
/// de pago y las transferencias con `transferenciaId` y sin categoría)
/// viajan por los mismos repositorios de Supabase que usa la app. Requiere
/// haber corrido los SQL de `supabase/migraciones_pendientes/`.
///
/// Fase 88 — IDEMPOTENTE: antes de cada paso lee lo que ya hay en la nube
/// y salta los ids existentes, así que repetirla (p. ej. tras un fallo a
/// mitad) no duplica nada. Las dos caras de una transferencia se suben
/// juntas: si la segunda falla, se borra la primera para que ninguna
/// transferencia quede con una sola cara en la nube.
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

  final _subidos = <String, int>{};
  final _yaEstaban = <String, int>{};
  var _incompletasLocales = <String>[];

  ResumenMigracion get _resumen => ResumenMigracion(
    subidos: Map.of(_subidos),
    yaEstaban: Map.of(_yaEstaban),
    transferenciasIncompletasLocales: List.of(_incompletasLocales),
  );

  Never _fallo(String paso, Object causa, {String? detalle}) =>
      throw MigracionFallidaException(
        paso,
        causa,
        resumen: _resumen,
        detalle: detalle,
      );

  Future<ResumenMigracion> call({
    void Function(String etapa)? onProgreso,
  }) async {
    _subidos.clear();
    _yaEstaban.clear();
    _incompletasLocales = [];

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
    await _migrarPaso(
      'cuentas',
      cuentas,
      (c) => c.id,
      () async => {
        for (final c in await _cuentaRepositoryNube.obtenerTodas()) c.id,
      },
      _cuentaRepositoryNube.crear,
    );

    onProgreso?.call('Subiendo categorías...');
    await _migrarPaso(
      'categorías',
      categoriasPropias,
      (c) => c.id,
      () async => {
        for (final c in await _categoriaRepositoryNube.obtenerTodas()) c.id,
      },
      _categoriaRepositoryNube.crear,
    );

    onProgreso?.call('Subiendo deudas...');
    await _migrarPaso(
      'deudas',
      deudas,
      (d) => d.id,
      () async => {
        for (final d in await _deudaRepositoryNube.obtenerTodas()) d.id,
      },
      _deudaRepositoryNube.crear,
    );

    onProgreso?.call('Subiendo transacciones...');
    await _migrarTransacciones(transacciones);

    onProgreso?.call('Subiendo pagos de deuda...');
    await _migrarPaso(
      'pagos de deuda',
      pagos,
      (p) => p.id,
      () async => {
        for (final d in deudas)
          for (final p in await _pagoDeudaRepositoryNube.obtenerPorDeuda(d.id))
            p.id,
      },
      _pagoDeudaRepositoryNube.crear,
    );

    // Fase 88b — producción tiene triggers que, en cada INSERT de una
    // transacción o un pago, vuelven a sumar/restar en
    // `cuentas.saldo_actual` y `deudas.monto_pagado` (y, antes de
    // fase89_triggers.sql, `numero_cuotas_pagadas`/`estado`). Como las
    // cuentas y deudas ya se subieron con sus valores FINALES, esos efectos
    // los duplicarían. Se reescriben al final con los valores del teléfono
    // (escritura absoluta, el mismo patrón que la app usa en cada pago).
    onProgreso?.call('Ajustando saldos...');
    await _reescribirValoresFinales(cuentas, deudas);

    onProgreso?.call('Verificando...');
    await _verificar(
      cuentas: cuentas.length,
      categorias: categoriasPropias.length,
      deudas: deudas.length,
      transacciones: transacciones.length,
      pagos: pagos.length,
    );
    return _resumen;
  }

  Future<void> _migrarPaso<T>(
    String nombrePaso,
    List<T> registros,
    String Function(T) idDe,
    Future<Set<String>> Function() idsEnNube,
    Future<void> Function(T) crear,
  ) async {
    _subidos[nombrePaso] = 0;
    _yaEstaban[nombrePaso] = 0;
    final Set<String> existentes;
    try {
      existentes = registros.isEmpty ? const {} : await idsEnNube();
    } catch (error) {
      _fallo(nombrePaso, error);
    }
    for (final registro in registros) {
      if (existentes.contains(idDe(registro))) {
        _yaEstaban.update(nombrePaso, (v) => v + 1);
        continue;
      }
      try {
        await crear(registro);
      } catch (error) {
        _fallo(nombrePaso, error);
      }
      _subidos.update(nombrePaso, (v) => v + 1);
    }
  }

  /// Transacciones: las normales una a una; las transferencias por pares
  /// (salida y luego entrada). Si la segunda cara falla, se borra la
  /// primera de la nube para no dejar una transferencia con una sola cara.
  Future<void> _migrarTransacciones(List<Transaccion> transacciones) async {
    const paso = 'transacciones';
    _subidos[paso] = 0;
    _yaEstaban[paso] = 0;
    final Set<String> existentes;
    try {
      existentes = transacciones.isEmpty
          ? const {}
          : {
              for (final t in await _transaccionRepositoryNube.obtenerTodas())
                t.id,
            };
    } catch (error) {
      _fallo(paso, error);
    }

    final normales = <Transaccion>[];
    final porTransferencia = <String, List<Transaccion>>{};
    for (final t in transacciones) {
      final id = t.transferenciaId;
      if (id == null) {
        normales.add(t);
      } else {
        porTransferencia.putIfAbsent(id, () => []).add(t);
      }
    }

    Future<bool> subir(Transaccion t) async {
      if (existentes.contains(t.id)) {
        _yaEstaban.update(paso, (v) => v + 1);
        return false;
      }
      await _transaccionRepositoryNube.crear(t);
      existentes.add(t.id);
      _subidos.update(paso, (v) => v + 1);
      return true;
    }

    for (final t in normales) {
      try {
        await subir(t);
      } catch (error) {
        _fallo(paso, error);
      }
    }

    for (final MapEntry(key: transferenciaId, value: caras)
        in porTransferencia.entries) {
      // Salida primero, entrada después (orden estable).
      caras.sort((a, b) {
        int rango(Transaccion t) =>
            t.tipo == TipoTransaccion.transferenciaSalida ? 0 : 1;
        return rango(a).compareTo(rango(b));
      });
      if (caras.length < 2) _incompletasLocales.add(transferenciaId);

      final subidasAhora = <Transaccion>[];
      for (final cara in caras) {
        try {
          if (await subir(cara)) subidasAhora.add(cara);
        } catch (error) {
          // Deshacer lo subido en ESTE par para no dejar una sola cara.
          var deshecho = true;
          for (final previa in subidasAhora) {
            try {
              await _transaccionRepositoryNube.eliminar(previa.id);
              existentes.remove(previa.id);
              _subidos.update(paso, (v) => v - 1);
            } catch (_) {
              deshecho = false;
            }
          }
          _fallo(
            paso,
            error,
            detalle: subidasAhora.isEmpty
                ? null
                : deshecho
                ? 'La transferencia $transferenciaId se deshizo en la nube '
                      '(no quedó con una sola cara); se sube completa al '
                      'reintentar.'
                : 'ATENCIÓN: la transferencia $transferenciaId quedó con '
                      'una sola cara en la nube y no se pudo deshacer; '
                      'reintentar sube la que falta.',
          );
        }
      }
    }
  }

  /// Ver el comentario en [call]. Idempotente: reescribir el mismo valor
  /// dos veces da lo mismo.
  Future<void> _reescribirValoresFinales(
    List<Cuenta> cuentas,
    List<Deuda> deudas,
  ) async {
    const paso = 'saldos reescritos';
    _subidos[paso] = 0;
    for (final cuenta in cuentas) {
      try {
        await _cuentaRepositoryNube.actualizar(cuenta);
      } catch (error) {
        _fallo('ajuste de saldos de cuentas', error);
      }
      _subidos.update(paso, (v) => v + 1);
    }
    for (final deuda in deudas) {
      try {
        await _deudaRepositoryNube.actualizar(deuda);
      } catch (error) {
        _fallo('ajuste de deudas', error);
      }
      _subidos.update(paso, (v) => v + 1);
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
        _fallo('verificación de $nombre', error);
      }
      if (enNube < esperado) {
        _fallo(
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
