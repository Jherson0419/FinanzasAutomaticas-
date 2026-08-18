// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CuentasTable extends Cuentas with TableInfo<$CuentasTable, CuentaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CuentasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monedaMeta = const VerificationMeta('moneda');
  @override
  late final GeneratedColumn<String> moneda = GeneratedColumn<String>(
    'moneda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saldoActualMeta = const VerificationMeta(
    'saldoActual',
  );
  @override
  late final GeneratedColumn<double> saldoActual = GeneratedColumn<double>(
    'saldo_actual',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nombre, tipo, moneda, saldoActual];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cuentas';
  @override
  VerificationContext validateIntegrity(
    Insertable<CuentaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('moneda')) {
      context.handle(
        _monedaMeta,
        moneda.isAcceptableOrUnknown(data['moneda']!, _monedaMeta),
      );
    } else if (isInserting) {
      context.missing(_monedaMeta);
    }
    if (data.containsKey('saldo_actual')) {
      context.handle(
        _saldoActualMeta,
        saldoActual.isAcceptableOrUnknown(
          data['saldo_actual']!,
          _saldoActualMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_saldoActualMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CuentaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CuentaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      moneda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moneda'],
      )!,
      saldoActual: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}saldo_actual'],
      )!,
    );
  }

  @override
  $CuentasTable createAlias(String alias) {
    return $CuentasTable(attachedDatabase, alias);
  }
}

