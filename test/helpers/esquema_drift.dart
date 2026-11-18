import 'package:drift/native.dart';
import 'package:finanzas_automaticas/infrastructure/persistence/drift/app_database.dart';

/// Columnas agregadas por cada migración de Drift: versión que la
/// introdujo → (tabla, columna). Al agregar una migración nueva, agregar
/// aquí sus columnas. Desde la versión 5 las migraciones solo AGREGAN
/// columnas (salvo `dia_corte`/`dia_pago`, que la 6 agrega y la 8 borra),
/// así que quitar estas columnas del esquema actual da el de esa versión.
const Map<int, List<(String, String)>> columnasPorVersion = {
  6: [('cuentas', 'linea_credito')],
  7: [('cuentas', 'ultimos_digitos')],
  8: [
    ('cuentas', 'fecha_corte'),
    ('cuentas', 'fecha_pago'),
    ('deudas', 'cuenta_id'),
  ],
  9: [('deudas', 'amigo_usuario_id')],
  10: [('cuentas', 'pago_minimo')],
  11: [('deudas', 'direccion')],
  12: [('cuentas', 'tcea')],
  13: [('pagos_deuda', 'tipo'), ('deudas', 'monto_abonado_capital')],
  14: [('deudas', 'monto_ultima_cuota')],
  15: [('transacciones', 'transferencia_id')],
};

/// `CREATE TABLE` del esquema actual menos las columnas agregadas después
/// de [version] = el esquema de esa versión. Soporta 5 en adelante. En 6 y
/// 7 la tabla `cuentas` tenía además `dia_corte`/`dia_pago` (INTEGER
/// nullable, agregadas en 6 y borradas en 8): se reponen a mano después de
/// `linea_credito` (Fase 84b — esas versiones pudieron llegar a TestFlight).
Future<List<String>> esquemaDriftEnVersion(int version) async {
  if (version < 5) {
    throw UnsupportedError('Esquema v$version no derivable (ver doc)');
  }
  final actual = AppDatabase.forTesting(NativeDatabase.memory());
  final tablas = await actual
      .customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  await actual.close();
  final quitar = [
    for (final e in columnasPorVersion.entries)
      if (e.key > version) ...e.value,
  ];
  return [
    for (final t in tablas)
      _conCategoriaObligatoria(
        t.read('name'),
        _conDiasDeCorte(
          t.read('name'),
          _sinColumnas(t.read('name'), t.read('sql'), quitar),
          version,
        ),
        version,
      ),
  ];
}

/// Antes de la v15 (Fase 85) `transacciones.categoria_id` era NOT NULL.
String _conCategoriaObligatoria(String tabla, String sql, int version) {
  if (tabla != 'transacciones' || version >= 15) return sql;
  const actual = '"categoria_id" TEXT NULL';
  if (!sql.contains(actual)) {
    throw StateError('No se encontró $actual en transacciones');
  }
  return sql.replaceFirst(actual, '"categoria_id" TEXT NOT NULL');
}

String _conDiasDeCorte(String tabla, String sql, int version) {
  if (tabla != 'cuentas' || (version != 6 && version != 7)) return sql;
  const ancla = '"linea_credito" REAL NULL';
  if (!sql.contains(ancla)) {
    throw StateError('No se encontró $ancla en cuentas (esquema v$version)');
  }
  return sql.replaceFirst(
    ancla,
    '$ancla, "dia_corte" INTEGER NULL, "dia_pago" INTEGER NULL',
  );
}

String _sinColumnas(String tabla, String sql, List<(String, String)> quitar) {
  var resultado = sql;
  for (final (t, columna) in quitar) {
    if (t != tabla) continue;
    final patron = RegExp(
      ',\\s*"$columna" [A-Z]+ (NOT )?NULL( DEFAULT [^,]+)?',
    );
    final sinColumna = resultado.replaceAll(patron, '');
    if (sinColumna == resultado) {
      throw StateError(
        'No se encontró "$columna" en $tabla: revisa la regex o la tabla '
        'en test/helpers/esquema_drift.dart',
      );
    }
    resultado = sinColumna;
  }
  return resultado;
}