class CuentaRow extends DataClass implements Insertable<CuentaRow> {
  final String id;
  final String nombre;
  final String tipo;
  final String moneda;
  final double saldoActual;
  const CuentaRow({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.moneda,
    required this.saldoActual,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    map['tipo'] = Variable<String>(tipo);
    map['moneda'] = Variable<String>(moneda);
    map['saldo_actual'] = Variable<double>(saldoActual);
    return map;
  }

  CuentasCompanion toCompanion(bool nullToAbsent) {
    return CuentasCompanion(
      id: Value(id),
      nombre: Value(nombre),
      tipo: Value(tipo),
      moneda: Value(moneda),
      saldoActual: Value(saldoActual),
    );
  }

  factory CuentaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CuentaRow(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      tipo: serializer.fromJson<String>(json['tipo']),
      moneda: serializer.fromJson<String>(json['moneda']),
      saldoActual: serializer.fromJson<double>(json['saldoActual']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'tipo': serializer.toJson<String>(tipo),
      'moneda': serializer.toJson<String>(moneda),
      'saldoActual': serializer.toJson<double>(saldoActual),
    };
  }

  CuentaRow copyWith({
    String? id,
    String? nombre,
    String? tipo,
    String? moneda,
    double? saldoActual,
  }) => CuentaRow(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    moneda: moneda ?? this.moneda,
    saldoActual: saldoActual ?? this.saldoActual,
  );
  CuentaRow copyWithCompanion(CuentasCompanion data) {
    return CuentaRow(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      moneda: data.moneda.present ? data.moneda.value : this.moneda,
      saldoActual: data.saldoActual.present
          ? data.saldoActual.value
          : this.saldoActual,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CuentaRow(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo, ')
          ..write('moneda: $moneda, ')
          ..write('saldoActual: $saldoActual')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, tipo, moneda, saldoActual);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CuentaRow &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.tipo == this.tipo &&
          other.moneda == this.moneda &&
          other.saldoActual == this.saldoActual);
}

class CuentasCompanion extends UpdateCompanion<CuentaRow> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<String> tipo;
  final Value<String> moneda;
  final Value<double> saldoActual;
  final Value<int> rowid;
  const CuentasCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.tipo = const Value.absent(),
    this.moneda = const Value.absent(),
    this.saldoActual = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CuentasCompanion.insert({
    required String id,
    required String nombre,
    required String tipo,
    required String moneda,
    required double saldoActual,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre),
       tipo = Value(tipo),
       moneda = Value(moneda),
       saldoActual = Value(saldoActual);
  static Insertable<CuentaRow> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<String>? tipo,
    Expression<String>? moneda,
    Expression<double>? saldoActual,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (tipo != null) 'tipo': tipo,
      if (moneda != null) 'moneda': moneda,
      if (saldoActual != null) 'saldo_actual': saldoActual,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CuentasCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<String>? tipo,
    Value<String>? moneda,
    Value<double>? saldoActual,
    Value<int>? rowid,
  }) {
    return CuentasCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      moneda: moneda ?? this.moneda,
      saldoActual: saldoActual ?? this.saldoActual,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (moneda.present) {
      map['moneda'] = Variable<String>(moneda.value);
    }
    if (saldoActual.present) {
      map['saldo_actual'] = Variable<double>(saldoActual.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CuentasCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo, ')
          ..write('moneda: $moneda, ')
          ..write('saldoActual: $saldoActual, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriasTable extends Categorias
    with TableInfo<$CategoriasTable, CategoriaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _esPredeterminadaMeta = const VerificationMeta(
    'esPredeterminada',
  );
  @override
  late final GeneratedColumn<bool> esPredeterminada = GeneratedColumn<bool>(
    'es_predeterminada',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("es_predeterminada" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombre,
    tipo,
    iconName,
    esPredeterminada,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categorias';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoriaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    } else if (isInserting) {
      context.missing(_iconNameMeta);
    }
    if (data.containsKey('es_predeterminada')) {
      context.handle(
        _esPredeterminadaMeta,
        esPredeterminada.isAcceptableOrUnknown(
          data['es_predeterminada']!,
          _esPredeterminadaMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoriaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      )!,
      esPredeterminada: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}es_predeterminada'],
      )!,
    );
  }

  @override
  $CategoriasTable createAlias(String alias) {
    return $CategoriasTable(attachedDatabase, alias);
  }
}

class CategoriaRow extends DataClass implements Insertable<CategoriaRow> {
  final String id;
  final String nombre;
  final String tipo;
  final String iconName;
  final bool esPredeterminada;
  const CategoriaRow({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.iconName,
    required this.esPredeterminada,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    map['tipo'] = Variable<String>(tipo);
    map['icon_name'] = Variable<String>(iconName);
    map['es_predeterminada'] = Variable<bool>(esPredeterminada);
    return map;
  }

  CategoriasCompanion toCompanion(bool nullToAbsent) {
    return CategoriasCompanion(
      id: Value(id),
      nombre: Value(nombre),
      tipo: Value(tipo),
      iconName: Value(iconName),
      esPredeterminada: Value(esPredeterminada),
    );
  }

  factory CategoriaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriaRow(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      tipo: serializer.fromJson<String>(json['tipo']),
      iconName: serializer.fromJson<String>(json['iconName']),
      esPredeterminada: serializer.fromJson<bool>(json['esPredeterminada']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'tipo': serializer.toJson<String>(tipo),
      'iconName': serializer.toJson<String>(iconName),
      'esPredeterminada': serializer.toJson<bool>(esPredeterminada),
    };
  }

  CategoriaRow copyWith({
    String? id,
    String? nombre,
    String? tipo,
    String? iconName,
    bool? esPredeterminada,
  }) => CategoriaRow(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    tipo: tipo ?? this.tipo,
    iconName: iconName ?? this.iconName,
    esPredeterminada: esPredeterminada ?? this.esPredeterminada,
  );
  CategoriaRow copyWithCompanion(CategoriasCompanion data) {
    return CategoriaRow(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      esPredeterminada: data.esPredeterminada.present
          ? data.esPredeterminada.value
          : this.esPredeterminada,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriaRow(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo, ')
          ..write('iconName: $iconName, ')
          ..write('esPredeterminada: $esPredeterminada')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, tipo, iconName, esPredeterminada);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriaRow &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.tipo == this.tipo &&
          other.iconName == this.iconName &&
          other.esPredeterminada == this.esPredeterminada);
}

class CategoriasCompanion extends UpdateCompanion<CategoriaRow> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<String> tipo;
  final Value<String> iconName;
  final Value<bool> esPredeterminada;
  final Value<int> rowid;
  const CategoriasCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.tipo = const Value.absent(),
    this.iconName = const Value.absent(),
    this.esPredeterminada = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriasCompanion.insert({
    required String id,
    required String nombre,
    required String tipo,
    required String iconName,
    this.esPredeterminada = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre),
       tipo = Value(tipo),
       iconName = Value(iconName);
  static Insertable<CategoriaRow> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<String>? tipo,
    Expression<String>? iconName,
    Expression<bool>? esPredeterminada,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (tipo != null) 'tipo': tipo,
      if (iconName != null) 'icon_name': iconName,
      if (esPredeterminada != null) 'es_predeterminada': esPredeterminada,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriasCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<String>? tipo,
    Value<String>? iconName,
    Value<bool>? esPredeterminada,
    Value<int>? rowid,
  }) {
    return CategoriasCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      iconName: iconName ?? this.iconName,
      esPredeterminada: esPredeterminada ?? this.esPredeterminada,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (esPredeterminada.present) {
      map['es_predeterminada'] = Variable<bool>(esPredeterminada.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriasCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('tipo: $tipo, ')
          ..write('iconName: $iconName, ')
          ..write('esPredeterminada: $esPredeterminada, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransaccionesTable extends Transacciones
    with TableInfo<$TransaccionesTable, TransaccionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransaccionesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cuentaIdMeta = const VerificationMeta(
    'cuentaId',
  );
  @override
  late final GeneratedColumn<String> cuentaId = GeneratedColumn<String>(
    'cuenta_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoriaIdMeta = const VerificationMeta(
    'categoriaId',
  );
  @override
  late final GeneratedColumn<String> categoriaId = GeneratedColumn<String>(
    'categoria_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoMeta = const VerificationMeta('monto');
  @override
  late final GeneratedColumn<double> monto = GeneratedColumn<double>(
    'monto',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monedaMeta = const VerificationMeta('moneda');
  @override
  late final GeneratedColumn<String> moneda = GeneratedColumn<String>(
    'moneda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoMeta = const VerificationMeta('tipo');
  @override
  late final GeneratedColumn<String> tipo = GeneratedColumn<String>(
    'tipo',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conceptoMeta = const VerificationMeta(
    'concepto',
  );
  @override
  late final GeneratedColumn<String> concepto = GeneratedColumn<String>(
    'concepto',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metodoPagoMeta = const VerificationMeta(
    'metodoPago',
  );
  @override
  late final GeneratedColumn<String> metodoPago = GeneratedColumn<String>(
    'metodo_pago',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _esRecurrenteMeta = const VerificationMeta(
    'esRecurrente',
  );
  @override
  late final GeneratedColumn<bool> esRecurrente = GeneratedColumn<bool>(
    'es_recurrente',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("es_recurrente" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _comprobanteUrlMeta = const VerificationMeta(
    'comprobanteUrl',
  );
  @override
  late final GeneratedColumn<String> comprobanteUrl = GeneratedColumn<String>(
    'comprobante_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fuenteCapturaMeta = const VerificationMeta(
    'fuenteCaptura',
  );
  @override
  late final GeneratedColumn<String> fuenteCaptura = GeneratedColumn<String>(
    'fuente_captura',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataRawMeta = const VerificationMeta(
    'dataRaw',
  );
  @override
  late final GeneratedColumn<String> dataRaw = GeneratedColumn<String>(
    'data_raw',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fechaMeta = const VerificationMeta('fecha');
  @override
  late final GeneratedColumn<DateTime> fecha = GeneratedColumn<DateTime>(
    'fecha',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cuentaId,
    categoriaId,
    monto,
    moneda,
    tipo,
    concepto,
    metodoPago,
    esRecurrente,
    comprobanteUrl,
    fuenteCaptura,
    dataRaw,
    fecha,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transacciones';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransaccionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cuenta_id')) {
      context.handle(
        _cuentaIdMeta,
        cuentaId.isAcceptableOrUnknown(data['cuenta_id']!, _cuentaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cuentaIdMeta);
    }
    if (data.containsKey('categoria_id')) {
      context.handle(
        _categoriaIdMeta,
        categoriaId.isAcceptableOrUnknown(
          data['categoria_id']!,
          _categoriaIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoriaIdMeta);
    }
    if (data.containsKey('monto')) {
      context.handle(
        _montoMeta,
        monto.isAcceptableOrUnknown(data['monto']!, _montoMeta),
      );
    } else if (isInserting) {
      context.missing(_montoMeta);
    }
    if (data.containsKey('moneda')) {
      context.handle(
        _monedaMeta,
        moneda.isAcceptableOrUnknown(data['moneda']!, _monedaMeta),
      );
    } else if (isInserting) {
      context.missing(_monedaMeta);
    }
    if (data.containsKey('tipo')) {
      context.handle(
        _tipoMeta,
        tipo.isAcceptableOrUnknown(data['tipo']!, _tipoMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoMeta);
    }
    if (data.containsKey('concepto')) {
      context.handle(
        _conceptoMeta,
        concepto.isAcceptableOrUnknown(data['concepto']!, _conceptoMeta),
      );
    } else if (isInserting) {
      context.missing(_conceptoMeta);
    }
    if (data.containsKey('metodo_pago')) {
      context.handle(
        _metodoPagoMeta,
        metodoPago.isAcceptableOrUnknown(data['metodo_pago']!, _metodoPagoMeta),
      );
    } else if (isInserting) {
      context.missing(_metodoPagoMeta);
    }
    if (data.containsKey('es_recurrente')) {
      context.handle(
        _esRecurrenteMeta,
        esRecurrente.isAcceptableOrUnknown(
          data['es_recurrente']!,
          _esRecurrenteMeta,
        ),
      );
    }
    if (data.containsKey('comprobante_url')) {
      context.handle(
        _comprobanteUrlMeta,
        comprobanteUrl.isAcceptableOrUnknown(
          data['comprobante_url']!,
          _comprobanteUrlMeta,
        ),
      );
    }
    if (data.containsKey('fuente_captura')) {
      context.handle(
        _fuenteCapturaMeta,
        fuenteCaptura.isAcceptableOrUnknown(
          data['fuente_captura']!,
          _fuenteCapturaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fuenteCapturaMeta);
    }
    if (data.containsKey('data_raw')) {
      context.handle(
        _dataRawMeta,
        dataRaw.isAcceptableOrUnknown(data['data_raw']!, _dataRawMeta),
      );
    }
    if (data.containsKey('fecha')) {
      context.handle(
        _fechaMeta,
        fecha.isAcceptableOrUnknown(data['fecha']!, _fechaMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransaccionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransaccionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cuentaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cuenta_id'],
      )!,
      categoriaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria_id'],
      )!,
      monto: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto'],
      )!,
      moneda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moneda'],
      )!,
      tipo: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo'],
      )!,
      concepto: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}concepto'],
      )!,
      metodoPago: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metodo_pago'],
      )!,
      esRecurrente: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}es_recurrente'],
      )!,
      comprobanteUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}comprobante_url'],
      ),
      fuenteCaptura: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fuente_captura'],
      )!,
      dataRaw: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_raw'],
      ),
      fecha: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha'],
      )!,
    );
  }

  @override
  $TransaccionesTable createAlias(String alias) {
    return $TransaccionesTable(attachedDatabase, alias);
  }
}

class TransaccionRow extends DataClass implements Insertable<TransaccionRow> {
  final String id;
  final String cuentaId;
  final String categoriaId;
  final double monto;
  final String moneda;
  final String tipo;
  final String concepto;
  final String metodoPago;
  final bool esRecurrente;
  final String? comprobanteUrl;
  final String fuenteCaptura;
  final String? dataRaw;
  final DateTime fecha;
  const TransaccionRow({
    required this.id,
    required this.cuentaId,
    required this.categoriaId,
    required this.monto,
    required this.moneda,
    required this.tipo,
    required this.concepto,
    required this.metodoPago,
    required this.esRecurrente,
    this.comprobanteUrl,
    required this.fuenteCaptura,
    this.dataRaw,
    required this.fecha,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cuenta_id'] = Variable<String>(cuentaId);
    map['categoria_id'] = Variable<String>(categoriaId);
    map['monto'] = Variable<double>(monto);
    map['moneda'] = Variable<String>(moneda);
    map['tipo'] = Variable<String>(tipo);
    map['concepto'] = Variable<String>(concepto);
    map['metodo_pago'] = Variable<String>(metodoPago);
    map['es_recurrente'] = Variable<bool>(esRecurrente);
    if (!nullToAbsent || comprobanteUrl != null) {
      map['comprobante_url'] = Variable<String>(comprobanteUrl);
    }
    map['fuente_captura'] = Variable<String>(fuenteCaptura);
    if (!nullToAbsent || dataRaw != null) {
      map['data_raw'] = Variable<String>(dataRaw);
    }
    map['fecha'] = Variable<DateTime>(fecha);
    return map;
  }

  TransaccionesCompanion toCompanion(bool nullToAbsent) {
    return TransaccionesCompanion(
      id: Value(id),
      cuentaId: Value(cuentaId),
      categoriaId: Value(categoriaId),
      monto: Value(monto),
      moneda: Value(moneda),
      tipo: Value(tipo),
      concepto: Value(concepto),
      metodoPago: Value(metodoPago),
      esRecurrente: Value(esRecurrente),
      comprobanteUrl: comprobanteUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(comprobanteUrl),
      fuenteCaptura: Value(fuenteCaptura),
      dataRaw: dataRaw == null && nullToAbsent
          ? const Value.absent()
          : Value(dataRaw),
      fecha: Value(fecha),
    );
  }

  factory TransaccionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransaccionRow(
      id: serializer.fromJson<String>(json['id']),
      cuentaId: serializer.fromJson<String>(json['cuentaId']),
      categoriaId: serializer.fromJson<String>(json['categoriaId']),
      monto: serializer.fromJson<double>(json['monto']),
      moneda: serializer.fromJson<String>(json['moneda']),
      tipo: serializer.fromJson<String>(json['tipo']),
      concepto: serializer.fromJson<String>(json['concepto']),
      metodoPago: serializer.fromJson<String>(json['metodoPago']),
      esRecurrente: serializer.fromJson<bool>(json['esRecurrente']),
      comprobanteUrl: serializer.fromJson<String?>(json['comprobanteUrl']),
      fuenteCaptura: serializer.fromJson<String>(json['fuenteCaptura']),
      dataRaw: serializer.fromJson<String?>(json['dataRaw']),
      fecha: serializer.fromJson<DateTime>(json['fecha']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cuentaId': serializer.toJson<String>(cuentaId),
      'categoriaId': serializer.toJson<String>(categoriaId),
      'monto': serializer.toJson<double>(monto),
      'moneda': serializer.toJson<String>(moneda),
      'tipo': serializer.toJson<String>(tipo),
      'concepto': serializer.toJson<String>(concepto),
      'metodoPago': serializer.toJson<String>(metodoPago),
      'esRecurrente': serializer.toJson<bool>(esRecurrente),
      'comprobanteUrl': serializer.toJson<String?>(comprobanteUrl),
      'fuenteCaptura': serializer.toJson<String>(fuenteCaptura),
      'dataRaw': serializer.toJson<String?>(dataRaw),
      'fecha': serializer.toJson<DateTime>(fecha),
    };
  }

  TransaccionRow copyWith({
    String? id,
    String? cuentaId,
    String? categoriaId,
    double? monto,
    String? moneda,
    String? tipo,
    String? concepto,
    String? metodoPago,
    bool? esRecurrente,
    Value<String?> comprobanteUrl = const Value.absent(),
    String? fuenteCaptura,
    Value<String?> dataRaw = const Value.absent(),
    DateTime? fecha,
  }) => TransaccionRow(
    id: id ?? this.id,
    cuentaId: cuentaId ?? this.cuentaId,
    categoriaId: categoriaId ?? this.categoriaId,
    monto: monto ?? this.monto,
    moneda: moneda ?? this.moneda,
    tipo: tipo ?? this.tipo,
    concepto: concepto ?? this.concepto,
    metodoPago: metodoPago ?? this.metodoPago,
    esRecurrente: esRecurrente ?? this.esRecurrente,
    comprobanteUrl: comprobanteUrl.present
        ? comprobanteUrl.value
        : this.comprobanteUrl,
    fuenteCaptura: fuenteCaptura ?? this.fuenteCaptura,
    dataRaw: dataRaw.present ? dataRaw.value : this.dataRaw,
    fecha: fecha ?? this.fecha,
  );
  TransaccionRow copyWithCompanion(TransaccionesCompanion data) {
    return TransaccionRow(
      id: data.id.present ? data.id.value : this.id,
      cuentaId: data.cuentaId.present ? data.cuentaId.value : this.cuentaId,
      categoriaId: data.categoriaId.present
          ? data.categoriaId.value
          : this.categoriaId,
      monto: data.monto.present ? data.monto.value : this.monto,
      moneda: data.moneda.present ? data.moneda.value : this.moneda,
      tipo: data.tipo.present ? data.tipo.value : this.tipo,
      concepto: data.concepto.present ? data.concepto.value : this.concepto,
      metodoPago: data.metodoPago.present
          ? data.metodoPago.value
          : this.metodoPago,
      esRecurrente: data.esRecurrente.present
          ? data.esRecurrente.value
          : this.esRecurrente,
      comprobanteUrl: data.comprobanteUrl.present
          ? data.comprobanteUrl.value
          : this.comprobanteUrl,
      fuenteCaptura: data.fuenteCaptura.present
          ? data.fuenteCaptura.value
          : this.fuenteCaptura,
      dataRaw: data.dataRaw.present ? data.dataRaw.value : this.dataRaw,
      fecha: data.fecha.present ? data.fecha.value : this.fecha,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransaccionRow(')
          ..write('id: $id, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('categoriaId: $categoriaId, ')
          ..write('monto: $monto, ')
          ..write('moneda: $moneda, ')
          ..write('tipo: $tipo, ')
          ..write('concepto: $concepto, ')
          ..write('metodoPago: $metodoPago, ')
          ..write('esRecurrente: $esRecurrente, ')
          ..write('comprobanteUrl: $comprobanteUrl, ')
          ..write('fuenteCaptura: $fuenteCaptura, ')
          ..write('dataRaw: $dataRaw, ')
          ..write('fecha: $fecha')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cuentaId,
    categoriaId,
    monto,
    moneda,
    tipo,
    concepto,
    metodoPago,
    esRecurrente,
    comprobanteUrl,
    fuenteCaptura,
    dataRaw,
    fecha,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransaccionRow &&
          other.id == this.id &&
          other.cuentaId == this.cuentaId &&
          other.categoriaId == this.categoriaId &&
          other.monto == this.monto &&
          other.moneda == this.moneda &&
          other.tipo == this.tipo &&
          other.concepto == this.concepto &&
          other.metodoPago == this.metodoPago &&
          other.esRecurrente == this.esRecurrente &&
          other.comprobanteUrl == this.comprobanteUrl &&
          other.fuenteCaptura == this.fuenteCaptura &&
          other.dataRaw == this.dataRaw &&
          other.fecha == this.fecha);
}

class TransaccionesCompanion extends UpdateCompanion<TransaccionRow> {
  final Value<String> id;
  final Value<String> cuentaId;
  final Value<String> categoriaId;
  final Value<double> monto;
  final Value<String> moneda;
  final Value<String> tipo;
  final Value<String> concepto;
  final Value<String> metodoPago;
  final Value<bool> esRecurrente;
  final Value<String?> comprobanteUrl;
  final Value<String> fuenteCaptura;
  final Value<String?> dataRaw;
  final Value<DateTime> fecha;
  final Value<int> rowid;
  const TransaccionesCompanion({
    this.id = const Value.absent(),
    this.cuentaId = const Value.absent(),
    this.categoriaId = const Value.absent(),
    this.monto = const Value.absent(),
    this.moneda = const Value.absent(),
    this.tipo = const Value.absent(),
    this.concepto = const Value.absent(),
    this.metodoPago = const Value.absent(),
    this.esRecurrente = const Value.absent(),
    this.comprobanteUrl = const Value.absent(),
    this.fuenteCaptura = const Value.absent(),
    this.dataRaw = const Value.absent(),
    this.fecha = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransaccionesCompanion.insert({
    required String id,
    required String cuentaId,
    required String categoriaId,
    required double monto,
    required String moneda,
    required String tipo,
    required String concepto,
    required String metodoPago,
    this.esRecurrente = const Value.absent(),
    this.comprobanteUrl = const Value.absent(),
    required String fuenteCaptura,
    this.dataRaw = const Value.absent(),
    required DateTime fecha,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cuentaId = Value(cuentaId),
       categoriaId = Value(categoriaId),
       monto = Value(monto),
       moneda = Value(moneda),
       tipo = Value(tipo),
       concepto = Value(concepto),
       metodoPago = Value(metodoPago),
       fuenteCaptura = Value(fuenteCaptura),
       fecha = Value(fecha);
  static Insertable<TransaccionRow> custom({
    Expression<String>? id,
    Expression<String>? cuentaId,
    Expression<String>? categoriaId,
    Expression<double>? monto,
    Expression<String>? moneda,
    Expression<String>? tipo,
    Expression<String>? concepto,
    Expression<String>? metodoPago,
    Expression<bool>? esRecurrente,
    Expression<String>? comprobanteUrl,
    Expression<String>? fuenteCaptura,
    Expression<String>? dataRaw,
    Expression<DateTime>? fecha,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cuentaId != null) 'cuenta_id': cuentaId,
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (monto != null) 'monto': monto,
      if (moneda != null) 'moneda': moneda,
      if (tipo != null) 'tipo': tipo,
      if (concepto != null) 'concepto': concepto,
      if (metodoPago != null) 'metodo_pago': metodoPago,
      if (esRecurrente != null) 'es_recurrente': esRecurrente,
      if (comprobanteUrl != null) 'comprobante_url': comprobanteUrl,
      if (fuenteCaptura != null) 'fuente_captura': fuenteCaptura,
      if (dataRaw != null) 'data_raw': dataRaw,
      if (fecha != null) 'fecha': fecha,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransaccionesCompanion copyWith({
    Value<String>? id,
    Value<String>? cuentaId,
    Value<String>? categoriaId,
    Value<double>? monto,
    Value<String>? moneda,
    Value<String>? tipo,
    Value<String>? concepto,
    Value<String>? metodoPago,
    Value<bool>? esRecurrente,
    Value<String?>? comprobanteUrl,
    Value<String>? fuenteCaptura,
    Value<String?>? dataRaw,
    Value<DateTime>? fecha,
    Value<int>? rowid,
  }) {
    return TransaccionesCompanion(
      id: id ?? this.id,
      cuentaId: cuentaId ?? this.cuentaId,
      categoriaId: categoriaId ?? this.categoriaId,
      monto: monto ?? this.monto,
      moneda: moneda ?? this.moneda,
      tipo: tipo ?? this.tipo,
      concepto: concepto ?? this.concepto,
      metodoPago: metodoPago ?? this.metodoPago,
      esRecurrente: esRecurrente ?? this.esRecurrente,
      comprobanteUrl: comprobanteUrl ?? this.comprobanteUrl,
      fuenteCaptura: fuenteCaptura ?? this.fuenteCaptura,
      dataRaw: dataRaw ?? this.dataRaw,
      fecha: fecha ?? this.fecha,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cuentaId.present) {
      map['cuenta_id'] = Variable<String>(cuentaId.value);
    }
    if (categoriaId.present) {
      map['categoria_id'] = Variable<String>(categoriaId.value);
    }
    if (monto.present) {
      map['monto'] = Variable<double>(monto.value);
    }
    if (moneda.present) {
      map['moneda'] = Variable<String>(moneda.value);
    }
    if (tipo.present) {
      map['tipo'] = Variable<String>(tipo.value);
    }
    if (concepto.present) {
      map['concepto'] = Variable<String>(concepto.value);
    }
    if (metodoPago.present) {
      map['metodo_pago'] = Variable<String>(metodoPago.value);
    }
    if (esRecurrente.present) {
      map['es_recurrente'] = Variable<bool>(esRecurrente.value);
    }
    if (comprobanteUrl.present) {
      map['comprobante_url'] = Variable<String>(comprobanteUrl.value);
    }
    if (fuenteCaptura.present) {
      map['fuente_captura'] = Variable<String>(fuenteCaptura.value);
    }
    if (dataRaw.present) {
      map['data_raw'] = Variable<String>(dataRaw.value);
    }
    if (fecha.present) {
      map['fecha'] = Variable<DateTime>(fecha.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransaccionesCompanion(')
          ..write('id: $id, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('categoriaId: $categoriaId, ')
          ..write('monto: $monto, ')
          ..write('moneda: $moneda, ')
          ..write('tipo: $tipo, ')
          ..write('concepto: $concepto, ')
          ..write('metodoPago: $metodoPago, ')
          ..write('esRecurrente: $esRecurrente, ')
          ..write('comprobanteUrl: $comprobanteUrl, ')
          ..write('fuenteCaptura: $fuenteCaptura, ')
          ..write('dataRaw: $dataRaw, ')
          ..write('fecha: $fecha, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeudasTable extends Deudas with TableInfo<$DeudasTable, DeudaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeudasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreDeudaMeta = const VerificationMeta(
    'nombreDeuda',
  );
  @override
  late final GeneratedColumn<String> nombreDeuda = GeneratedColumn<String>(
    'nombre_deuda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoDeudaMeta = const VerificationMeta(
    'tipoDeuda',
  );
  @override
  late final GeneratedColumn<String> tipoDeuda = GeneratedColumn<String>(
    'tipo_deuda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tipoAcreedorMeta = const VerificationMeta(
    'tipoAcreedor',
  );
  @override
  late final GeneratedColumn<String> tipoAcreedor = GeneratedColumn<String>(
    'tipo_acreedor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreAcreedorMeta = const VerificationMeta(
    'nombreAcreedor',
  );
  @override
  late final GeneratedColumn<String> nombreAcreedor = GeneratedColumn<String>(
    'nombre_acreedor',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monedaMeta = const VerificationMeta('moneda');
  @override
  late final GeneratedColumn<String> moneda = GeneratedColumn<String>(
    'moneda',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoTotalMeta = const VerificationMeta(
    'montoTotal',
  );
  @override
  late final GeneratedColumn<double> montoTotal = GeneratedColumn<double>(
    'monto_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoPagadoMeta = const VerificationMeta(
    'montoPagado',
  );
  @override
  late final GeneratedColumn<double> montoPagado = GeneratedColumn<double>(
    'monto_pagado',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tieneInteresMeta = const VerificationMeta(
    'tieneInteres',
  );
  @override
  late final GeneratedColumn<bool> tieneInteres = GeneratedColumn<bool>(
    'tiene_interes',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("tiene_interes" IN (0, 1))',
    ),
  );
  static const VerificationMeta _tasaInteresMeta = const VerificationMeta(
    'tasaInteres',
  );
  @override
  late final GeneratedColumn<double> tasaInteres = GeneratedColumn<double>(
    'tasa_interes',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tipoTasaMeta = const VerificationMeta(
    'tipoTasa',
  );
  @override
  late final GeneratedColumn<String> tipoTasa = GeneratedColumn<String>(
    'tipo_tasa',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estructuraPagoMeta = const VerificationMeta(
    'estructuraPago',
  );
  @override
  late final GeneratedColumn<String> estructuraPago = GeneratedColumn<String>(
    'estructura_pago',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numeroCuotasTotalMeta = const VerificationMeta(
    'numeroCuotasTotal',
  );
  @override
  late final GeneratedColumn<int> numeroCuotasTotal = GeneratedColumn<int>(
    'numero_cuotas_total',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _numeroCuotasPagadasMeta =
      const VerificationMeta('numeroCuotasPagadas');
  @override
  late final GeneratedColumn<int> numeroCuotasPagadas = GeneratedColumn<int>(
    'numero_cuotas_pagadas',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _montoCuotaMeta = const VerificationMeta(
    'montoCuota',
  );
  @override
  late final GeneratedColumn<double> montoCuota = GeneratedColumn<double>(
    'monto_cuota',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pagoMinimoMeta = const VerificationMeta(
    'pagoMinimo',
  );
  @override
  late final GeneratedColumn<double> pagoMinimo = GeneratedColumn<double>(
    'pago_minimo',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _periodicidadCuotasMeta =
      const VerificationMeta('periodicidadCuotas');
  @override
  late final GeneratedColumn<String> periodicidadCuotas =
      GeneratedColumn<String>(
        'periodicidad_cuotas',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _interesTotalMeta = const VerificationMeta(
    'interesTotal',
  );
  @override
  late final GeneratedColumn<double> interesTotal = GeneratedColumn<double>(
    'interes_total',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fechaInicioMeta = const VerificationMeta(
    'fechaInicio',
  );
  @override
  late final GeneratedColumn<DateTime> fechaInicio = GeneratedColumn<DateTime>(
    'fecha_inicio',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fechaVencimientoFinalMeta =
      const VerificationMeta('fechaVencimientoFinal');
  @override
  late final GeneratedColumn<DateTime> fechaVencimientoFinal =
      GeneratedColumn<DateTime>(
        'fecha_vencimiento_final',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _diaPagoMeta = const VerificationMeta(
    'diaPago',
  );
  @override
  late final GeneratedColumn<int> diaPago = GeneratedColumn<int>(
    'dia_pago',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proximaFechaPagoMeta = const VerificationMeta(
    'proximaFechaPago',
  );
  @override
  late final GeneratedColumn<DateTime> proximaFechaPago =
      GeneratedColumn<DateTime>(
        'proxima_fecha_pago',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _enMoraMeta = const VerificationMeta('enMora');
  @override
  late final GeneratedColumn<bool> enMora = GeneratedColumn<bool>(
    'en_mora',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("en_mora" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _diasMoraMeta = const VerificationMeta(
    'diasMora',
  );
  @override
  late final GeneratedColumn<int> diasMora = GeneratedColumn<int>(
    'dias_mora',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tasaInteresMoratorioMeta =
      const VerificationMeta('tasaInteresMoratorio');
  @override
  late final GeneratedColumn<double> tasaInteresMoratorio =
      GeneratedColumn<double>(
        'tasa_interes_moratorio',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estadoMeta = const VerificationMeta('estado');
  @override
  late final GeneratedColumn<String> estado = GeneratedColumn<String>(
    'estado',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notasMeta = const VerificationMeta('notas');
  @override
  late final GeneratedColumn<String> notas = GeneratedColumn<String>(
    'notas',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombreDeuda,
    tipoDeuda,
    tipoAcreedor,
    nombreAcreedor,
    moneda,
    montoTotal,
    montoPagado,
    tieneInteres,
    tasaInteres,
    tipoTasa,
    estructuraPago,
    numeroCuotasTotal,
    numeroCuotasPagadas,
    montoCuota,
    pagoMinimo,
    periodicidadCuotas,
    interesTotal,
    fechaInicio,
    fechaVencimientoFinal,
    diaPago,
    proximaFechaPago,
    enMora,
    diasMora,
    tasaInteresMoratorio,
    estado,
    notas,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deudas';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeudaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre_deuda')) {
      context.handle(
        _nombreDeudaMeta,
        nombreDeuda.isAcceptableOrUnknown(
          data['nombre_deuda']!,
          _nombreDeudaMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nombreDeudaMeta);
    }
    if (data.containsKey('tipo_deuda')) {
      context.handle(
        _tipoDeudaMeta,
        tipoDeuda.isAcceptableOrUnknown(data['tipo_deuda']!, _tipoDeudaMeta),
      );
    } else if (isInserting) {
      context.missing(_tipoDeudaMeta);
    }
    if (data.containsKey('tipo_acreedor')) {
      context.handle(
        _tipoAcreedorMeta,
        tipoAcreedor.isAcceptableOrUnknown(
          data['tipo_acreedor']!,
          _tipoAcreedorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tipoAcreedorMeta);
    }
    if (data.containsKey('nombre_acreedor')) {
      context.handle(
        _nombreAcreedorMeta,
        nombreAcreedor.isAcceptableOrUnknown(
          data['nombre_acreedor']!,
          _nombreAcreedorMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nombreAcreedorMeta);
    }
    if (data.containsKey('moneda')) {
      context.handle(
        _monedaMeta,
        moneda.isAcceptableOrUnknown(data['moneda']!, _monedaMeta),
      );
    } else if (isInserting) {
      context.missing(_monedaMeta);
    }
    if (data.containsKey('monto_total')) {
      context.handle(
        _montoTotalMeta,
        montoTotal.isAcceptableOrUnknown(data['monto_total']!, _montoTotalMeta),
      );
    } else if (isInserting) {
      context.missing(_montoTotalMeta);
    }
    if (data.containsKey('monto_pagado')) {
      context.handle(
        _montoPagadoMeta,
        montoPagado.isAcceptableOrUnknown(
          data['monto_pagado']!,
          _montoPagadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoPagadoMeta);
    }
    if (data.containsKey('tiene_interes')) {
      context.handle(
        _tieneInteresMeta,
        tieneInteres.isAcceptableOrUnknown(
          data['tiene_interes']!,
          _tieneInteresMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tieneInteresMeta);
    }
    if (data.containsKey('tasa_interes')) {
      context.handle(
        _tasaInteresMeta,
        tasaInteres.isAcceptableOrUnknown(
          data['tasa_interes']!,
          _tasaInteresMeta,
        ),
      );
    }
    if (data.containsKey('tipo_tasa')) {
      context.handle(
        _tipoTasaMeta,
        tipoTasa.isAcceptableOrUnknown(data['tipo_tasa']!, _tipoTasaMeta),
      );
    }
    if (data.containsKey('estructura_pago')) {
      context.handle(
        _estructuraPagoMeta,
        estructuraPago.isAcceptableOrUnknown(
          data['estructura_pago']!,
          _estructuraPagoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estructuraPagoMeta);
    }
    if (data.containsKey('numero_cuotas_total')) {
      context.handle(
        _numeroCuotasTotalMeta,
        numeroCuotasTotal.isAcceptableOrUnknown(
          data['numero_cuotas_total']!,
          _numeroCuotasTotalMeta,
        ),
      );
    }
    if (data.containsKey('numero_cuotas_pagadas')) {
      context.handle(
        _numeroCuotasPagadasMeta,
        numeroCuotasPagadas.isAcceptableOrUnknown(
          data['numero_cuotas_pagadas']!,
          _numeroCuotasPagadasMeta,
        ),
      );
    }
    if (data.containsKey('monto_cuota')) {
      context.handle(
        _montoCuotaMeta,
        montoCuota.isAcceptableOrUnknown(data['monto_cuota']!, _montoCuotaMeta),
      );
    }
    if (data.containsKey('pago_minimo')) {
      context.handle(
        _pagoMinimoMeta,
        pagoMinimo.isAcceptableOrUnknown(data['pago_minimo']!, _pagoMinimoMeta),
      );
    }
    if (data.containsKey('periodicidad_cuotas')) {
      context.handle(
        _periodicidadCuotasMeta,
        periodicidadCuotas.isAcceptableOrUnknown(
          data['periodicidad_cuotas']!,
          _periodicidadCuotasMeta,
        ),
      );
    }
    if (data.containsKey('interes_total')) {
      context.handle(
        _interesTotalMeta,
        interesTotal.isAcceptableOrUnknown(
          data['interes_total']!,
          _interesTotalMeta,
        ),
      );
    }
    if (data.containsKey('fecha_inicio')) {
      context.handle(
        _fechaInicioMeta,
        fechaInicio.isAcceptableOrUnknown(
          data['fecha_inicio']!,
          _fechaInicioMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fechaInicioMeta);
    }
    if (data.containsKey('fecha_vencimiento_final')) {
      context.handle(
        _fechaVencimientoFinalMeta,
        fechaVencimientoFinal.isAcceptableOrUnknown(
          data['fecha_vencimiento_final']!,
          _fechaVencimientoFinalMeta,
        ),
      );
    }
    if (data.containsKey('dia_pago')) {
      context.handle(
        _diaPagoMeta,
        diaPago.isAcceptableOrUnknown(data['dia_pago']!, _diaPagoMeta),
      );
    }
    if (data.containsKey('proxima_fecha_pago')) {
      context.handle(
        _proximaFechaPagoMeta,
        proximaFechaPago.isAcceptableOrUnknown(
          data['proxima_fecha_pago']!,
          _proximaFechaPagoMeta,
        ),
      );
    }
    if (data.containsKey('en_mora')) {
      context.handle(
        _enMoraMeta,
        enMora.isAcceptableOrUnknown(data['en_mora']!, _enMoraMeta),
      );
    }
    if (data.containsKey('dias_mora')) {
      context.handle(
        _diasMoraMeta,
        diasMora.isAcceptableOrUnknown(data['dias_mora']!, _diasMoraMeta),
      );
    }
    if (data.containsKey('tasa_interes_moratorio')) {
      context.handle(
        _tasaInteresMoratorioMeta,
        tasaInteresMoratorio.isAcceptableOrUnknown(
          data['tasa_interes_moratorio']!,
          _tasaInteresMoratorioMeta,
        ),
      );
    }
    if (data.containsKey('estado')) {
      context.handle(
        _estadoMeta,
        estado.isAcceptableOrUnknown(data['estado']!, _estadoMeta),
      );
    } else if (isInserting) {
      context.missing(_estadoMeta);
    }
    if (data.containsKey('notas')) {
      context.handle(
        _notasMeta,
        notas.isAcceptableOrUnknown(data['notas']!, _notasMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeudaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeudaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombreDeuda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre_deuda'],
      )!,
      tipoDeuda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_deuda'],
      )!,
      tipoAcreedor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_acreedor'],
      )!,
      nombreAcreedor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre_acreedor'],
      )!,
      moneda: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}moneda'],
      )!,
      montoTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_total'],
      )!,
      montoPagado: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_pagado'],
      )!,
      tieneInteres: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}tiene_interes'],
      )!,
      tasaInteres: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tasa_interes'],
      ),
      tipoTasa: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tipo_tasa'],
      ),
      estructuraPago: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estructura_pago'],
      )!,
      numeroCuotasTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero_cuotas_total'],
      ),
      numeroCuotasPagadas: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero_cuotas_pagadas'],
      ),
      montoCuota: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_cuota'],
      ),
      pagoMinimo: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pago_minimo'],
      ),
      periodicidadCuotas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}periodicidad_cuotas'],
      ),
      interesTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interes_total'],
      ),
      fechaInicio: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha_inicio'],
      )!,
      fechaVencimientoFinal: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha_vencimiento_final'],
      ),
      diaPago: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dia_pago'],
      ),
      proximaFechaPago: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}proxima_fecha_pago'],
      ),
      enMora: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}en_mora'],
      )!,
      diasMora: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dias_mora'],
      ),
      tasaInteresMoratorio: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tasa_interes_moratorio'],
      ),
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      notas: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notas'],
      ),
    );
  }

  @override
  $DeudasTable createAlias(String alias) {
    return $DeudasTable(attachedDatabase, alias);
  }
}

class DeudaRow extends DataClass implements Insertable<DeudaRow> {
  final String id;
  final String nombreDeuda;
  final String tipoDeuda;
  final String tipoAcreedor;
  final String nombreAcreedor;
  final String moneda;
  final double montoTotal;
  final double montoPagado;
  final bool tieneInteres;
  final double? tasaInteres;
  final String? tipoTasa;
  final String estructuraPago;
  final int? numeroCuotasTotal;
  final int? numeroCuotasPagadas;
  final double? montoCuota;
  final double? pagoMinimo;
  final String? periodicidadCuotas;
  final double? interesTotal;
  final DateTime fechaInicio;
  final DateTime? fechaVencimientoFinal;
  final int? diaPago;
  final DateTime? proximaFechaPago;
  final bool enMora;
  final int? diasMora;
  final double? tasaInteresMoratorio;
  final String estado;
  final String? notas;
  const DeudaRow({
    required this.id,
    required this.nombreDeuda,
    required this.tipoDeuda,
    required this.tipoAcreedor,
    required this.nombreAcreedor,
    required this.moneda,
    required this.montoTotal,
    required this.montoPagado,
    required this.tieneInteres,
    this.tasaInteres,
    this.tipoTasa,
    required this.estructuraPago,
    this.numeroCuotasTotal,
    this.numeroCuotasPagadas,
    this.montoCuota,
    this.pagoMinimo,
    this.periodicidadCuotas,
    this.interesTotal,
    required this.fechaInicio,
    this.fechaVencimientoFinal,
    this.diaPago,
    this.proximaFechaPago,
    required this.enMora,
    this.diasMora,
    this.tasaInteresMoratorio,
    required this.estado,
    this.notas,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre_deuda'] = Variable<String>(nombreDeuda);
    map['tipo_deuda'] = Variable<String>(tipoDeuda);
    map['tipo_acreedor'] = Variable<String>(tipoAcreedor);
    map['nombre_acreedor'] = Variable<String>(nombreAcreedor);
    map['moneda'] = Variable<String>(moneda);
    map['monto_total'] = Variable<double>(montoTotal);
    map['monto_pagado'] = Variable<double>(montoPagado);
    map['tiene_interes'] = Variable<bool>(tieneInteres);
    if (!nullToAbsent || tasaInteres != null) {
      map['tasa_interes'] = Variable<double>(tasaInteres);
    }
    if (!nullToAbsent || tipoTasa != null) {
      map['tipo_tasa'] = Variable<String>(tipoTasa);
    }
    map['estructura_pago'] = Variable<String>(estructuraPago);
    if (!nullToAbsent || numeroCuotasTotal != null) {
      map['numero_cuotas_total'] = Variable<int>(numeroCuotasTotal);
    }
    if (!nullToAbsent || numeroCuotasPagadas != null) {
      map['numero_cuotas_pagadas'] = Variable<int>(numeroCuotasPagadas);
    }
    if (!nullToAbsent || montoCuota != null) {
      map['monto_cuota'] = Variable<double>(montoCuota);
    }
    if (!nullToAbsent || pagoMinimo != null) {
      map['pago_minimo'] = Variable<double>(pagoMinimo);
    }
    if (!nullToAbsent || periodicidadCuotas != null) {
      map['periodicidad_cuotas'] = Variable<String>(periodicidadCuotas);
    }
    if (!nullToAbsent || interesTotal != null) {
      map['interes_total'] = Variable<double>(interesTotal);
    }
    map['fecha_inicio'] = Variable<DateTime>(fechaInicio);
    if (!nullToAbsent || fechaVencimientoFinal != null) {
      map['fecha_vencimiento_final'] = Variable<DateTime>(
        fechaVencimientoFinal,
      );
    }
    if (!nullToAbsent || diaPago != null) {
      map['dia_pago'] = Variable<int>(diaPago);
    }
    if (!nullToAbsent || proximaFechaPago != null) {
      map['proxima_fecha_pago'] = Variable<DateTime>(proximaFechaPago);
    }
    map['en_mora'] = Variable<bool>(enMora);
    if (!nullToAbsent || diasMora != null) {
      map['dias_mora'] = Variable<int>(diasMora);
    }
    if (!nullToAbsent || tasaInteresMoratorio != null) {
      map['tasa_interes_moratorio'] = Variable<double>(tasaInteresMoratorio);
    }
    map['estado'] = Variable<String>(estado);
    if (!nullToAbsent || notas != null) {
      map['notas'] = Variable<String>(notas);
    }
    return map;
  }

  DeudasCompanion toCompanion(bool nullToAbsent) {
    return DeudasCompanion(
      id: Value(id),
      nombreDeuda: Value(nombreDeuda),
      tipoDeuda: Value(tipoDeuda),
      tipoAcreedor: Value(tipoAcreedor),
      nombreAcreedor: Value(nombreAcreedor),
      moneda: Value(moneda),
      montoTotal: Value(montoTotal),
      montoPagado: Value(montoPagado),
      tieneInteres: Value(tieneInteres),
      tasaInteres: tasaInteres == null && nullToAbsent
          ? const Value.absent()
          : Value(tasaInteres),
      tipoTasa: tipoTasa == null && nullToAbsent
          ? const Value.absent()
          : Value(tipoTasa),
      estructuraPago: Value(estructuraPago),
      numeroCuotasTotal: numeroCuotasTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(numeroCuotasTotal),
      numeroCuotasPagadas: numeroCuotasPagadas == null && nullToAbsent
          ? const Value.absent()
          : Value(numeroCuotasPagadas),
      montoCuota: montoCuota == null && nullToAbsent
          ? const Value.absent()
          : Value(montoCuota),
      pagoMinimo: pagoMinimo == null && nullToAbsent
          ? const Value.absent()
          : Value(pagoMinimo),
      periodicidadCuotas: periodicidadCuotas == null && nullToAbsent
          ? const Value.absent()
          : Value(periodicidadCuotas),
      interesTotal: interesTotal == null && nullToAbsent
          ? const Value.absent()
          : Value(interesTotal),
      fechaInicio: Value(fechaInicio),
      fechaVencimientoFinal: fechaVencimientoFinal == null && nullToAbsent
          ? const Value.absent()
          : Value(fechaVencimientoFinal),
      diaPago: diaPago == null && nullToAbsent
          ? const Value.absent()
          : Value(diaPago),
      proximaFechaPago: proximaFechaPago == null && nullToAbsent
          ? const Value.absent()
          : Value(proximaFechaPago),
      enMora: Value(enMora),
      diasMora: diasMora == null && nullToAbsent
          ? const Value.absent()
          : Value(diasMora),
      tasaInteresMoratorio: tasaInteresMoratorio == null && nullToAbsent
          ? const Value.absent()
          : Value(tasaInteresMoratorio),
      estado: Value(estado),
      notas: notas == null && nullToAbsent
          ? const Value.absent()
          : Value(notas),
    );
  }

  factory DeudaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeudaRow(
      id: serializer.fromJson<String>(json['id']),
      nombreDeuda: serializer.fromJson<String>(json['nombreDeuda']),
      tipoDeuda: serializer.fromJson<String>(json['tipoDeuda']),
      tipoAcreedor: serializer.fromJson<String>(json['tipoAcreedor']),
      nombreAcreedor: serializer.fromJson<String>(json['nombreAcreedor']),
      moneda: serializer.fromJson<String>(json['moneda']),
      montoTotal: serializer.fromJson<double>(json['montoTotal']),
      montoPagado: serializer.fromJson<double>(json['montoPagado']),
      tieneInteres: serializer.fromJson<bool>(json['tieneInteres']),
      tasaInteres: serializer.fromJson<double?>(json['tasaInteres']),
      tipoTasa: serializer.fromJson<String?>(json['tipoTasa']),
      estructuraPago: serializer.fromJson<String>(json['estructuraPago']),
      numeroCuotasTotal: serializer.fromJson<int?>(json['numeroCuotasTotal']),
      numeroCuotasPagadas: serializer.fromJson<int?>(
        json['numeroCuotasPagadas'],
      ),
      montoCuota: serializer.fromJson<double?>(json['montoCuota']),
      pagoMinimo: serializer.fromJson<double?>(json['pagoMinimo']),
      periodicidadCuotas: serializer.fromJson<String?>(
        json['periodicidadCuotas'],
      ),
      interesTotal: serializer.fromJson<double?>(json['interesTotal']),
      fechaInicio: serializer.fromJson<DateTime>(json['fechaInicio']),
      fechaVencimientoFinal: serializer.fromJson<DateTime?>(
        json['fechaVencimientoFinal'],
      ),
      diaPago: serializer.fromJson<int?>(json['diaPago']),
      proximaFechaPago: serializer.fromJson<DateTime?>(
        json['proximaFechaPago'],
      ),
      enMora: serializer.fromJson<bool>(json['enMora']),
      diasMora: serializer.fromJson<int?>(json['diasMora']),
      tasaInteresMoratorio: serializer.fromJson<double?>(
        json['tasaInteresMoratorio'],
      ),
      estado: serializer.fromJson<String>(json['estado']),
      notas: serializer.fromJson<String?>(json['notas']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombreDeuda': serializer.toJson<String>(nombreDeuda),
      'tipoDeuda': serializer.toJson<String>(tipoDeuda),
      'tipoAcreedor': serializer.toJson<String>(tipoAcreedor),
      'nombreAcreedor': serializer.toJson<String>(nombreAcreedor),
      'moneda': serializer.toJson<String>(moneda),
      'montoTotal': serializer.toJson<double>(montoTotal),
      'montoPagado': serializer.toJson<double>(montoPagado),
      'tieneInteres': serializer.toJson<bool>(tieneInteres),
      'tasaInteres': serializer.toJson<double?>(tasaInteres),
      'tipoTasa': serializer.toJson<String?>(tipoTasa),
      'estructuraPago': serializer.toJson<String>(estructuraPago),
      'numeroCuotasTotal': serializer.toJson<int?>(numeroCuotasTotal),
      'numeroCuotasPagadas': serializer.toJson<int?>(numeroCuotasPagadas),
      'montoCuota': serializer.toJson<double?>(montoCuota),
      'pagoMinimo': serializer.toJson<double?>(pagoMinimo),
      'periodicidadCuotas': serializer.toJson<String?>(periodicidadCuotas),
      'interesTotal': serializer.toJson<double?>(interesTotal),
      'fechaInicio': serializer.toJson<DateTime>(fechaInicio),
      'fechaVencimientoFinal': serializer.toJson<DateTime?>(
        fechaVencimientoFinal,
      ),
      'diaPago': serializer.toJson<int?>(diaPago),
      'proximaFechaPago': serializer.toJson<DateTime?>(proximaFechaPago),
      'enMora': serializer.toJson<bool>(enMora),
      'diasMora': serializer.toJson<int?>(diasMora),
      'tasaInteresMoratorio': serializer.toJson<double?>(tasaInteresMoratorio),
      'estado': serializer.toJson<String>(estado),
      'notas': serializer.toJson<String?>(notas),
    };
  }

  DeudaRow copyWith({
    String? id,
    String? nombreDeuda,
    String? tipoDeuda,
    String? tipoAcreedor,
    String? nombreAcreedor,
    String? moneda,
    double? montoTotal,
    double? montoPagado,
    bool? tieneInteres,
    Value<double?> tasaInteres = const Value.absent(),
    Value<String?> tipoTasa = const Value.absent(),
    String? estructuraPago,
    Value<int?> numeroCuotasTotal = const Value.absent(),
    Value<int?> numeroCuotasPagadas = const Value.absent(),
    Value<double?> montoCuota = const Value.absent(),
    Value<double?> pagoMinimo = const Value.absent(),
    Value<String?> periodicidadCuotas = const Value.absent(),
    Value<double?> interesTotal = const Value.absent(),
    DateTime? fechaInicio,
    Value<DateTime?> fechaVencimientoFinal = const Value.absent(),
    Value<int?> diaPago = const Value.absent(),
    Value<DateTime?> proximaFechaPago = const Value.absent(),
    bool? enMora,
    Value<int?> diasMora = const Value.absent(),
    Value<double?> tasaInteresMoratorio = const Value.absent(),
    String? estado,
    Value<String?> notas = const Value.absent(),
  }) => DeudaRow(
    id: id ?? this.id,
    nombreDeuda: nombreDeuda ?? this.nombreDeuda,
    tipoDeuda: tipoDeuda ?? this.tipoDeuda,
    tipoAcreedor: tipoAcreedor ?? this.tipoAcreedor,
    nombreAcreedor: nombreAcreedor ?? this.nombreAcreedor,
    moneda: moneda ?? this.moneda,
    montoTotal: montoTotal ?? this.montoTotal,
    montoPagado: montoPagado ?? this.montoPagado,
    tieneInteres: tieneInteres ?? this.tieneInteres,
    tasaInteres: tasaInteres.present ? tasaInteres.value : this.tasaInteres,
    tipoTasa: tipoTasa.present ? tipoTasa.value : this.tipoTasa,
    estructuraPago: estructuraPago ?? this.estructuraPago,
    numeroCuotasTotal: numeroCuotasTotal.present
        ? numeroCuotasTotal.value
        : this.numeroCuotasTotal,
    numeroCuotasPagadas: numeroCuotasPagadas.present
        ? numeroCuotasPagadas.value
        : this.numeroCuotasPagadas,
    montoCuota: montoCuota.present ? montoCuota.value : this.montoCuota,
    pagoMinimo: pagoMinimo.present ? pagoMinimo.value : this.pagoMinimo,
    periodicidadCuotas: periodicidadCuotas.present
        ? periodicidadCuotas.value
        : this.periodicidadCuotas,
    interesTotal: interesTotal.present ? interesTotal.value : this.interesTotal,
    fechaInicio: fechaInicio ?? this.fechaInicio,
    fechaVencimientoFinal: fechaVencimientoFinal.present
        ? fechaVencimientoFinal.value
        : this.fechaVencimientoFinal,
    diaPago: diaPago.present ? diaPago.value : this.diaPago,
    proximaFechaPago: proximaFechaPago.present
        ? proximaFechaPago.value
        : this.proximaFechaPago,
    enMora: enMora ?? this.enMora,
    diasMora: diasMora.present ? diasMora.value : this.diasMora,
    tasaInteresMoratorio: tasaInteresMoratorio.present
        ? tasaInteresMoratorio.value
        : this.tasaInteresMoratorio,
    estado: estado ?? this.estado,
    notas: notas.present ? notas.value : this.notas,
  );
  DeudaRow copyWithCompanion(DeudasCompanion data) {
    return DeudaRow(
      id: data.id.present ? data.id.value : this.id,
      nombreDeuda: data.nombreDeuda.present
          ? data.nombreDeuda.value
          : this.nombreDeuda,
      tipoDeuda: data.tipoDeuda.present ? data.tipoDeuda.value : this.tipoDeuda,
      tipoAcreedor: data.tipoAcreedor.present
          ? data.tipoAcreedor.value
          : this.tipoAcreedor,
      nombreAcreedor: data.nombreAcreedor.present
          ? data.nombreAcreedor.value
          : this.nombreAcreedor,
      moneda: data.moneda.present ? data.moneda.value : this.moneda,
      montoTotal: data.montoTotal.present
          ? data.montoTotal.value
          : this.montoTotal,
      montoPagado: data.montoPagado.present
          ? data.montoPagado.value
          : this.montoPagado,
      tieneInteres: data.tieneInteres.present
          ? data.tieneInteres.value
          : this.tieneInteres,
      tasaInteres: data.tasaInteres.present
          ? data.tasaInteres.value
          : this.tasaInteres,
      tipoTasa: data.tipoTasa.present ? data.tipoTasa.value : this.tipoTasa,
      estructuraPago: data.estructuraPago.present
          ? data.estructuraPago.value
          : this.estructuraPago,
      numeroCuotasTotal: data.numeroCuotasTotal.present
          ? data.numeroCuotasTotal.value
          : this.numeroCuotasTotal,
      numeroCuotasPagadas: data.numeroCuotasPagadas.present
          ? data.numeroCuotasPagadas.value
          : this.numeroCuotasPagadas,
      montoCuota: data.montoCuota.present
          ? data.montoCuota.value
          : this.montoCuota,
      pagoMinimo: data.pagoMinimo.present
          ? data.pagoMinimo.value
          : this.pagoMinimo,
      periodicidadCuotas: data.periodicidadCuotas.present
          ? data.periodicidadCuotas.value
          : this.periodicidadCuotas,
      interesTotal: data.interesTotal.present
          ? data.interesTotal.value
          : this.interesTotal,
      fechaInicio: data.fechaInicio.present
          ? data.fechaInicio.value
          : this.fechaInicio,
      fechaVencimientoFinal: data.fechaVencimientoFinal.present
          ? data.fechaVencimientoFinal.value
          : this.fechaVencimientoFinal,
      diaPago: data.diaPago.present ? data.diaPago.value : this.diaPago,
      proximaFechaPago: data.proximaFechaPago.present
          ? data.proximaFechaPago.value
          : this.proximaFechaPago,
      enMora: data.enMora.present ? data.enMora.value : this.enMora,
      diasMora: data.diasMora.present ? data.diasMora.value : this.diasMora,
      tasaInteresMoratorio: data.tasaInteresMoratorio.present
          ? data.tasaInteresMoratorio.value
          : this.tasaInteresMoratorio,
      estado: data.estado.present ? data.estado.value : this.estado,
      notas: data.notas.present ? data.notas.value : this.notas,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeudaRow(')
          ..write('id: $id, ')
          ..write('nombreDeuda: $nombreDeuda, ')
          ..write('tipoDeuda: $tipoDeuda, ')
          ..write('tipoAcreedor: $tipoAcreedor, ')
          ..write('nombreAcreedor: $nombreAcreedor, ')
          ..write('moneda: $moneda, ')
          ..write('montoTotal: $montoTotal, ')
          ..write('montoPagado: $montoPagado, ')
          ..write('tieneInteres: $tieneInteres, ')
          ..write('tasaInteres: $tasaInteres, ')
          ..write('tipoTasa: $tipoTasa, ')
          ..write('estructuraPago: $estructuraPago, ')
          ..write('numeroCuotasTotal: $numeroCuotasTotal, ')
          ..write('numeroCuotasPagadas: $numeroCuotasPagadas, ')
          ..write('montoCuota: $montoCuota, ')
          ..write('pagoMinimo: $pagoMinimo, ')
          ..write('periodicidadCuotas: $periodicidadCuotas, ')
          ..write('interesTotal: $interesTotal, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('fechaVencimientoFinal: $fechaVencimientoFinal, ')
          ..write('diaPago: $diaPago, ')
          ..write('proximaFechaPago: $proximaFechaPago, ')
          ..write('enMora: $enMora, ')
          ..write('diasMora: $diasMora, ')
          ..write('tasaInteresMoratorio: $tasaInteresMoratorio, ')
          ..write('estado: $estado, ')
          ..write('notas: $notas')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    nombreDeuda,
    tipoDeuda,
    tipoAcreedor,
    nombreAcreedor,
    moneda,
    montoTotal,
    montoPagado,
    tieneInteres,
    tasaInteres,
    tipoTasa,
    estructuraPago,
    numeroCuotasTotal,
    numeroCuotasPagadas,
    montoCuota,
    pagoMinimo,
    periodicidadCuotas,
    interesTotal,
    fechaInicio,
    fechaVencimientoFinal,
    diaPago,
    proximaFechaPago,
    enMora,
    diasMora,
    tasaInteresMoratorio,
    estado,
    notas,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeudaRow &&
          other.id == this.id &&
          other.nombreDeuda == this.nombreDeuda &&
          other.tipoDeuda == this.tipoDeuda &&
          other.tipoAcreedor == this.tipoAcreedor &&
          other.nombreAcreedor == this.nombreAcreedor &&
          other.moneda == this.moneda &&
          other.montoTotal == this.montoTotal &&
          other.montoPagado == this.montoPagado &&
          other.tieneInteres == this.tieneInteres &&
          other.tasaInteres == this.tasaInteres &&
          other.tipoTasa == this.tipoTasa &&
          other.estructuraPago == this.estructuraPago &&
          other.numeroCuotasTotal == this.numeroCuotasTotal &&
          other.numeroCuotasPagadas == this.numeroCuotasPagadas &&
          other.montoCuota == this.montoCuota &&
          other.pagoMinimo == this.pagoMinimo &&
          other.periodicidadCuotas == this.periodicidadCuotas &&
          other.interesTotal == this.interesTotal &&
          other.fechaInicio == this.fechaInicio &&
          other.fechaVencimientoFinal == this.fechaVencimientoFinal &&
          other.diaPago == this.diaPago &&
          other.proximaFechaPago == this.proximaFechaPago &&
          other.enMora == this.enMora &&
          other.diasMora == this.diasMora &&
          other.tasaInteresMoratorio == this.tasaInteresMoratorio &&
          other.estado == this.estado &&
          other.notas == this.notas);
}

class DeudasCompanion extends UpdateCompanion<DeudaRow> {
  final Value<String> id;
  final Value<String> nombreDeuda;
  final Value<String> tipoDeuda;
  final Value<String> tipoAcreedor;
  final Value<String> nombreAcreedor;
  final Value<String> moneda;
  final Value<double> montoTotal;
  final Value<double> montoPagado;
  final Value<bool> tieneInteres;
  final Value<double?> tasaInteres;
  final Value<String?> tipoTasa;
  final Value<String> estructuraPago;
  final Value<int?> numeroCuotasTotal;
  final Value<int?> numeroCuotasPagadas;
  final Value<double?> montoCuota;
  final Value<double?> pagoMinimo;
  final Value<String?> periodicidadCuotas;
  final Value<double?> interesTotal;
  final Value<DateTime> fechaInicio;
  final Value<DateTime?> fechaVencimientoFinal;
  final Value<int?> diaPago;
  final Value<DateTime?> proximaFechaPago;
  final Value<bool> enMora;
  final Value<int?> diasMora;
  final Value<double?> tasaInteresMoratorio;
  final Value<String> estado;
  final Value<String?> notas;
  final Value<int> rowid;
  const DeudasCompanion({
    this.id = const Value.absent(),
    this.nombreDeuda = const Value.absent(),
    this.tipoDeuda = const Value.absent(),
    this.tipoAcreedor = const Value.absent(),
    this.nombreAcreedor = const Value.absent(),
    this.moneda = const Value.absent(),
    this.montoTotal = const Value.absent(),
    this.montoPagado = const Value.absent(),
    this.tieneInteres = const Value.absent(),
    this.tasaInteres = const Value.absent(),
    this.tipoTasa = const Value.absent(),
    this.estructuraPago = const Value.absent(),
    this.numeroCuotasTotal = const Value.absent(),
    this.numeroCuotasPagadas = const Value.absent(),
    this.montoCuota = const Value.absent(),
    this.pagoMinimo = const Value.absent(),
    this.periodicidadCuotas = const Value.absent(),
    this.interesTotal = const Value.absent(),
    this.fechaInicio = const Value.absent(),
    this.fechaVencimientoFinal = const Value.absent(),
    this.diaPago = const Value.absent(),
    this.proximaFechaPago = const Value.absent(),
    this.enMora = const Value.absent(),
    this.diasMora = const Value.absent(),
    this.tasaInteresMoratorio = const Value.absent(),
    this.estado = const Value.absent(),
    this.notas = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeudasCompanion.insert({
    required String id,
    required String nombreDeuda,
    required String tipoDeuda,
    required String tipoAcreedor,
    required String nombreAcreedor,
    required String moneda,
    required double montoTotal,
    required double montoPagado,
    required bool tieneInteres,
    this.tasaInteres = const Value.absent(),
    this.tipoTasa = const Value.absent(),
    required String estructuraPago,
    this.numeroCuotasTotal = const Value.absent(),
    this.numeroCuotasPagadas = const Value.absent(),
    this.montoCuota = const Value.absent(),
    this.pagoMinimo = const Value.absent(),
    this.periodicidadCuotas = const Value.absent(),
    this.interesTotal = const Value.absent(),
    required DateTime fechaInicio,
    this.fechaVencimientoFinal = const Value.absent(),
    this.diaPago = const Value.absent(),
    this.proximaFechaPago = const Value.absent(),
    this.enMora = const Value.absent(),
    this.diasMora = const Value.absent(),
    this.tasaInteresMoratorio = const Value.absent(),
    required String estado,
    this.notas = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombreDeuda = Value(nombreDeuda),
       tipoDeuda = Value(tipoDeuda),
       tipoAcreedor = Value(tipoAcreedor),
       nombreAcreedor = Value(nombreAcreedor),
       moneda = Value(moneda),
       montoTotal = Value(montoTotal),
       montoPagado = Value(montoPagado),
       tieneInteres = Value(tieneInteres),
       estructuraPago = Value(estructuraPago),
       fechaInicio = Value(fechaInicio),
       estado = Value(estado);
  static Insertable<DeudaRow> custom({
    Expression<String>? id,
    Expression<String>? nombreDeuda,
    Expression<String>? tipoDeuda,
    Expression<String>? tipoAcreedor,
    Expression<String>? nombreAcreedor,
    Expression<String>? moneda,
    Expression<double>? montoTotal,
    Expression<double>? montoPagado,
    Expression<bool>? tieneInteres,
    Expression<double>? tasaInteres,
    Expression<String>? tipoTasa,
    Expression<String>? estructuraPago,
    Expression<int>? numeroCuotasTotal,
    Expression<int>? numeroCuotasPagadas,
    Expression<double>? montoCuota,
    Expression<double>? pagoMinimo,
    Expression<String>? periodicidadCuotas,
    Expression<double>? interesTotal,
    Expression<DateTime>? fechaInicio,
    Expression<DateTime>? fechaVencimientoFinal,
    Expression<int>? diaPago,
    Expression<DateTime>? proximaFechaPago,
    Expression<bool>? enMora,
    Expression<int>? diasMora,
    Expression<double>? tasaInteresMoratorio,
    Expression<String>? estado,
    Expression<String>? notas,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombreDeuda != null) 'nombre_deuda': nombreDeuda,
      if (tipoDeuda != null) 'tipo_deuda': tipoDeuda,
      if (tipoAcreedor != null) 'tipo_acreedor': tipoAcreedor,
      if (nombreAcreedor != null) 'nombre_acreedor': nombreAcreedor,
      if (moneda != null) 'moneda': moneda,
      if (montoTotal != null) 'monto_total': montoTotal,
      if (montoPagado != null) 'monto_pagado': montoPagado,
      if (tieneInteres != null) 'tiene_interes': tieneInteres,
      if (tasaInteres != null) 'tasa_interes': tasaInteres,
      if (tipoTasa != null) 'tipo_tasa': tipoTasa,
      if (estructuraPago != null) 'estructura_pago': estructuraPago,
      if (numeroCuotasTotal != null) 'numero_cuotas_total': numeroCuotasTotal,
      if (numeroCuotasPagadas != null)
        'numero_cuotas_pagadas': numeroCuotasPagadas,
      if (montoCuota != null) 'monto_cuota': montoCuota,
      if (pagoMinimo != null) 'pago_minimo': pagoMinimo,
      if (periodicidadCuotas != null) 'periodicidad_cuotas': periodicidadCuotas,
      if (interesTotal != null) 'interes_total': interesTotal,
      if (fechaInicio != null) 'fecha_inicio': fechaInicio,
      if (fechaVencimientoFinal != null)
        'fecha_vencimiento_final': fechaVencimientoFinal,
      if (diaPago != null) 'dia_pago': diaPago,
      if (proximaFechaPago != null) 'proxima_fecha_pago': proximaFechaPago,
      if (enMora != null) 'en_mora': enMora,
      if (diasMora != null) 'dias_mora': diasMora,
      if (tasaInteresMoratorio != null)
        'tasa_interes_moratorio': tasaInteresMoratorio,
      if (estado != null) 'estado': estado,
      if (notas != null) 'notas': notas,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeudasCompanion copyWith({
    Value<String>? id,
    Value<String>? nombreDeuda,
    Value<String>? tipoDeuda,
    Value<String>? tipoAcreedor,
    Value<String>? nombreAcreedor,
    Value<String>? moneda,
    Value<double>? montoTotal,
    Value<double>? montoPagado,
    Value<bool>? tieneInteres,
    Value<double?>? tasaInteres,
    Value<String?>? tipoTasa,
    Value<String>? estructuraPago,
    Value<int?>? numeroCuotasTotal,
    Value<int?>? numeroCuotasPagadas,
    Value<double?>? montoCuota,
    Value<double?>? pagoMinimo,
    Value<String?>? periodicidadCuotas,
    Value<double?>? interesTotal,
    Value<DateTime>? fechaInicio,
    Value<DateTime?>? fechaVencimientoFinal,
    Value<int?>? diaPago,
    Value<DateTime?>? proximaFechaPago,
    Value<bool>? enMora,
    Value<int?>? diasMora,
    Value<double?>? tasaInteresMoratorio,
    Value<String>? estado,
    Value<String?>? notas,
    Value<int>? rowid,
  }) {
    return DeudasCompanion(
      id: id ?? this.id,
      nombreDeuda: nombreDeuda ?? this.nombreDeuda,
      tipoDeuda: tipoDeuda ?? this.tipoDeuda,
      tipoAcreedor: tipoAcreedor ?? this.tipoAcreedor,
      nombreAcreedor: nombreAcreedor ?? this.nombreAcreedor,
      moneda: moneda ?? this.moneda,
      montoTotal: montoTotal ?? this.montoTotal,
      montoPagado: montoPagado ?? this.montoPagado,
      tieneInteres: tieneInteres ?? this.tieneInteres,
      tasaInteres: tasaInteres ?? this.tasaInteres,
      tipoTasa: tipoTasa ?? this.tipoTasa,
      estructuraPago: estructuraPago ?? this.estructuraPago,
      numeroCuotasTotal: numeroCuotasTotal ?? this.numeroCuotasTotal,
      numeroCuotasPagadas: numeroCuotasPagadas ?? this.numeroCuotasPagadas,
      montoCuota: montoCuota ?? this.montoCuota,
      pagoMinimo: pagoMinimo ?? this.pagoMinimo,
      periodicidadCuotas: periodicidadCuotas ?? this.periodicidadCuotas,
      interesTotal: interesTotal ?? this.interesTotal,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaVencimientoFinal:
          fechaVencimientoFinal ?? this.fechaVencimientoFinal,
      diaPago: diaPago ?? this.diaPago,
      proximaFechaPago: proximaFechaPago ?? this.proximaFechaPago,
      enMora: enMora ?? this.enMora,
      diasMora: diasMora ?? this.diasMora,
      tasaInteresMoratorio: tasaInteresMoratorio ?? this.tasaInteresMoratorio,
      estado: estado ?? this.estado,
      notas: notas ?? this.notas,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombreDeuda.present) {
      map['nombre_deuda'] = Variable<String>(nombreDeuda.value);
    }
    if (tipoDeuda.present) {
      map['tipo_deuda'] = Variable<String>(tipoDeuda.value);
    }
    if (tipoAcreedor.present) {
      map['tipo_acreedor'] = Variable<String>(tipoAcreedor.value);
    }
    if (nombreAcreedor.present) {
      map['nombre_acreedor'] = Variable<String>(nombreAcreedor.value);
    }
    if (moneda.present) {
      map['moneda'] = Variable<String>(moneda.value);
    }
    if (montoTotal.present) {
      map['monto_total'] = Variable<double>(montoTotal.value);
    }
    if (montoPagado.present) {
      map['monto_pagado'] = Variable<double>(montoPagado.value);
    }
    if (tieneInteres.present) {
      map['tiene_interes'] = Variable<bool>(tieneInteres.value);
    }
    if (tasaInteres.present) {
      map['tasa_interes'] = Variable<double>(tasaInteres.value);
    }
    if (tipoTasa.present) {
      map['tipo_tasa'] = Variable<String>(tipoTasa.value);
    }
    if (estructuraPago.present) {
      map['estructura_pago'] = Variable<String>(estructuraPago.value);
    }
    if (numeroCuotasTotal.present) {
      map['numero_cuotas_total'] = Variable<int>(numeroCuotasTotal.value);
    }
    if (numeroCuotasPagadas.present) {
      map['numero_cuotas_pagadas'] = Variable<int>(numeroCuotasPagadas.value);
    }
    if (montoCuota.present) {
      map['monto_cuota'] = Variable<double>(montoCuota.value);
    }
    if (pagoMinimo.present) {
      map['pago_minimo'] = Variable<double>(pagoMinimo.value);
    }
    if (periodicidadCuotas.present) {
      map['periodicidad_cuotas'] = Variable<String>(periodicidadCuotas.value);
    }
    if (interesTotal.present) {
      map['interes_total'] = Variable<double>(interesTotal.value);
    }
    if (fechaInicio.present) {
      map['fecha_inicio'] = Variable<DateTime>(fechaInicio.value);
    }
    if (fechaVencimientoFinal.present) {
      map['fecha_vencimiento_final'] = Variable<DateTime>(
        fechaVencimientoFinal.value,
      );
    }
    if (diaPago.present) {
      map['dia_pago'] = Variable<int>(diaPago.value);
    }
    if (proximaFechaPago.present) {
      map['proxima_fecha_pago'] = Variable<DateTime>(proximaFechaPago.value);
    }
    if (enMora.present) {
      map['en_mora'] = Variable<bool>(enMora.value);
    }
    if (diasMora.present) {
      map['dias_mora'] = Variable<int>(diasMora.value);
    }
    if (tasaInteresMoratorio.present) {
      map['tasa_interes_moratorio'] = Variable<double>(
        tasaInteresMoratorio.value,
      );
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (notas.present) {
      map['notas'] = Variable<String>(notas.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeudasCompanion(')
          ..write('id: $id, ')
          ..write('nombreDeuda: $nombreDeuda, ')
          ..write('tipoDeuda: $tipoDeuda, ')
          ..write('tipoAcreedor: $tipoAcreedor, ')
          ..write('nombreAcreedor: $nombreAcreedor, ')
          ..write('moneda: $moneda, ')
          ..write('montoTotal: $montoTotal, ')
          ..write('montoPagado: $montoPagado, ')
          ..write('tieneInteres: $tieneInteres, ')
          ..write('tasaInteres: $tasaInteres, ')
          ..write('tipoTasa: $tipoTasa, ')
          ..write('estructuraPago: $estructuraPago, ')
          ..write('numeroCuotasTotal: $numeroCuotasTotal, ')
          ..write('numeroCuotasPagadas: $numeroCuotasPagadas, ')
          ..write('montoCuota: $montoCuota, ')
          ..write('pagoMinimo: $pagoMinimo, ')
          ..write('periodicidadCuotas: $periodicidadCuotas, ')
          ..write('interesTotal: $interesTotal, ')
          ..write('fechaInicio: $fechaInicio, ')
          ..write('fechaVencimientoFinal: $fechaVencimientoFinal, ')
          ..write('diaPago: $diaPago, ')
          ..write('proximaFechaPago: $proximaFechaPago, ')
          ..write('enMora: $enMora, ')
          ..write('diasMora: $diasMora, ')
          ..write('tasaInteresMoratorio: $tasaInteresMoratorio, ')
          ..write('estado: $estado, ')
          ..write('notas: $notas, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PagosDeudaTable extends PagosDeuda
    with TableInfo<$PagosDeudaTable, PagoDeudaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PagosDeudaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deudaIdMeta = const VerificationMeta(
    'deudaId',
  );
  @override
  late final GeneratedColumn<String> deudaId = GeneratedColumn<String>(
    'deuda_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cuentaIdMeta = const VerificationMeta(
    'cuentaId',
  );
  @override
  late final GeneratedColumn<String> cuentaId = GeneratedColumn<String>(
    'cuenta_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _montoPagadoMeta = const VerificationMeta(
    'montoPagado',
  );
  @override
  late final GeneratedColumn<double> montoPagado = GeneratedColumn<double>(
    'monto_pagado',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _montoCapitalMeta = const VerificationMeta(
    'montoCapital',
  );
  @override
  late final GeneratedColumn<double> montoCapital = GeneratedColumn<double>(
    'monto_capital',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _montoInteresMeta = const VerificationMeta(
    'montoInteres',
  );
  @override
  late final GeneratedColumn<double> montoInteres = GeneratedColumn<double>(
    'monto_interes',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fechaPagoMeta = const VerificationMeta(
    'fechaPago',
  );
  @override
  late final GeneratedColumn<DateTime> fechaPago = GeneratedColumn<DateTime>(
    'fecha_pago',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numeroCuotaMeta = const VerificationMeta(
    'numeroCuota',
  );
  @override
  late final GeneratedColumn<int> numeroCuota = GeneratedColumn<int>(
    'numero_cuota',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deudaId,
    cuentaId,
    montoPagado,
    montoCapital,
    montoInteres,
    fechaPago,
    numeroCuota,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pagos_deuda';
  @override
  VerificationContext validateIntegrity(
    Insertable<PagoDeudaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('deuda_id')) {
      context.handle(
        _deudaIdMeta,
        deudaId.isAcceptableOrUnknown(data['deuda_id']!, _deudaIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deudaIdMeta);
    }
    if (data.containsKey('cuenta_id')) {
      context.handle(
        _cuentaIdMeta,
        cuentaId.isAcceptableOrUnknown(data['cuenta_id']!, _cuentaIdMeta),
      );
    }
    if (data.containsKey('monto_pagado')) {
      context.handle(
        _montoPagadoMeta,
        montoPagado.isAcceptableOrUnknown(
          data['monto_pagado']!,
          _montoPagadoMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_montoPagadoMeta);
    }
    if (data.containsKey('monto_capital')) {
      context.handle(
        _montoCapitalMeta,
        montoCapital.isAcceptableOrUnknown(
          data['monto_capital']!,
          _montoCapitalMeta,
        ),
      );
    }
    if (data.containsKey('monto_interes')) {
      context.handle(
        _montoInteresMeta,
        montoInteres.isAcceptableOrUnknown(
          data['monto_interes']!,
          _montoInteresMeta,
        ),
      );
    }
    if (data.containsKey('fecha_pago')) {
      context.handle(
        _fechaPagoMeta,
        fechaPago.isAcceptableOrUnknown(data['fecha_pago']!, _fechaPagoMeta),
      );
    } else if (isInserting) {
      context.missing(_fechaPagoMeta);
    }
    if (data.containsKey('numero_cuota')) {
      context.handle(
        _numeroCuotaMeta,
        numeroCuota.isAcceptableOrUnknown(
          data['numero_cuota']!,
          _numeroCuotaMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PagoDeudaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PagoDeudaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      deudaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deuda_id'],
      )!,
      cuentaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cuenta_id'],
      ),
      montoPagado: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_pagado'],
      )!,
      montoCapital: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_capital'],
      ),
      montoInteres: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}monto_interes'],
      ),
      fechaPago: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fecha_pago'],
      )!,
      numeroCuota: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}numero_cuota'],
      ),
    );
  }

  @override
  $PagosDeudaTable createAlias(String alias) {
    return $PagosDeudaTable(attachedDatabase, alias);
  }
}

class PagoDeudaRow extends DataClass implements Insertable<PagoDeudaRow> {
  final String id;
  final String deudaId;
  final String? cuentaId;
  final double montoPagado;
  final double? montoCapital;
  final double? montoInteres;
  final DateTime fechaPago;
  final int? numeroCuota;
  const PagoDeudaRow({
    required this.id,
    required this.deudaId,
    this.cuentaId,
    required this.montoPagado,
    this.montoCapital,
    this.montoInteres,
    required this.fechaPago,
    this.numeroCuota,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['deuda_id'] = Variable<String>(deudaId);
    if (!nullToAbsent || cuentaId != null) {
      map['cuenta_id'] = Variable<String>(cuentaId);
    }
    map['monto_pagado'] = Variable<double>(montoPagado);
    if (!nullToAbsent || montoCapital != null) {
      map['monto_capital'] = Variable<double>(montoCapital);
    }
    if (!nullToAbsent || montoInteres != null) {
      map['monto_interes'] = Variable<double>(montoInteres);
    }
    map['fecha_pago'] = Variable<DateTime>(fechaPago);
    if (!nullToAbsent || numeroCuota != null) {
      map['numero_cuota'] = Variable<int>(numeroCuota);
    }
    return map;
  }

  PagosDeudaCompanion toCompanion(bool nullToAbsent) {
    return PagosDeudaCompanion(
      id: Value(id),
      deudaId: Value(deudaId),
      cuentaId: cuentaId == null && nullToAbsent
          ? const Value.absent()
          : Value(cuentaId),
      montoPagado: Value(montoPagado),
      montoCapital: montoCapital == null && nullToAbsent
          ? const Value.absent()
          : Value(montoCapital),
      montoInteres: montoInteres == null && nullToAbsent
          ? const Value.absent()
          : Value(montoInteres),
      fechaPago: Value(fechaPago),
      numeroCuota: numeroCuota == null && nullToAbsent
          ? const Value.absent()
          : Value(numeroCuota),
    );
  }

  factory PagoDeudaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PagoDeudaRow(
      id: serializer.fromJson<String>(json['id']),
      deudaId: serializer.fromJson<String>(json['deudaId']),
      cuentaId: serializer.fromJson<String?>(json['cuentaId']),
      montoPagado: serializer.fromJson<double>(json['montoPagado']),
      montoCapital: serializer.fromJson<double?>(json['montoCapital']),
      montoInteres: serializer.fromJson<double?>(json['montoInteres']),
      fechaPago: serializer.fromJson<DateTime>(json['fechaPago']),
      numeroCuota: serializer.fromJson<int?>(json['numeroCuota']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'deudaId': serializer.toJson<String>(deudaId),
      'cuentaId': serializer.toJson<String?>(cuentaId),
      'montoPagado': serializer.toJson<double>(montoPagado),
      'montoCapital': serializer.toJson<double?>(montoCapital),
      'montoInteres': serializer.toJson<double?>(montoInteres),
      'fechaPago': serializer.toJson<DateTime>(fechaPago),
      'numeroCuota': serializer.toJson<int?>(numeroCuota),
    };
  }

  PagoDeudaRow copyWith({
    String? id,
    String? deudaId,
    Value<String?> cuentaId = const Value.absent(),
    double? montoPagado,
    Value<double?> montoCapital = const Value.absent(),
    Value<double?> montoInteres = const Value.absent(),
    DateTime? fechaPago,
    Value<int?> numeroCuota = const Value.absent(),
  }) => PagoDeudaRow(
    id: id ?? this.id,
    deudaId: deudaId ?? this.deudaId,
    cuentaId: cuentaId.present ? cuentaId.value : this.cuentaId,
    montoPagado: montoPagado ?? this.montoPagado,
    montoCapital: montoCapital.present ? montoCapital.value : this.montoCapital,
    montoInteres: montoInteres.present ? montoInteres.value : this.montoInteres,
    fechaPago: fechaPago ?? this.fechaPago,
    numeroCuota: numeroCuota.present ? numeroCuota.value : this.numeroCuota,
  );
  PagoDeudaRow copyWithCompanion(PagosDeudaCompanion data) {
    return PagoDeudaRow(
      id: data.id.present ? data.id.value : this.id,
      deudaId: data.deudaId.present ? data.deudaId.value : this.deudaId,
      cuentaId: data.cuentaId.present ? data.cuentaId.value : this.cuentaId,
      montoPagado: data.montoPagado.present
          ? data.montoPagado.value
          : this.montoPagado,
      montoCapital: data.montoCapital.present
          ? data.montoCapital.value
          : this.montoCapital,
      montoInteres: data.montoInteres.present
          ? data.montoInteres.value
          : this.montoInteres,
      fechaPago: data.fechaPago.present ? data.fechaPago.value : this.fechaPago,
      numeroCuota: data.numeroCuota.present
          ? data.numeroCuota.value
          : this.numeroCuota,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PagoDeudaRow(')
          ..write('id: $id, ')
          ..write('deudaId: $deudaId, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('montoPagado: $montoPagado, ')
          ..write('montoCapital: $montoCapital, ')
          ..write('montoInteres: $montoInteres, ')
          ..write('fechaPago: $fechaPago, ')
          ..write('numeroCuota: $numeroCuota')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    deudaId,
    cuentaId,
    montoPagado,
    montoCapital,
    montoInteres,
    fechaPago,
    numeroCuota,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PagoDeudaRow &&
          other.id == this.id &&
          other.deudaId == this.deudaId &&
          other.cuentaId == this.cuentaId &&
          other.montoPagado == this.montoPagado &&
          other.montoCapital == this.montoCapital &&
          other.montoInteres == this.montoInteres &&
          other.fechaPago == this.fechaPago &&
          other.numeroCuota == this.numeroCuota);
}

class PagosDeudaCompanion extends UpdateCompanion<PagoDeudaRow> {
  final Value<String> id;
  final Value<String> deudaId;
  final Value<String?> cuentaId;
  final Value<double> montoPagado;
  final Value<double?> montoCapital;
  final Value<double?> montoInteres;
  final Value<DateTime> fechaPago;
  final Value<int?> numeroCuota;
  final Value<int> rowid;
  const PagosDeudaCompanion({
    this.id = const Value.absent(),
    this.deudaId = const Value.absent(),
    this.cuentaId = const Value.absent(),
    this.montoPagado = const Value.absent(),
    this.montoCapital = const Value.absent(),
    this.montoInteres = const Value.absent(),
    this.fechaPago = const Value.absent(),
    this.numeroCuota = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PagosDeudaCompanion.insert({
    required String id,
    required String deudaId,
    this.cuentaId = const Value.absent(),
    required double montoPagado,
    this.montoCapital = const Value.absent(),
    this.montoInteres = const Value.absent(),
    required DateTime fechaPago,
    this.numeroCuota = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       deudaId = Value(deudaId),
       montoPagado = Value(montoPagado),
       fechaPago = Value(fechaPago);
  static Insertable<PagoDeudaRow> custom({
    Expression<String>? id,
    Expression<String>? deudaId,
    Expression<String>? cuentaId,
    Expression<double>? montoPagado,
    Expression<double>? montoCapital,
    Expression<double>? montoInteres,
    Expression<DateTime>? fechaPago,
    Expression<int>? numeroCuota,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deudaId != null) 'deuda_id': deudaId,
      if (cuentaId != null) 'cuenta_id': cuentaId,
      if (montoPagado != null) 'monto_pagado': montoPagado,
      if (montoCapital != null) 'monto_capital': montoCapital,
      if (montoInteres != null) 'monto_interes': montoInteres,
      if (fechaPago != null) 'fecha_pago': fechaPago,
      if (numeroCuota != null) 'numero_cuota': numeroCuota,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PagosDeudaCompanion copyWith({
    Value<String>? id,
    Value<String>? deudaId,
    Value<String?>? cuentaId,
    Value<double>? montoPagado,
    Value<double?>? montoCapital,
    Value<double?>? montoInteres,
    Value<DateTime>? fechaPago,
    Value<int?>? numeroCuota,
    Value<int>? rowid,
  }) {
    return PagosDeudaCompanion(
      id: id ?? this.id,
      deudaId: deudaId ?? this.deudaId,
      cuentaId: cuentaId ?? this.cuentaId,
      montoPagado: montoPagado ?? this.montoPagado,
      montoCapital: montoCapital ?? this.montoCapital,
      montoInteres: montoInteres ?? this.montoInteres,
      fechaPago: fechaPago ?? this.fechaPago,
      numeroCuota: numeroCuota ?? this.numeroCuota,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (deudaId.present) {
      map['deuda_id'] = Variable<String>(deudaId.value);
    }
    if (cuentaId.present) {
      map['cuenta_id'] = Variable<String>(cuentaId.value);
    }
    if (montoPagado.present) {
      map['monto_pagado'] = Variable<double>(montoPagado.value);
    }
    if (montoCapital.present) {
      map['monto_capital'] = Variable<double>(montoCapital.value);
    }
    if (montoInteres.present) {
      map['monto_interes'] = Variable<double>(montoInteres.value);
    }
    if (fechaPago.present) {
      map['fecha_pago'] = Variable<DateTime>(fechaPago.value);
    }
    if (numeroCuota.present) {
      map['numero_cuota'] = Variable<int>(numeroCuota.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PagosDeudaCompanion(')
          ..write('id: $id, ')
          ..write('deudaId: $deudaId, ')
          ..write('cuentaId: $cuentaId, ')
          ..write('montoPagado: $montoPagado, ')
          ..write('montoCapital: $montoCapital, ')
          ..write('montoInteres: $montoInteres, ')
          ..write('fechaPago: $fechaPago, ')
          ..write('numeroCuota: $numeroCuota, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CuentasTable cuentas = $CuentasTable(this);
  late final $CategoriasTable categorias = $CategoriasTable(this);
  late final $TransaccionesTable transacciones = $TransaccionesTable(this);
  late final $DeudasTable deudas = $DeudasTable(this);
  late final $PagosDeudaTable pagosDeuda = $PagosDeudaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cuentas,
    categorias,
    transacciones,
    deudas,
    pagosDeuda,
  ];
}

typedef $$CuentasTableCreateCompanionBuilder =
    CuentasCompanion Function({
      required String id,
      required String nombre,
      required String tipo,
      required String moneda,
      required double saldoActual,
      Value<int> rowid,
    });
typedef $$CuentasTableUpdateCompanionBuilder =
    CuentasCompanion Function({
      Value<String> id,
      Value<String> nombre,
      Value<String> tipo,
      Value<String> moneda,
      Value<double> saldoActual,
      Value<int> rowid,
    });

class $$CuentasTableFilterComposer
    extends Composer<_$AppDatabase, $CuentasTable> {
  $$CuentasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moneda => $composableBuilder(
    column: $table.moneda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get saldoActual => $composableBuilder(
    column: $table.saldoActual,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CuentasTableOrderingComposer
    extends Composer<_$AppDatabase, $CuentasTable> {
  $$CuentasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moneda => $composableBuilder(
    column: $table.moneda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get saldoActual => $composableBuilder(
    column: $table.saldoActual,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CuentasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CuentasTable> {
  $$CuentasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get moneda =>
      $composableBuilder(column: $table.moneda, builder: (column) => column);

  GeneratedColumn<double> get saldoActual => $composableBuilder(
    column: $table.saldoActual,
    builder: (column) => column,
  );
}

class $$CuentasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CuentasTable,
          CuentaRow,
          $$CuentasTableFilterComposer,
          $$CuentasTableOrderingComposer,
          $$CuentasTableAnnotationComposer,
          $$CuentasTableCreateCompanionBuilder,
          $$CuentasTableUpdateCompanionBuilder,
          (CuentaRow, BaseReferences<_$AppDatabase, $CuentasTable, CuentaRow>),
          CuentaRow,
          PrefetchHooks Function()
        > {
  $$CuentasTableTableManager(_$AppDatabase db, $CuentasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CuentasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CuentasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CuentasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> moneda = const Value.absent(),
                Value<double> saldoActual = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CuentasCompanion(
                id: id,
                nombre: nombre,
                tipo: tipo,
                moneda: moneda,
                saldoActual: saldoActual,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                required String tipo,
                required String moneda,
                required double saldoActual,
                Value<int> rowid = const Value.absent(),
              }) => CuentasCompanion.insert(
                id: id,
                nombre: nombre,
                tipo: tipo,
                moneda: moneda,
                saldoActual: saldoActual,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CuentasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CuentasTable,
      CuentaRow,
      $$CuentasTableFilterComposer,
      $$CuentasTableOrderingComposer,
      $$CuentasTableAnnotationComposer,
      $$CuentasTableCreateCompanionBuilder,
      $$CuentasTableUpdateCompanionBuilder,
      (CuentaRow, BaseReferences<_$AppDatabase, $CuentasTable, CuentaRow>),
      CuentaRow,
      PrefetchHooks Function()
    >;
typedef $$CategoriasTableCreateCompanionBuilder =
    CategoriasCompanion Function({
      required String id,
      required String nombre,
      required String tipo,
      required String iconName,
      Value<bool> esPredeterminada,
      Value<int> rowid,
    });
typedef $$CategoriasTableUpdateCompanionBuilder =
    CategoriasCompanion Function({
      Value<String> id,
      Value<String> nombre,
      Value<String> tipo,
      Value<String> iconName,
      Value<bool> esPredeterminada,
      Value<int> rowid,
    });

class $$CategoriasTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriasTable> {
  $$CategoriasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get esPredeterminada => $composableBuilder(
    column: $table.esPredeterminada,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriasTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriasTable> {
  $$CategoriasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get esPredeterminada => $composableBuilder(
    column: $table.esPredeterminada,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriasTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriasTable> {
  $$CategoriasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<bool> get esPredeterminada => $composableBuilder(
    column: $table.esPredeterminada,
    builder: (column) => column,
  );
}

class $$CategoriasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriasTable,
          CategoriaRow,
          $$CategoriasTableFilterComposer,
          $$CategoriasTableOrderingComposer,
          $$CategoriasTableAnnotationComposer,
          $$CategoriasTableCreateCompanionBuilder,
          $$CategoriasTableUpdateCompanionBuilder,
          (
            CategoriaRow,
            BaseReferences<_$AppDatabase, $CategoriasTable, CategoriaRow>,
          ),
          CategoriaRow,
          PrefetchHooks Function()
        > {
  $$CategoriasTableTableManager(_$AppDatabase db, $CategoriasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> iconName = const Value.absent(),
                Value<bool> esPredeterminada = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriasCompanion(
                id: id,
                nombre: nombre,
                tipo: tipo,
                iconName: iconName,
                esPredeterminada: esPredeterminada,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                required String tipo,
                required String iconName,
                Value<bool> esPredeterminada = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriasCompanion.insert(
                id: id,
                nombre: nombre,
                tipo: tipo,
                iconName: iconName,
                esPredeterminada: esPredeterminada,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriasTable,
      CategoriaRow,
      $$CategoriasTableFilterComposer,
      $$CategoriasTableOrderingComposer,
      $$CategoriasTableAnnotationComposer,
      $$CategoriasTableCreateCompanionBuilder,
      $$CategoriasTableUpdateCompanionBuilder,
      (
        CategoriaRow,
        BaseReferences<_$AppDatabase, $CategoriasTable, CategoriaRow>,
      ),
      CategoriaRow,
      PrefetchHooks Function()
    >;
typedef $$TransaccionesTableCreateCompanionBuilder =
    TransaccionesCompanion Function({
      required String id,
      required String cuentaId,
      required String categoriaId,
      required double monto,
      required String moneda,
      required String tipo,
      required String concepto,
      required String metodoPago,
      Value<bool> esRecurrente,
      Value<String?> comprobanteUrl,
      required String fuenteCaptura,
      Value<String?> dataRaw,
      required DateTime fecha,
      Value<int> rowid,
    });
typedef $$TransaccionesTableUpdateCompanionBuilder =
    TransaccionesCompanion Function({
      Value<String> id,
      Value<String> cuentaId,
      Value<String> categoriaId,
      Value<double> monto,
      Value<String> moneda,
      Value<String> tipo,
      Value<String> concepto,
      Value<String> metodoPago,
      Value<bool> esRecurrente,
      Value<String?> comprobanteUrl,
      Value<String> fuenteCaptura,
      Value<String?> dataRaw,
      Value<DateTime> fecha,
      Value<int> rowid,
    });

class $$TransaccionesTableFilterComposer
    extends Composer<_$AppDatabase, $TransaccionesTable> {
  $$TransaccionesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moneda => $composableBuilder(
    column: $table.moneda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get concepto => $composableBuilder(
    column: $table.concepto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metodoPago => $composableBuilder(
    column: $table.metodoPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get esRecurrente => $composableBuilder(
    column: $table.esRecurrente,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get comprobanteUrl => $composableBuilder(
    column: $table.comprobanteUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fuenteCaptura => $composableBuilder(
    column: $table.fuenteCaptura,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataRaw => $composableBuilder(
    column: $table.dataRaw,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransaccionesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransaccionesTable> {
  $$TransaccionesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get monto => $composableBuilder(
    column: $table.monto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moneda => $composableBuilder(
    column: $table.moneda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipo => $composableBuilder(
    column: $table.tipo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get concepto => $composableBuilder(
    column: $table.concepto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metodoPago => $composableBuilder(
    column: $table.metodoPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get esRecurrente => $composableBuilder(
    column: $table.esRecurrente,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get comprobanteUrl => $composableBuilder(
    column: $table.comprobanteUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fuenteCaptura => $composableBuilder(
    column: $table.fuenteCaptura,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataRaw => $composableBuilder(
    column: $table.dataRaw,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fecha => $composableBuilder(
    column: $table.fecha,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransaccionesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransaccionesTable> {
  $$TransaccionesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cuentaId =>
      $composableBuilder(column: $table.cuentaId, builder: (column) => column);

  GeneratedColumn<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get monto =>
      $composableBuilder(column: $table.monto, builder: (column) => column);

  GeneratedColumn<String> get moneda =>
      $composableBuilder(column: $table.moneda, builder: (column) => column);

  GeneratedColumn<String> get tipo =>
      $composableBuilder(column: $table.tipo, builder: (column) => column);

  GeneratedColumn<String> get concepto =>
      $composableBuilder(column: $table.concepto, builder: (column) => column);

  GeneratedColumn<String> get metodoPago => $composableBuilder(
    column: $table.metodoPago,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get esRecurrente => $composableBuilder(
    column: $table.esRecurrente,
    builder: (column) => column,
  );

  GeneratedColumn<String> get comprobanteUrl => $composableBuilder(
    column: $table.comprobanteUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fuenteCaptura => $composableBuilder(
    column: $table.fuenteCaptura,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataRaw =>
      $composableBuilder(column: $table.dataRaw, builder: (column) => column);

  GeneratedColumn<DateTime> get fecha =>
      $composableBuilder(column: $table.fecha, builder: (column) => column);
}

class $$TransaccionesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransaccionesTable,
          TransaccionRow,
          $$TransaccionesTableFilterComposer,
          $$TransaccionesTableOrderingComposer,
          $$TransaccionesTableAnnotationComposer,
          $$TransaccionesTableCreateCompanionBuilder,
          $$TransaccionesTableUpdateCompanionBuilder,
          (
            TransaccionRow,
            BaseReferences<_$AppDatabase, $TransaccionesTable, TransaccionRow>,
          ),
          TransaccionRow,
          PrefetchHooks Function()
        > {
  $$TransaccionesTableTableManager(_$AppDatabase db, $TransaccionesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransaccionesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransaccionesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransaccionesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cuentaId = const Value.absent(),
                Value<String> categoriaId = const Value.absent(),
                Value<double> monto = const Value.absent(),
                Value<String> moneda = const Value.absent(),
                Value<String> tipo = const Value.absent(),
                Value<String> concepto = const Value.absent(),
                Value<String> metodoPago = const Value.absent(),
                Value<bool> esRecurrente = const Value.absent(),
                Value<String?> comprobanteUrl = const Value.absent(),
                Value<String> fuenteCaptura = const Value.absent(),
                Value<String?> dataRaw = const Value.absent(),
                Value<DateTime> fecha = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransaccionesCompanion(
                id: id,
                cuentaId: cuentaId,
                categoriaId: categoriaId,
                monto: monto,
                moneda: moneda,
                tipo: tipo,
                concepto: concepto,
                metodoPago: metodoPago,
                esRecurrente: esRecurrente,
                comprobanteUrl: comprobanteUrl,
                fuenteCaptura: fuenteCaptura,
                dataRaw: dataRaw,
                fecha: fecha,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cuentaId,
                required String categoriaId,
                required double monto,
                required String moneda,
                required String tipo,
                required String concepto,
                required String metodoPago,
                Value<bool> esRecurrente = const Value.absent(),
                Value<String?> comprobanteUrl = const Value.absent(),
                required String fuenteCaptura,
                Value<String?> dataRaw = const Value.absent(),
                required DateTime fecha,
                Value<int> rowid = const Value.absent(),
              }) => TransaccionesCompanion.insert(
                id: id,
                cuentaId: cuentaId,
                categoriaId: categoriaId,
                monto: monto,
                moneda: moneda,
                tipo: tipo,
                concepto: concepto,
                metodoPago: metodoPago,
                esRecurrente: esRecurrente,
                comprobanteUrl: comprobanteUrl,
                fuenteCaptura: fuenteCaptura,
                dataRaw: dataRaw,
                fecha: fecha,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransaccionesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransaccionesTable,
      TransaccionRow,
      $$TransaccionesTableFilterComposer,
      $$TransaccionesTableOrderingComposer,
      $$TransaccionesTableAnnotationComposer,
      $$TransaccionesTableCreateCompanionBuilder,
      $$TransaccionesTableUpdateCompanionBuilder,
      (
        TransaccionRow,
        BaseReferences<_$AppDatabase, $TransaccionesTable, TransaccionRow>,
      ),
      TransaccionRow,
      PrefetchHooks Function()
    >;
typedef $$DeudasTableCreateCompanionBuilder =
    DeudasCompanion Function({
      required String id,
      required String nombreDeuda,
      required String tipoDeuda,
      required String tipoAcreedor,
      required String nombreAcreedor,
      required String moneda,
      required double montoTotal,
      required double montoPagado,
      required bool tieneInteres,
      Value<double?> tasaInteres,
      Value<String?> tipoTasa,
      required String estructuraPago,
      Value<int?> numeroCuotasTotal,
      Value<int?> numeroCuotasPagadas,
      Value<double?> montoCuota,
      Value<double?> pagoMinimo,
      Value<String?> periodicidadCuotas,
      Value<double?> interesTotal,
      required DateTime fechaInicio,
      Value<DateTime?> fechaVencimientoFinal,
      Value<int?> diaPago,
      Value<DateTime?> proximaFechaPago,
      Value<bool> enMora,
      Value<int?> diasMora,
      Value<double?> tasaInteresMoratorio,
      required String estado,
      Value<String?> notas,
      Value<int> rowid,
    });
typedef $$DeudasTableUpdateCompanionBuilder =
    DeudasCompanion Function({
      Value<String> id,
      Value<String> nombreDeuda,
      Value<String> tipoDeuda,
      Value<String> tipoAcreedor,
      Value<String> nombreAcreedor,
      Value<String> moneda,
      Value<double> montoTotal,
      Value<double> montoPagado,
      Value<bool> tieneInteres,
      Value<double?> tasaInteres,
      Value<String?> tipoTasa,
      Value<String> estructuraPago,
      Value<int?> numeroCuotasTotal,
      Value<int?> numeroCuotasPagadas,
      Value<double?> montoCuota,
      Value<double?> pagoMinimo,
      Value<String?> periodicidadCuotas,
      Value<double?> interesTotal,
      Value<DateTime> fechaInicio,
      Value<DateTime?> fechaVencimientoFinal,
      Value<int?> diaPago,
      Value<DateTime?> proximaFechaPago,
      Value<bool> enMora,
      Value<int?> diasMora,
      Value<double?> tasaInteresMoratorio,
      Value<String> estado,
      Value<String?> notas,
      Value<int> rowid,
    });

class $$DeudasTableFilterComposer
    extends Composer<_$AppDatabase, $DeudasTable> {
  $$DeudasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombreDeuda => $composableBuilder(
    column: $table.nombreDeuda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoDeuda => $composableBuilder(
    column: $table.tipoDeuda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoAcreedor => $composableBuilder(
    column: $table.tipoAcreedor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombreAcreedor => $composableBuilder(
    column: $table.nombreAcreedor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get moneda => $composableBuilder(
    column: $table.moneda,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoTotal => $composableBuilder(
    column: $table.montoTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoPagado => $composableBuilder(
    column: $table.montoPagado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get tieneInteres => $composableBuilder(
    column: $table.tieneInteres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tasaInteres => $composableBuilder(
    column: $table.tasaInteres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tipoTasa => $composableBuilder(
    column: $table.tipoTasa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estructuraPago => $composableBuilder(
    column: $table.estructuraPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numeroCuotasTotal => $composableBuilder(
    column: $table.numeroCuotasTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numeroCuotasPagadas => $composableBuilder(
    column: $table.numeroCuotasPagadas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoCuota => $composableBuilder(
    column: $table.montoCuota,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pagoMinimo => $composableBuilder(
    column: $table.pagoMinimo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get periodicidadCuotas => $composableBuilder(
    column: $table.periodicidadCuotas,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get interesTotal => $composableBuilder(
    column: $table.interesTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fechaVencimientoFinal => $composableBuilder(
    column: $table.fechaVencimientoFinal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diaPago => $composableBuilder(
    column: $table.diaPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get proximaFechaPago => $composableBuilder(
    column: $table.proximaFechaPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enMora => $composableBuilder(
    column: $table.enMora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diasMora => $composableBuilder(
    column: $table.diasMora,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tasaInteresMoratorio => $composableBuilder(
    column: $table.tasaInteresMoratorio,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeudasTableOrderingComposer
    extends Composer<_$AppDatabase, $DeudasTable> {
  $$DeudasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombreDeuda => $composableBuilder(
    column: $table.nombreDeuda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoDeuda => $composableBuilder(
    column: $table.tipoDeuda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoAcreedor => $composableBuilder(
    column: $table.tipoAcreedor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombreAcreedor => $composableBuilder(
    column: $table.nombreAcreedor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get moneda => $composableBuilder(
    column: $table.moneda,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoTotal => $composableBuilder(
    column: $table.montoTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoPagado => $composableBuilder(
    column: $table.montoPagado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get tieneInteres => $composableBuilder(
    column: $table.tieneInteres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tasaInteres => $composableBuilder(
    column: $table.tasaInteres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tipoTasa => $composableBuilder(
    column: $table.tipoTasa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estructuraPago => $composableBuilder(
    column: $table.estructuraPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numeroCuotasTotal => $composableBuilder(
    column: $table.numeroCuotasTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numeroCuotasPagadas => $composableBuilder(
    column: $table.numeroCuotasPagadas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoCuota => $composableBuilder(
    column: $table.montoCuota,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pagoMinimo => $composableBuilder(
    column: $table.pagoMinimo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get periodicidadCuotas => $composableBuilder(
    column: $table.periodicidadCuotas,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get interesTotal => $composableBuilder(
    column: $table.interesTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fechaVencimientoFinal => $composableBuilder(
    column: $table.fechaVencimientoFinal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diaPago => $composableBuilder(
    column: $table.diaPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get proximaFechaPago => $composableBuilder(
    column: $table.proximaFechaPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enMora => $composableBuilder(
    column: $table.enMora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diasMora => $composableBuilder(
    column: $table.diasMora,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tasaInteresMoratorio => $composableBuilder(
    column: $table.tasaInteresMoratorio,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notas => $composableBuilder(
    column: $table.notas,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeudasTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeudasTable> {
  $$DeudasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombreDeuda => $composableBuilder(
    column: $table.nombreDeuda,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tipoDeuda =>
      $composableBuilder(column: $table.tipoDeuda, builder: (column) => column);

  GeneratedColumn<String> get tipoAcreedor => $composableBuilder(
    column: $table.tipoAcreedor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nombreAcreedor => $composableBuilder(
    column: $table.nombreAcreedor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get moneda =>
      $composableBuilder(column: $table.moneda, builder: (column) => column);

  GeneratedColumn<double> get montoTotal => $composableBuilder(
    column: $table.montoTotal,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoPagado => $composableBuilder(
    column: $table.montoPagado,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get tieneInteres => $composableBuilder(
    column: $table.tieneInteres,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tasaInteres => $composableBuilder(
    column: $table.tasaInteres,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tipoTasa =>
      $composableBuilder(column: $table.tipoTasa, builder: (column) => column);

  GeneratedColumn<String> get estructuraPago => $composableBuilder(
    column: $table.estructuraPago,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numeroCuotasTotal => $composableBuilder(
    column: $table.numeroCuotasTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get numeroCuotasPagadas => $composableBuilder(
    column: $table.numeroCuotasPagadas,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoCuota => $composableBuilder(
    column: $table.montoCuota,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pagoMinimo => $composableBuilder(
    column: $table.pagoMinimo,
    builder: (column) => column,
  );

  GeneratedColumn<String> get periodicidadCuotas => $composableBuilder(
    column: $table.periodicidadCuotas,
    builder: (column) => column,
  );

  GeneratedColumn<double> get interesTotal => $composableBuilder(
    column: $table.interesTotal,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fechaInicio => $composableBuilder(
    column: $table.fechaInicio,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fechaVencimientoFinal => $composableBuilder(
    column: $table.fechaVencimientoFinal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get diaPago =>
      $composableBuilder(column: $table.diaPago, builder: (column) => column);

  GeneratedColumn<DateTime> get proximaFechaPago => $composableBuilder(
    column: $table.proximaFechaPago,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enMora =>
      $composableBuilder(column: $table.enMora, builder: (column) => column);

  GeneratedColumn<int> get diasMora =>
      $composableBuilder(column: $table.diasMora, builder: (column) => column);

  GeneratedColumn<double> get tasaInteresMoratorio => $composableBuilder(
    column: $table.tasaInteresMoratorio,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get notas =>
      $composableBuilder(column: $table.notas, builder: (column) => column);
}

class $$DeudasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeudasTable,
          DeudaRow,
          $$DeudasTableFilterComposer,
          $$DeudasTableOrderingComposer,
          $$DeudasTableAnnotationComposer,
          $$DeudasTableCreateCompanionBuilder,
          $$DeudasTableUpdateCompanionBuilder,
          (DeudaRow, BaseReferences<_$AppDatabase, $DeudasTable, DeudaRow>),
          DeudaRow,
          PrefetchHooks Function()
        > {
  $$DeudasTableTableManager(_$AppDatabase db, $DeudasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeudasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeudasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeudasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombreDeuda = const Value.absent(),
                Value<String> tipoDeuda = const Value.absent(),
                Value<String> tipoAcreedor = const Value.absent(),
                Value<String> nombreAcreedor = const Value.absent(),
                Value<String> moneda = const Value.absent(),
                Value<double> montoTotal = const Value.absent(),
                Value<double> montoPagado = const Value.absent(),
                Value<bool> tieneInteres = const Value.absent(),
                Value<double?> tasaInteres = const Value.absent(),
                Value<String?> tipoTasa = const Value.absent(),
                Value<String> estructuraPago = const Value.absent(),
                Value<int?> numeroCuotasTotal = const Value.absent(),
                Value<int?> numeroCuotasPagadas = const Value.absent(),
                Value<double?> montoCuota = const Value.absent(),
                Value<double?> pagoMinimo = const Value.absent(),
                Value<String?> periodicidadCuotas = const Value.absent(),
                Value<double?> interesTotal = const Value.absent(),
                Value<DateTime> fechaInicio = const Value.absent(),
                Value<DateTime?> fechaVencimientoFinal = const Value.absent(),
                Value<int?> diaPago = const Value.absent(),
                Value<DateTime?> proximaFechaPago = const Value.absent(),
                Value<bool> enMora = const Value.absent(),
                Value<int?> diasMora = const Value.absent(),
                Value<double?> tasaInteresMoratorio = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<String?> notas = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeudasCompanion(
                id: id,
                nombreDeuda: nombreDeuda,
                tipoDeuda: tipoDeuda,
                tipoAcreedor: tipoAcreedor,
                nombreAcreedor: nombreAcreedor,
                moneda: moneda,
                montoTotal: montoTotal,
                montoPagado: montoPagado,
                tieneInteres: tieneInteres,
                tasaInteres: tasaInteres,
                tipoTasa: tipoTasa,
                estructuraPago: estructuraPago,
                numeroCuotasTotal: numeroCuotasTotal,
                numeroCuotasPagadas: numeroCuotasPagadas,
                montoCuota: montoCuota,
                pagoMinimo: pagoMinimo,
                periodicidadCuotas: periodicidadCuotas,
                interesTotal: interesTotal,
                fechaInicio: fechaInicio,
                fechaVencimientoFinal: fechaVencimientoFinal,
                diaPago: diaPago,
                proximaFechaPago: proximaFechaPago,
                enMora: enMora,
                diasMora: diasMora,
                tasaInteresMoratorio: tasaInteresMoratorio,
                estado: estado,
                notas: notas,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombreDeuda,
                required String tipoDeuda,
                required String tipoAcreedor,
                required String nombreAcreedor,
                required String moneda,
                required double montoTotal,
                required double montoPagado,
                required bool tieneInteres,
                Value<double?> tasaInteres = const Value.absent(),
                Value<String?> tipoTasa = const Value.absent(),
                required String estructuraPago,
                Value<int?> numeroCuotasTotal = const Value.absent(),
                Value<int?> numeroCuotasPagadas = const Value.absent(),
                Value<double?> montoCuota = const Value.absent(),
                Value<double?> pagoMinimo = const Value.absent(),
                Value<String?> periodicidadCuotas = const Value.absent(),
                Value<double?> interesTotal = const Value.absent(),
                required DateTime fechaInicio,
                Value<DateTime?> fechaVencimientoFinal = const Value.absent(),
                Value<int?> diaPago = const Value.absent(),
                Value<DateTime?> proximaFechaPago = const Value.absent(),
                Value<bool> enMora = const Value.absent(),
                Value<int?> diasMora = const Value.absent(),
                Value<double?> tasaInteresMoratorio = const Value.absent(),
                required String estado,
                Value<String?> notas = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeudasCompanion.insert(
                id: id,
                nombreDeuda: nombreDeuda,
                tipoDeuda: tipoDeuda,
                tipoAcreedor: tipoAcreedor,
                nombreAcreedor: nombreAcreedor,
                moneda: moneda,
                montoTotal: montoTotal,
                montoPagado: montoPagado,
                tieneInteres: tieneInteres,
                tasaInteres: tasaInteres,
                tipoTasa: tipoTasa,
                estructuraPago: estructuraPago,
                numeroCuotasTotal: numeroCuotasTotal,
                numeroCuotasPagadas: numeroCuotasPagadas,
                montoCuota: montoCuota,
                pagoMinimo: pagoMinimo,
                periodicidadCuotas: periodicidadCuotas,
                interesTotal: interesTotal,
                fechaInicio: fechaInicio,
                fechaVencimientoFinal: fechaVencimientoFinal,
                diaPago: diaPago,
                proximaFechaPago: proximaFechaPago,
                enMora: enMora,
                diasMora: diasMora,
                tasaInteresMoratorio: tasaInteresMoratorio,
                estado: estado,
                notas: notas,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeudasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeudasTable,
      DeudaRow,
      $$DeudasTableFilterComposer,
      $$DeudasTableOrderingComposer,
      $$DeudasTableAnnotationComposer,
      $$DeudasTableCreateCompanionBuilder,
      $$DeudasTableUpdateCompanionBuilder,
      (DeudaRow, BaseReferences<_$AppDatabase, $DeudasTable, DeudaRow>),
      DeudaRow,
      PrefetchHooks Function()
    >;
typedef $$PagosDeudaTableCreateCompanionBuilder =
    PagosDeudaCompanion Function({
      required String id,
      required String deudaId,
      Value<String?> cuentaId,
      required double montoPagado,
      Value<double?> montoCapital,
      Value<double?> montoInteres,
      required DateTime fechaPago,
      Value<int?> numeroCuota,
      Value<int> rowid,
    });
typedef $$PagosDeudaTableUpdateCompanionBuilder =
    PagosDeudaCompanion Function({
      Value<String> id,
      Value<String> deudaId,
      Value<String?> cuentaId,
      Value<double> montoPagado,
      Value<double?> montoCapital,
      Value<double?> montoInteres,
      Value<DateTime> fechaPago,
      Value<int?> numeroCuota,
      Value<int> rowid,
    });

class $$PagosDeudaTableFilterComposer
    extends Composer<_$AppDatabase, $PagosDeudaTable> {
  $$PagosDeudaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deudaId => $composableBuilder(
    column: $table.deudaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoPagado => $composableBuilder(
    column: $table.montoPagado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoCapital => $composableBuilder(
    column: $table.montoCapital,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get montoInteres => $composableBuilder(
    column: $table.montoInteres,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fechaPago => $composableBuilder(
    column: $table.fechaPago,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get numeroCuota => $composableBuilder(
    column: $table.numeroCuota,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PagosDeudaTableOrderingComposer
    extends Composer<_$AppDatabase, $PagosDeudaTable> {
  $$PagosDeudaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deudaId => $composableBuilder(
    column: $table.deudaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cuentaId => $composableBuilder(
    column: $table.cuentaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoPagado => $composableBuilder(
    column: $table.montoPagado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoCapital => $composableBuilder(
    column: $table.montoCapital,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get montoInteres => $composableBuilder(
    column: $table.montoInteres,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fechaPago => $composableBuilder(
    column: $table.fechaPago,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get numeroCuota => $composableBuilder(
    column: $table.numeroCuota,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PagosDeudaTableAnnotationComposer
    extends Composer<_$AppDatabase, $PagosDeudaTable> {
  $$PagosDeudaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deudaId =>
      $composableBuilder(column: $table.deudaId, builder: (column) => column);

  GeneratedColumn<String> get cuentaId =>
      $composableBuilder(column: $table.cuentaId, builder: (column) => column);

  GeneratedColumn<double> get montoPagado => $composableBuilder(
    column: $table.montoPagado,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoCapital => $composableBuilder(
    column: $table.montoCapital,
    builder: (column) => column,
  );

  GeneratedColumn<double> get montoInteres => $composableBuilder(
    column: $table.montoInteres,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fechaPago =>
      $composableBuilder(column: $table.fechaPago, builder: (column) => column);

  GeneratedColumn<int> get numeroCuota => $composableBuilder(
    column: $table.numeroCuota,
    builder: (column) => column,
  );
}

class $$PagosDeudaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PagosDeudaTable,
          PagoDeudaRow,
          $$PagosDeudaTableFilterComposer,
          $$PagosDeudaTableOrderingComposer,
          $$PagosDeudaTableAnnotationComposer,
          $$PagosDeudaTableCreateCompanionBuilder,
          $$PagosDeudaTableUpdateCompanionBuilder,
          (
            PagoDeudaRow,
            BaseReferences<_$AppDatabase, $PagosDeudaTable, PagoDeudaRow>,
          ),
          PagoDeudaRow,
          PrefetchHooks Function()
        > {
  $$PagosDeudaTableTableManager(_$AppDatabase db, $PagosDeudaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PagosDeudaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PagosDeudaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PagosDeudaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> deudaId = const Value.absent(),
                Value<String?> cuentaId = const Value.absent(),
                Value<double> montoPagado = const Value.absent(),
                Value<double?> montoCapital = const Value.absent(),
                Value<double?> montoInteres = const Value.absent(),
                Value<DateTime> fechaPago = const Value.absent(),
                Value<int?> numeroCuota = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PagosDeudaCompanion(
                id: id,
                deudaId: deudaId,
                cuentaId: cuentaId,
                montoPagado: montoPagado,
                montoCapital: montoCapital,
                montoInteres: montoInteres,
                fechaPago: fechaPago,
                numeroCuota: numeroCuota,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String deudaId,
                Value<String?> cuentaId = const Value.absent(),
                required double montoPagado,
                Value<double?> montoCapital = const Value.absent(),
                Value<double?> montoInteres = const Value.absent(),
                required DateTime fechaPago,
                Value<int?> numeroCuota = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PagosDeudaCompanion.insert(
                id: id,
                deudaId: deudaId,
                cuentaId: cuentaId,
                montoPagado: montoPagado,
                montoCapital: montoCapital,
                montoInteres: montoInteres,
                fechaPago: fechaPago,
                numeroCuota: numeroCuota,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PagosDeudaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PagosDeudaTable,
      PagoDeudaRow,
      $$PagosDeudaTableFilterComposer,
      $$PagosDeudaTableOrderingComposer,
      $$PagosDeudaTableAnnotationComposer,
      $$PagosDeudaTableCreateCompanionBuilder,
      $$PagosDeudaTableUpdateCompanionBuilder,
      (
        PagoDeudaRow,
        BaseReferences<_$AppDatabase, $PagosDeudaTable, PagoDeudaRow>,
      ),
      PagoDeudaRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CuentasTableTableManager get cuentas =>
      $$CuentasTableTableManager(_db, _db.cuentas);
  $$CategoriasTableTableManager get categorias =>
      $$CategoriasTableTableManager(_db, _db.categorias);
  $$TransaccionesTableTableManager get transacciones =>
      $$TransaccionesTableTableManager(_db, _db.transacciones);
  $$DeudasTableTableManager get deudas =>
      $$DeudasTableTableManager(_db, _db.deudas);
  $$PagosDeudaTableTableManager get pagosDeuda =>
      $$PagosDeudaTableTableManager(_db, _db.pagosDeuda);
}
