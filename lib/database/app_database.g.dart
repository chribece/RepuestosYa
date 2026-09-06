// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SolicitudesTable extends Solicitudes
    with TableInfo<$SolicitudesTable, SolicitudLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SolicitudesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vehiculoIdMeta = const VerificationMeta(
    'vehiculoId',
  );
  @override
  late final GeneratedColumn<String> vehiculoId = GeneratedColumn<String>(
    'vehiculo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _piezaNombreMeta = const VerificationMeta(
    'piezaNombre',
  );
  @override
  late final GeneratedColumn<String> piezaNombre = GeneratedColumn<String>(
    'pieza_nombre',
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _repuestoIdMeta = const VerificationMeta(
    'repuestoId',
  );
  @override
  late final GeneratedColumn<String> repuestoId = GeneratedColumn<String>(
    'repuesto_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _descripcionMeta = const VerificationMeta(
    'descripcion',
  );
  @override
  late final GeneratedColumn<String> descripcion = GeneratedColumn<String>(
    'descripcion',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fotoUrlMeta = const VerificationMeta(
    'fotoUrl',
  );
  @override
  late final GeneratedColumn<String> fotoUrl = GeneratedColumn<String>(
    'foto_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncedMeta = const VerificationMeta('synced');
  @override
  late final GeneratedColumn<bool> synced = GeneratedColumn<bool>(
    'synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    clientId,
    vehiculoId,
    piezaNombre,
    categoriaId,
    repuestoId,
    estado,
    descripcion,
    fotoUrl,
    createdAt,
    updatedAt,
    synced,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'solicitudes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SolicitudLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    }
    if (data.containsKey('vehiculo_id')) {
      context.handle(
        _vehiculoIdMeta,
        vehiculoId.isAcceptableOrUnknown(data['vehiculo_id']!, _vehiculoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_vehiculoIdMeta);
    }
    if (data.containsKey('pieza_nombre')) {
      context.handle(
        _piezaNombreMeta,
        piezaNombre.isAcceptableOrUnknown(
          data['pieza_nombre']!,
          _piezaNombreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_piezaNombreMeta);
    }
    if (data.containsKey('categoria_id')) {
      context.handle(
        _categoriaIdMeta,
        categoriaId.isAcceptableOrUnknown(
          data['categoria_id']!,
          _categoriaIdMeta,
        ),
      );
    }
    if (data.containsKey('repuesto_id')) {
      context.handle(
        _repuestoIdMeta,
        repuestoId.isAcceptableOrUnknown(data['repuesto_id']!, _repuestoIdMeta),
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
    if (data.containsKey('descripcion')) {
      context.handle(
        _descripcionMeta,
        descripcion.isAcceptableOrUnknown(
          data['descripcion']!,
          _descripcionMeta,
        ),
      );
    }
    if (data.containsKey('foto_url')) {
      context.handle(
        _fotoUrlMeta,
        fotoUrl.isAcceptableOrUnknown(data['foto_url']!, _fotoUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('synced')) {
      context.handle(
        _syncedMeta,
        synced.isAcceptableOrUnknown(data['synced']!, _syncedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SolicitudLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SolicitudLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      ),
      vehiculoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vehiculo_id'],
      )!,
      piezaNombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pieza_nombre'],
      )!,
      categoriaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria_id'],
      ),
      repuestoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}repuesto_id'],
      ),
      estado: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}estado'],
      )!,
      descripcion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}descripcion'],
      ),
      fotoUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foto_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      synced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced'],
      )!,
    );
  }

  @override
  $SolicitudesTable createAlias(String alias) {
    return $SolicitudesTable(attachedDatabase, alias);
  }
}

class SolicitudLocal extends DataClass implements Insertable<SolicitudLocal> {
  final String id;
  final String? clientId;
  final String vehiculoId;
  final String piezaNombre;
  final String? categoriaId;
  final String? repuestoId;
  final String estado;
  final String? descripcion;
  final String? fotoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool synced;
  const SolicitudLocal({
    required this.id,
    this.clientId,
    required this.vehiculoId,
    required this.piezaNombre,
    this.categoriaId,
    this.repuestoId,
    required this.estado,
    this.descripcion,
    this.fotoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.synced,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || clientId != null) {
      map['client_id'] = Variable<String>(clientId);
    }
    map['vehiculo_id'] = Variable<String>(vehiculoId);
    map['pieza_nombre'] = Variable<String>(piezaNombre);
    if (!nullToAbsent || categoriaId != null) {
      map['categoria_id'] = Variable<String>(categoriaId);
    }
    if (!nullToAbsent || repuestoId != null) {
      map['repuesto_id'] = Variable<String>(repuestoId);
    }
    map['estado'] = Variable<String>(estado);
    if (!nullToAbsent || descripcion != null) {
      map['descripcion'] = Variable<String>(descripcion);
    }
    if (!nullToAbsent || fotoUrl != null) {
      map['foto_url'] = Variable<String>(fotoUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['synced'] = Variable<bool>(synced);
    return map;
  }

  SolicitudesCompanion toCompanion(bool nullToAbsent) {
    return SolicitudesCompanion(
      id: Value(id),
      clientId: clientId == null && nullToAbsent
          ? const Value.absent()
          : Value(clientId),
      vehiculoId: Value(vehiculoId),
      piezaNombre: Value(piezaNombre),
      categoriaId: categoriaId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoriaId),
      repuestoId: repuestoId == null && nullToAbsent
          ? const Value.absent()
          : Value(repuestoId),
      estado: Value(estado),
      descripcion: descripcion == null && nullToAbsent
          ? const Value.absent()
          : Value(descripcion),
      fotoUrl: fotoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(fotoUrl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      synced: Value(synced),
    );
  }

  factory SolicitudLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SolicitudLocal(
      id: serializer.fromJson<String>(json['id']),
      clientId: serializer.fromJson<String?>(json['clientId']),
      vehiculoId: serializer.fromJson<String>(json['vehiculoId']),
      piezaNombre: serializer.fromJson<String>(json['piezaNombre']),
      categoriaId: serializer.fromJson<String?>(json['categoriaId']),
      repuestoId: serializer.fromJson<String?>(json['repuestoId']),
      estado: serializer.fromJson<String>(json['estado']),
      descripcion: serializer.fromJson<String?>(json['descripcion']),
      fotoUrl: serializer.fromJson<String?>(json['fotoUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      synced: serializer.fromJson<bool>(json['synced']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'clientId': serializer.toJson<String?>(clientId),
      'vehiculoId': serializer.toJson<String>(vehiculoId),
      'piezaNombre': serializer.toJson<String>(piezaNombre),
      'categoriaId': serializer.toJson<String?>(categoriaId),
      'repuestoId': serializer.toJson<String?>(repuestoId),
      'estado': serializer.toJson<String>(estado),
      'descripcion': serializer.toJson<String?>(descripcion),
      'fotoUrl': serializer.toJson<String?>(fotoUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'synced': serializer.toJson<bool>(synced),
    };
  }

  SolicitudLocal copyWith({
    String? id,
    Value<String?> clientId = const Value.absent(),
    String? vehiculoId,
    String? piezaNombre,
    Value<String?> categoriaId = const Value.absent(),
    Value<String?> repuestoId = const Value.absent(),
    String? estado,
    Value<String?> descripcion = const Value.absent(),
    Value<String?> fotoUrl = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) => SolicitudLocal(
    id: id ?? this.id,
    clientId: clientId.present ? clientId.value : this.clientId,
    vehiculoId: vehiculoId ?? this.vehiculoId,
    piezaNombre: piezaNombre ?? this.piezaNombre,
    categoriaId: categoriaId.present ? categoriaId.value : this.categoriaId,
    repuestoId: repuestoId.present ? repuestoId.value : this.repuestoId,
    estado: estado ?? this.estado,
    descripcion: descripcion.present ? descripcion.value : this.descripcion,
    fotoUrl: fotoUrl.present ? fotoUrl.value : this.fotoUrl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    synced: synced ?? this.synced,
  );
  SolicitudLocal copyWithCompanion(SolicitudesCompanion data) {
    return SolicitudLocal(
      id: data.id.present ? data.id.value : this.id,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      vehiculoId: data.vehiculoId.present
          ? data.vehiculoId.value
          : this.vehiculoId,
      piezaNombre: data.piezaNombre.present
          ? data.piezaNombre.value
          : this.piezaNombre,
      categoriaId: data.categoriaId.present
          ? data.categoriaId.value
          : this.categoriaId,
      repuestoId: data.repuestoId.present
          ? data.repuestoId.value
          : this.repuestoId,
      estado: data.estado.present ? data.estado.value : this.estado,
      descripcion: data.descripcion.present
          ? data.descripcion.value
          : this.descripcion,
      fotoUrl: data.fotoUrl.present ? data.fotoUrl.value : this.fotoUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      synced: data.synced.present ? data.synced.value : this.synced,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SolicitudLocal(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('vehiculoId: $vehiculoId, ')
          ..write('piezaNombre: $piezaNombre, ')
          ..write('categoriaId: $categoriaId, ')
          ..write('repuestoId: $repuestoId, ')
          ..write('estado: $estado, ')
          ..write('descripcion: $descripcion, ')
          ..write('fotoUrl: $fotoUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    clientId,
    vehiculoId,
    piezaNombre,
    categoriaId,
    repuestoId,
    estado,
    descripcion,
    fotoUrl,
    createdAt,
    updatedAt,
    synced,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SolicitudLocal &&
          other.id == this.id &&
          other.clientId == this.clientId &&
          other.vehiculoId == this.vehiculoId &&
          other.piezaNombre == this.piezaNombre &&
          other.categoriaId == this.categoriaId &&
          other.repuestoId == this.repuestoId &&
          other.estado == this.estado &&
          other.descripcion == this.descripcion &&
          other.fotoUrl == this.fotoUrl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.synced == this.synced);
}

class SolicitudesCompanion extends UpdateCompanion<SolicitudLocal> {
  final Value<String> id;
  final Value<String?> clientId;
  final Value<String> vehiculoId;
  final Value<String> piezaNombre;
  final Value<String?> categoriaId;
  final Value<String?> repuestoId;
  final Value<String> estado;
  final Value<String?> descripcion;
  final Value<String?> fotoUrl;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> synced;
  final Value<int> rowid;
  const SolicitudesCompanion({
    this.id = const Value.absent(),
    this.clientId = const Value.absent(),
    this.vehiculoId = const Value.absent(),
    this.piezaNombre = const Value.absent(),
    this.categoriaId = const Value.absent(),
    this.repuestoId = const Value.absent(),
    this.estado = const Value.absent(),
    this.descripcion = const Value.absent(),
    this.fotoUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SolicitudesCompanion.insert({
    required String id,
    this.clientId = const Value.absent(),
    required String vehiculoId,
    required String piezaNombre,
    this.categoriaId = const Value.absent(),
    this.repuestoId = const Value.absent(),
    required String estado,
    this.descripcion = const Value.absent(),
    this.fotoUrl = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.synced = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       vehiculoId = Value(vehiculoId),
       piezaNombre = Value(piezaNombre),
       estado = Value(estado),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SolicitudLocal> custom({
    Expression<String>? id,
    Expression<String>? clientId,
    Expression<String>? vehiculoId,
    Expression<String>? piezaNombre,
    Expression<String>? categoriaId,
    Expression<String>? repuestoId,
    Expression<String>? estado,
    Expression<String>? descripcion,
    Expression<String>? fotoUrl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? synced,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (clientId != null) 'client_id': clientId,
      if (vehiculoId != null) 'vehiculo_id': vehiculoId,
      if (piezaNombre != null) 'pieza_nombre': piezaNombre,
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (repuestoId != null) 'repuesto_id': repuestoId,
      if (estado != null) 'estado': estado,
      if (descripcion != null) 'descripcion': descripcion,
      if (fotoUrl != null) 'foto_url': fotoUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (synced != null) 'synced': synced,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SolicitudesCompanion copyWith({
    Value<String>? id,
    Value<String?>? clientId,
    Value<String>? vehiculoId,
    Value<String>? piezaNombre,
    Value<String?>? categoriaId,
    Value<String?>? repuestoId,
    Value<String>? estado,
    Value<String?>? descripcion,
    Value<String?>? fotoUrl,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? synced,
    Value<int>? rowid,
  }) {
    return SolicitudesCompanion(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      piezaNombre: piezaNombre ?? this.piezaNombre,
      categoriaId: categoriaId ?? this.categoriaId,
      repuestoId: repuestoId ?? this.repuestoId,
      estado: estado ?? this.estado,
      descripcion: descripcion ?? this.descripcion,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (vehiculoId.present) {
      map['vehiculo_id'] = Variable<String>(vehiculoId.value);
    }
    if (piezaNombre.present) {
      map['pieza_nombre'] = Variable<String>(piezaNombre.value);
    }
    if (categoriaId.present) {
      map['categoria_id'] = Variable<String>(categoriaId.value);
    }
    if (repuestoId.present) {
      map['repuesto_id'] = Variable<String>(repuestoId.value);
    }
    if (estado.present) {
      map['estado'] = Variable<String>(estado.value);
    }
    if (descripcion.present) {
      map['descripcion'] = Variable<String>(descripcion.value);
    }
    if (fotoUrl.present) {
      map['foto_url'] = Variable<String>(fotoUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (synced.present) {
      map['synced'] = Variable<bool>(synced.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SolicitudesCompanion(')
          ..write('id: $id, ')
          ..write('clientId: $clientId, ')
          ..write('vehiculoId: $vehiculoId, ')
          ..write('piezaNombre: $piezaNombre, ')
          ..write('categoriaId: $categoriaId, ')
          ..write('repuestoId: $repuestoId, ')
          ..write('estado: $estado, ')
          ..write('descripcion: $descripcion, ')
          ..write('fotoUrl: $fotoUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('synced: $synced, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxTable extends Outbox with TableInfo<$OutboxTable, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('PENDING'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientId,
    entityType,
    operation,
    payload,
    status,
    attempts,
    lastError,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $OutboxTable createAlias(String alias) {
    return $OutboxTable(attachedDatabase, alias);
  }
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String clientId;
  final String entityType;
  final String operation;
  final String payload;
  final String status;
  final int attempts;
  final String? lastError;
  final DateTime createdAt;
  const OutboxData({
    required this.clientId,
    required this.entityType,
    required this.operation,
    required this.payload,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    map['entity_type'] = Variable<String>(entityType);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['status'] = Variable<String>(status);
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      clientId: Value(clientId),
      entityType: Value(entityType),
      operation: Value(operation),
      payload: Value(payload),
      status: Value(status),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      createdAt: Value(createdAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      clientId: serializer.fromJson<String>(json['clientId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      status: serializer.fromJson<String>(json['status']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'entityType': serializer.toJson<String>(entityType),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'status': serializer.toJson<String>(status),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  OutboxData copyWith({
    String? clientId,
    String? entityType,
    String? operation,
    String? payload,
    String? status,
    int? attempts,
    Value<String?> lastError = const Value.absent(),
    DateTime? createdAt,
  }) => OutboxData(
    clientId: clientId ?? this.clientId,
    entityType: entityType ?? this.entityType,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    lastError: lastError.present ? lastError.value : this.lastError,
    createdAt: createdAt ?? this.createdAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('clientId: $clientId, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    clientId,
    entityType,
    operation,
    payload,
    status,
    attempts,
    lastError,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.clientId == this.clientId &&
          other.entityType == this.entityType &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError &&
          other.createdAt == this.createdAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> clientId;
  final Value<String> entityType;
  final Value<String> operation;
  final Value<String> payload;
  final Value<String> status;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.clientId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String clientId,
    required String entityType,
    required String operation,
    required String payload,
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : clientId = Value(clientId),
       entityType = Value(entityType),
       operation = Value(operation),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<OutboxData> custom({
    Expression<String>? clientId,
    Expression<String>? entityType,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (entityType != null) 'entity_type': entityType,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? clientId,
    Value<String>? entityType,
    Value<String>? operation,
    Value<String>? payload,
    Value<String>? status,
    Value<int>? attempts,
    Value<String?>? lastError,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      clientId: clientId ?? this.clientId,
      entityType: entityType ?? this.entityType,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('clientId: $clientId, ')
          ..write('entityType: $entityType, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VehiculosCacheTable extends VehiculosCache
    with TableInfo<$VehiculosCacheTable, VehiculosCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VehiculosCacheTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _vinMeta = const VerificationMeta('vin');
  @override
  late final GeneratedColumn<String> vin = GeneratedColumn<String>(
    'vin',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nombre, vin, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vehiculos_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VehiculosCacheData> instance, {
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
    if (data.containsKey('vin')) {
      context.handle(
        _vinMeta,
        vin.isAcceptableOrUnknown(data['vin']!, _vinMeta),
      );
    } else if (isInserting) {
      context.missing(_vinMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VehiculosCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VehiculosCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      vin: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vin'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $VehiculosCacheTable createAlias(String alias) {
    return $VehiculosCacheTable(attachedDatabase, alias);
  }
}

class VehiculosCacheData extends DataClass
    implements Insertable<VehiculosCacheData> {
  final String id;
  final String nombre;
  final String vin;
  final String dataJson;
  const VehiculosCacheData({
    required this.id,
    required this.nombre,
    required this.vin,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    map['vin'] = Variable<String>(vin);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  VehiculosCacheCompanion toCompanion(bool nullToAbsent) {
    return VehiculosCacheCompanion(
      id: Value(id),
      nombre: Value(nombre),
      vin: Value(vin),
      dataJson: Value(dataJson),
    );
  }

  factory VehiculosCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VehiculosCacheData(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      vin: serializer.fromJson<String>(json['vin']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'vin': serializer.toJson<String>(vin),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  VehiculosCacheData copyWith({
    String? id,
    String? nombre,
    String? vin,
    String? dataJson,
  }) => VehiculosCacheData(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    vin: vin ?? this.vin,
    dataJson: dataJson ?? this.dataJson,
  );
  VehiculosCacheData copyWithCompanion(VehiculosCacheCompanion data) {
    return VehiculosCacheData(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      vin: data.vin.present ? data.vin.value : this.vin,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VehiculosCacheData(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('vin: $vin, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, vin, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VehiculosCacheData &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.vin == this.vin &&
          other.dataJson == this.dataJson);
}

class VehiculosCacheCompanion extends UpdateCompanion<VehiculosCacheData> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<String> vin;
  final Value<String> dataJson;
  final Value<int> rowid;
  const VehiculosCacheCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.vin = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VehiculosCacheCompanion.insert({
    required String id,
    required String nombre,
    required String vin,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre),
       vin = Value(vin),
       dataJson = Value(dataJson);
  static Insertable<VehiculosCacheData> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<String>? vin,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (vin != null) 'vin': vin,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VehiculosCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<String>? vin,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return VehiculosCacheCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      vin: vin ?? this.vin,
      dataJson: dataJson ?? this.dataJson,
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
    if (vin.present) {
      map['vin'] = Variable<String>(vin.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VehiculosCacheCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('vin: $vin, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DireccionesCacheTable extends DireccionesCache
    with TableInfo<$DireccionesCacheTable, DireccionesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DireccionesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aliasMeta = const VerificationMeta('alias');
  @override
  late final GeneratedColumn<String> alias = GeneratedColumn<String>(
    'alias',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detalleMeta = const VerificationMeta(
    'detalle',
  );
  @override
  late final GeneratedColumn<String> detalle = GeneratedColumn<String>(
    'detalle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, alias, detalle, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'direcciones_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<DireccionesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('alias')) {
      context.handle(
        _aliasMeta,
        alias.isAcceptableOrUnknown(data['alias']!, _aliasMeta),
      );
    } else if (isInserting) {
      context.missing(_aliasMeta);
    }
    if (data.containsKey('detalle')) {
      context.handle(
        _detalleMeta,
        detalle.isAcceptableOrUnknown(data['detalle']!, _detalleMeta),
      );
    } else if (isInserting) {
      context.missing(_detalleMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DireccionesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DireccionesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      alias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alias'],
      )!,
      detalle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}detalle'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $DireccionesCacheTable createAlias(String alias) {
    return $DireccionesCacheTable(attachedDatabase, alias);
  }
}

class DireccionesCacheData extends DataClass
    implements Insertable<DireccionesCacheData> {
  final String id;
  final String alias;
  final String detalle;
  final String dataJson;
  const DireccionesCacheData({
    required this.id,
    required this.alias,
    required this.detalle,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['alias'] = Variable<String>(alias);
    map['detalle'] = Variable<String>(detalle);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  DireccionesCacheCompanion toCompanion(bool nullToAbsent) {
    return DireccionesCacheCompanion(
      id: Value(id),
      alias: Value(alias),
      detalle: Value(detalle),
      dataJson: Value(dataJson),
    );
  }

  factory DireccionesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DireccionesCacheData(
      id: serializer.fromJson<String>(json['id']),
      alias: serializer.fromJson<String>(json['alias']),
      detalle: serializer.fromJson<String>(json['detalle']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'alias': serializer.toJson<String>(alias),
      'detalle': serializer.toJson<String>(detalle),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  DireccionesCacheData copyWith({
    String? id,
    String? alias,
    String? detalle,
    String? dataJson,
  }) => DireccionesCacheData(
    id: id ?? this.id,
    alias: alias ?? this.alias,
    detalle: detalle ?? this.detalle,
    dataJson: dataJson ?? this.dataJson,
  );
  DireccionesCacheData copyWithCompanion(DireccionesCacheCompanion data) {
    return DireccionesCacheData(
      id: data.id.present ? data.id.value : this.id,
      alias: data.alias.present ? data.alias.value : this.alias,
      detalle: data.detalle.present ? data.detalle.value : this.detalle,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DireccionesCacheData(')
          ..write('id: $id, ')
          ..write('alias: $alias, ')
          ..write('detalle: $detalle, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, alias, detalle, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DireccionesCacheData &&
          other.id == this.id &&
          other.alias == this.alias &&
          other.detalle == this.detalle &&
          other.dataJson == this.dataJson);
}

class DireccionesCacheCompanion extends UpdateCompanion<DireccionesCacheData> {
  final Value<String> id;
  final Value<String> alias;
  final Value<String> detalle;
  final Value<String> dataJson;
  final Value<int> rowid;
  const DireccionesCacheCompanion({
    this.id = const Value.absent(),
    this.alias = const Value.absent(),
    this.detalle = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DireccionesCacheCompanion.insert({
    required String id,
    required String alias,
    required String detalle,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       alias = Value(alias),
       detalle = Value(detalle),
       dataJson = Value(dataJson);
  static Insertable<DireccionesCacheData> custom({
    Expression<String>? id,
    Expression<String>? alias,
    Expression<String>? detalle,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (alias != null) 'alias': alias,
      if (detalle != null) 'detalle': detalle,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DireccionesCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? alias,
    Value<String>? detalle,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return DireccionesCacheCompanion(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      detalle: detalle ?? this.detalle,
      dataJson: dataJson ?? this.dataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (alias.present) {
      map['alias'] = Variable<String>(alias.value);
    }
    if (detalle.present) {
      map['detalle'] = Variable<String>(detalle.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DireccionesCacheCompanion(')
          ..write('id: $id, ')
          ..write('alias: $alias, ')
          ..write('detalle: $detalle, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriasCacheTable extends CategoriasCache
    with TableInfo<$CategoriasCacheTable, CategoriasCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriasCacheTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _slugMeta = const VerificationMeta('slug');
  @override
  late final GeneratedColumn<String> slug = GeneratedColumn<String>(
    'slug',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, nombre, slug, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categorias_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CategoriasCacheData> instance, {
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
    if (data.containsKey('slug')) {
      context.handle(
        _slugMeta,
        slug.isAcceptableOrUnknown(data['slug']!, _slugMeta),
      );
    } else if (isInserting) {
      context.missing(_slugMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CategoriasCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CategoriasCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      slug: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}slug'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $CategoriasCacheTable createAlias(String alias) {
    return $CategoriasCacheTable(attachedDatabase, alias);
  }
}

class CategoriasCacheData extends DataClass
    implements Insertable<CategoriasCacheData> {
  final String id;
  final String nombre;
  final String slug;
  final String dataJson;
  const CategoriasCacheData({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre'] = Variable<String>(nombre);
    map['slug'] = Variable<String>(slug);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  CategoriasCacheCompanion toCompanion(bool nullToAbsent) {
    return CategoriasCacheCompanion(
      id: Value(id),
      nombre: Value(nombre),
      slug: Value(slug),
      dataJson: Value(dataJson),
    );
  }

  factory CategoriasCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CategoriasCacheData(
      id: serializer.fromJson<String>(json['id']),
      nombre: serializer.fromJson<String>(json['nombre']),
      slug: serializer.fromJson<String>(json['slug']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombre': serializer.toJson<String>(nombre),
      'slug': serializer.toJson<String>(slug),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  CategoriasCacheData copyWith({
    String? id,
    String? nombre,
    String? slug,
    String? dataJson,
  }) => CategoriasCacheData(
    id: id ?? this.id,
    nombre: nombre ?? this.nombre,
    slug: slug ?? this.slug,
    dataJson: dataJson ?? this.dataJson,
  );
  CategoriasCacheData copyWithCompanion(CategoriasCacheCompanion data) {
    return CategoriasCacheData(
      id: data.id.present ? data.id.value : this.id,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      slug: data.slug.present ? data.slug.value : this.slug,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CategoriasCacheData(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('slug: $slug, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, nombre, slug, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CategoriasCacheData &&
          other.id == this.id &&
          other.nombre == this.nombre &&
          other.slug == this.slug &&
          other.dataJson == this.dataJson);
}

class CategoriasCacheCompanion extends UpdateCompanion<CategoriasCacheData> {
  final Value<String> id;
  final Value<String> nombre;
  final Value<String> slug;
  final Value<String> dataJson;
  final Value<int> rowid;
  const CategoriasCacheCompanion({
    this.id = const Value.absent(),
    this.nombre = const Value.absent(),
    this.slug = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriasCacheCompanion.insert({
    required String id,
    required String nombre,
    required String slug,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombre = Value(nombre),
       slug = Value(slug),
       dataJson = Value(dataJson);
  static Insertable<CategoriasCacheData> custom({
    Expression<String>? id,
    Expression<String>? nombre,
    Expression<String>? slug,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombre != null) 'nombre': nombre,
      if (slug != null) 'slug': slug,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriasCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? nombre,
    Value<String>? slug,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return CategoriasCacheCompanion(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      slug: slug ?? this.slug,
      dataJson: dataJson ?? this.dataJson,
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
    if (slug.present) {
      map['slug'] = Variable<String>(slug.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriasCacheCompanion(')
          ..write('id: $id, ')
          ..write('nombre: $nombre, ')
          ..write('slug: $slug, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PartesCacheTable extends PartesCache
    with TableInfo<$PartesCacheTable, PartesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PartesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _nombreMeta = const VerificationMeta('nombre');
  @override
  late final GeneratedColumn<String> nombre = GeneratedColumn<String>(
    'nombre',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, categoriaId, nombre, dataJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'partes_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<PartesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
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
    if (data.containsKey('nombre')) {
      context.handle(
        _nombreMeta,
        nombre.isAcceptableOrUnknown(data['nombre']!, _nombreMeta),
      );
    } else if (isInserting) {
      context.missing(_nombreMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PartesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PartesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      categoriaId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}categoria_id'],
      )!,
      nombre: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
    );
  }

  @override
  $PartesCacheTable createAlias(String alias) {
    return $PartesCacheTable(attachedDatabase, alias);
  }
}

class PartesCacheData extends DataClass implements Insertable<PartesCacheData> {
  final String id;
  final String categoriaId;
  final String nombre;
  final String dataJson;
  const PartesCacheData({
    required this.id,
    required this.categoriaId,
    required this.nombre,
    required this.dataJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['categoria_id'] = Variable<String>(categoriaId);
    map['nombre'] = Variable<String>(nombre);
    map['data_json'] = Variable<String>(dataJson);
    return map;
  }

  PartesCacheCompanion toCompanion(bool nullToAbsent) {
    return PartesCacheCompanion(
      id: Value(id),
      categoriaId: Value(categoriaId),
      nombre: Value(nombre),
      dataJson: Value(dataJson),
    );
  }

  factory PartesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PartesCacheData(
      id: serializer.fromJson<String>(json['id']),
      categoriaId: serializer.fromJson<String>(json['categoriaId']),
      nombre: serializer.fromJson<String>(json['nombre']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'categoriaId': serializer.toJson<String>(categoriaId),
      'nombre': serializer.toJson<String>(nombre),
      'dataJson': serializer.toJson<String>(dataJson),
    };
  }

  PartesCacheData copyWith({
    String? id,
    String? categoriaId,
    String? nombre,
    String? dataJson,
  }) => PartesCacheData(
    id: id ?? this.id,
    categoriaId: categoriaId ?? this.categoriaId,
    nombre: nombre ?? this.nombre,
    dataJson: dataJson ?? this.dataJson,
  );
  PartesCacheData copyWithCompanion(PartesCacheCompanion data) {
    return PartesCacheData(
      id: data.id.present ? data.id.value : this.id,
      categoriaId: data.categoriaId.present
          ? data.categoriaId.value
          : this.categoriaId,
      nombre: data.nombre.present ? data.nombre.value : this.nombre,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PartesCacheData(')
          ..write('id: $id, ')
          ..write('categoriaId: $categoriaId, ')
          ..write('nombre: $nombre, ')
          ..write('dataJson: $dataJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, categoriaId, nombre, dataJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PartesCacheData &&
          other.id == this.id &&
          other.categoriaId == this.categoriaId &&
          other.nombre == this.nombre &&
          other.dataJson == this.dataJson);
}

class PartesCacheCompanion extends UpdateCompanion<PartesCacheData> {
  final Value<String> id;
  final Value<String> categoriaId;
  final Value<String> nombre;
  final Value<String> dataJson;
  final Value<int> rowid;
  const PartesCacheCompanion({
    this.id = const Value.absent(),
    this.categoriaId = const Value.absent(),
    this.nombre = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PartesCacheCompanion.insert({
    required String id,
    required String categoriaId,
    required String nombre,
    required String dataJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       categoriaId = Value(categoriaId),
       nombre = Value(nombre),
       dataJson = Value(dataJson);
  static Insertable<PartesCacheData> custom({
    Expression<String>? id,
    Expression<String>? categoriaId,
    Expression<String>? nombre,
    Expression<String>? dataJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (categoriaId != null) 'categoria_id': categoriaId,
      if (nombre != null) 'nombre': nombre,
      if (dataJson != null) 'data_json': dataJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PartesCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? categoriaId,
    Value<String>? nombre,
    Value<String>? dataJson,
    Value<int>? rowid,
  }) {
    return PartesCacheCompanion(
      id: id ?? this.id,
      categoriaId: categoriaId ?? this.categoriaId,
      nombre: nombre ?? this.nombre,
      dataJson: dataJson ?? this.dataJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (categoriaId.present) {
      map['categoria_id'] = Variable<String>(categoriaId.value);
    }
    if (nombre.present) {
      map['nombre'] = Variable<String>(nombre.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PartesCacheCompanion(')
          ..write('id: $id, ')
          ..write('categoriaId: $categoriaId, ')
          ..write('nombre: $nombre, ')
          ..write('dataJson: $dataJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PerfilAlmacenCacheTable extends PerfilAlmacenCache
    with TableInfo<$PerfilAlmacenCacheTable, PerfilAlmacenCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PerfilAlmacenCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nombreComercialMeta = const VerificationMeta(
    'nombreComercial',
  );
  @override
  late final GeneratedColumn<String> nombreComercial = GeneratedColumn<String>(
    'nombre_comercial',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verificationStatusMeta =
      const VerificationMeta('verificationStatus');
  @override
  late final GeneratedColumn<String> verificationStatus =
      GeneratedColumn<String>(
        'verification_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nombreComercial,
    verificationStatus,
    dataJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'perfil_almacen_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<PerfilAlmacenCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nombre_comercial')) {
      context.handle(
        _nombreComercialMeta,
        nombreComercial.isAcceptableOrUnknown(
          data['nombre_comercial']!,
          _nombreComercialMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nombreComercialMeta);
    }
    if (data.containsKey('verification_status')) {
      context.handle(
        _verificationStatusMeta,
        verificationStatus.isAcceptableOrUnknown(
          data['verification_status']!,
          _verificationStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verificationStatusMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PerfilAlmacenCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PerfilAlmacenCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nombreComercial: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nombre_comercial'],
      )!,
      verificationStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verification_status'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PerfilAlmacenCacheTable createAlias(String alias) {
    return $PerfilAlmacenCacheTable(attachedDatabase, alias);
  }
}

class PerfilAlmacenCacheData extends DataClass
    implements Insertable<PerfilAlmacenCacheData> {
  final String id;
  final String nombreComercial;
  final String verificationStatus;
  final String dataJson;
  final DateTime updatedAt;
  const PerfilAlmacenCacheData({
    required this.id,
    required this.nombreComercial,
    required this.verificationStatus,
    required this.dataJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nombre_comercial'] = Variable<String>(nombreComercial);
    map['verification_status'] = Variable<String>(verificationStatus);
    map['data_json'] = Variable<String>(dataJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PerfilAlmacenCacheCompanion toCompanion(bool nullToAbsent) {
    return PerfilAlmacenCacheCompanion(
      id: Value(id),
      nombreComercial: Value(nombreComercial),
      verificationStatus: Value(verificationStatus),
      dataJson: Value(dataJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory PerfilAlmacenCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PerfilAlmacenCacheData(
      id: serializer.fromJson<String>(json['id']),
      nombreComercial: serializer.fromJson<String>(json['nombreComercial']),
      verificationStatus: serializer.fromJson<String>(
        json['verificationStatus'],
      ),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nombreComercial': serializer.toJson<String>(nombreComercial),
      'verificationStatus': serializer.toJson<String>(verificationStatus),
      'dataJson': serializer.toJson<String>(dataJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  PerfilAlmacenCacheData copyWith({
    String? id,
    String? nombreComercial,
    String? verificationStatus,
    String? dataJson,
    DateTime? updatedAt,
  }) => PerfilAlmacenCacheData(
    id: id ?? this.id,
    nombreComercial: nombreComercial ?? this.nombreComercial,
    verificationStatus: verificationStatus ?? this.verificationStatus,
    dataJson: dataJson ?? this.dataJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  PerfilAlmacenCacheData copyWithCompanion(PerfilAlmacenCacheCompanion data) {
    return PerfilAlmacenCacheData(
      id: data.id.present ? data.id.value : this.id,
      nombreComercial: data.nombreComercial.present
          ? data.nombreComercial.value
          : this.nombreComercial,
      verificationStatus: data.verificationStatus.present
          ? data.verificationStatus.value
          : this.verificationStatus,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PerfilAlmacenCacheData(')
          ..write('id: $id, ')
          ..write('nombreComercial: $nombreComercial, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, nombreComercial, verificationStatus, dataJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PerfilAlmacenCacheData &&
          other.id == this.id &&
          other.nombreComercial == this.nombreComercial &&
          other.verificationStatus == this.verificationStatus &&
          other.dataJson == this.dataJson &&
          other.updatedAt == this.updatedAt);
}

class PerfilAlmacenCacheCompanion
    extends UpdateCompanion<PerfilAlmacenCacheData> {
  final Value<String> id;
  final Value<String> nombreComercial;
  final Value<String> verificationStatus;
  final Value<String> dataJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PerfilAlmacenCacheCompanion({
    this.id = const Value.absent(),
    this.nombreComercial = const Value.absent(),
    this.verificationStatus = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PerfilAlmacenCacheCompanion.insert({
    required String id,
    required String nombreComercial,
    required String verificationStatus,
    required String dataJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nombreComercial = Value(nombreComercial),
       verificationStatus = Value(verificationStatus),
       dataJson = Value(dataJson),
       updatedAt = Value(updatedAt);
  static Insertable<PerfilAlmacenCacheData> custom({
    Expression<String>? id,
    Expression<String>? nombreComercial,
    Expression<String>? verificationStatus,
    Expression<String>? dataJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nombreComercial != null) 'nombre_comercial': nombreComercial,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (dataJson != null) 'data_json': dataJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PerfilAlmacenCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? nombreComercial,
    Value<String>? verificationStatus,
    Value<String>? dataJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PerfilAlmacenCacheCompanion(
      id: id ?? this.id,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      dataJson: dataJson ?? this.dataJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nombreComercial.present) {
      map['nombre_comercial'] = Variable<String>(nombreComercial.value);
    }
    if (verificationStatus.present) {
      map['verification_status'] = Variable<String>(verificationStatus.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PerfilAlmacenCacheCompanion(')
          ..write('id: $id, ')
          ..write('nombreComercial: $nombreComercial, ')
          ..write('verificationStatus: $verificationStatus, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SolicitudesTable solicitudes = $SolicitudesTable(this);
  late final $OutboxTable outbox = $OutboxTable(this);
  late final $VehiculosCacheTable vehiculosCache = $VehiculosCacheTable(this);
  late final $DireccionesCacheTable direccionesCache = $DireccionesCacheTable(
    this,
  );
  late final $CategoriasCacheTable categoriasCache = $CategoriasCacheTable(
    this,
  );
  late final $PartesCacheTable partesCache = $PartesCacheTable(this);
  late final $PerfilAlmacenCacheTable perfilAlmacenCache =
      $PerfilAlmacenCacheTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    solicitudes,
    outbox,
    vehiculosCache,
    direccionesCache,
    categoriasCache,
    partesCache,
    perfilAlmacenCache,
  ];
}

typedef $$SolicitudesTableCreateCompanionBuilder =
    SolicitudesCompanion Function({
      required String id,
      Value<String?> clientId,
      required String vehiculoId,
      required String piezaNombre,
      Value<String?> categoriaId,
      Value<String?> repuestoId,
      required String estado,
      Value<String?> descripcion,
      Value<String?> fotoUrl,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<bool> synced,
      Value<int> rowid,
    });
typedef $$SolicitudesTableUpdateCompanionBuilder =
    SolicitudesCompanion Function({
      Value<String> id,
      Value<String?> clientId,
      Value<String> vehiculoId,
      Value<String> piezaNombre,
      Value<String?> categoriaId,
      Value<String?> repuestoId,
      Value<String> estado,
      Value<String?> descripcion,
      Value<String?> fotoUrl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> synced,
      Value<int> rowid,
    });

class $$SolicitudesTableFilterComposer
    extends Composer<_$AppDatabase, $SolicitudesTable> {
  $$SolicitudesTableFilterComposer({
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

  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vehiculoId => $composableBuilder(
    column: $table.vehiculoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get piezaNombre => $composableBuilder(
    column: $table.piezaNombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get repuestoId => $composableBuilder(
    column: $table.repuestoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fotoUrl => $composableBuilder(
    column: $table.fotoUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SolicitudesTableOrderingComposer
    extends Composer<_$AppDatabase, $SolicitudesTable> {
  $$SolicitudesTableOrderingComposer({
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

  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vehiculoId => $composableBuilder(
    column: $table.vehiculoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get piezaNombre => $composableBuilder(
    column: $table.piezaNombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get repuestoId => $composableBuilder(
    column: $table.repuestoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get estado => $composableBuilder(
    column: $table.estado,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fotoUrl => $composableBuilder(
    column: $table.fotoUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get synced => $composableBuilder(
    column: $table.synced,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SolicitudesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SolicitudesTable> {
  $$SolicitudesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get vehiculoId => $composableBuilder(
    column: $table.vehiculoId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get piezaNombre => $composableBuilder(
    column: $table.piezaNombre,
    builder: (column) => column,
  );

  GeneratedColumn<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get repuestoId => $composableBuilder(
    column: $table.repuestoId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get estado =>
      $composableBuilder(column: $table.estado, builder: (column) => column);

  GeneratedColumn<String> get descripcion => $composableBuilder(
    column: $table.descripcion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fotoUrl =>
      $composableBuilder(column: $table.fotoUrl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get synced =>
      $composableBuilder(column: $table.synced, builder: (column) => column);
}

class $$SolicitudesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SolicitudesTable,
          SolicitudLocal,
          $$SolicitudesTableFilterComposer,
          $$SolicitudesTableOrderingComposer,
          $$SolicitudesTableAnnotationComposer,
          $$SolicitudesTableCreateCompanionBuilder,
          $$SolicitudesTableUpdateCompanionBuilder,
          (
            SolicitudLocal,
            BaseReferences<_$AppDatabase, $SolicitudesTable, SolicitudLocal>,
          ),
          SolicitudLocal,
          PrefetchHooks Function()
        > {
  $$SolicitudesTableTableManager(_$AppDatabase db, $SolicitudesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SolicitudesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SolicitudesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SolicitudesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> clientId = const Value.absent(),
                Value<String> vehiculoId = const Value.absent(),
                Value<String> piezaNombre = const Value.absent(),
                Value<String?> categoriaId = const Value.absent(),
                Value<String?> repuestoId = const Value.absent(),
                Value<String> estado = const Value.absent(),
                Value<String?> descripcion = const Value.absent(),
                Value<String?> fotoUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SolicitudesCompanion(
                id: id,
                clientId: clientId,
                vehiculoId: vehiculoId,
                piezaNombre: piezaNombre,
                categoriaId: categoriaId,
                repuestoId: repuestoId,
                estado: estado,
                descripcion: descripcion,
                fotoUrl: fotoUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> clientId = const Value.absent(),
                required String vehiculoId,
                required String piezaNombre,
                Value<String?> categoriaId = const Value.absent(),
                Value<String?> repuestoId = const Value.absent(),
                required String estado,
                Value<String?> descripcion = const Value.absent(),
                Value<String?> fotoUrl = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<bool> synced = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SolicitudesCompanion.insert(
                id: id,
                clientId: clientId,
                vehiculoId: vehiculoId,
                piezaNombre: piezaNombre,
                categoriaId: categoriaId,
                repuestoId: repuestoId,
                estado: estado,
                descripcion: descripcion,
                fotoUrl: fotoUrl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                synced: synced,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SolicitudesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SolicitudesTable,
      SolicitudLocal,
      $$SolicitudesTableFilterComposer,
      $$SolicitudesTableOrderingComposer,
      $$SolicitudesTableAnnotationComposer,
      $$SolicitudesTableCreateCompanionBuilder,
      $$SolicitudesTableUpdateCompanionBuilder,
      (
        SolicitudLocal,
        BaseReferences<_$AppDatabase, $SolicitudesTable, SolicitudLocal>,
      ),
      SolicitudLocal,
      PrefetchHooks Function()
    >;
typedef $$OutboxTableCreateCompanionBuilder =
    OutboxCompanion Function({
      required String clientId,
      required String entityType,
      required String operation,
      required String payload,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$OutboxTableUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> clientId,
      Value<String> entityType,
      Value<String> operation,
      Value<String> payload,
      Value<String> status,
      Value<int> attempts,
      Value<String?> lastError,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$OutboxTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxTable> {
  $$OutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$OutboxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxTable,
          OutboxData,
          $$OutboxTableFilterComposer,
          $$OutboxTableOrderingComposer,
          $$OutboxTableAnnotationComposer,
          $$OutboxTableCreateCompanionBuilder,
          $$OutboxTableUpdateCompanionBuilder,
          (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
          OutboxData,
          PrefetchHooks Function()
        > {
  $$OutboxTableTableManager(_$AppDatabase db, $OutboxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                clientId: clientId,
                entityType: entityType,
                operation: operation,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientId,
                required String entityType,
                required String operation,
                required String payload,
                Value<String> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                clientId: clientId,
                entityType: entityType,
                operation: operation,
                payload: payload,
                status: status,
                attempts: attempts,
                lastError: lastError,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxTable,
      OutboxData,
      $$OutboxTableFilterComposer,
      $$OutboxTableOrderingComposer,
      $$OutboxTableAnnotationComposer,
      $$OutboxTableCreateCompanionBuilder,
      $$OutboxTableUpdateCompanionBuilder,
      (OutboxData, BaseReferences<_$AppDatabase, $OutboxTable, OutboxData>),
      OutboxData,
      PrefetchHooks Function()
    >;
typedef $$VehiculosCacheTableCreateCompanionBuilder =
    VehiculosCacheCompanion Function({
      required String id,
      required String nombre,
      required String vin,
      required String dataJson,
      Value<int> rowid,
    });
typedef $$VehiculosCacheTableUpdateCompanionBuilder =
    VehiculosCacheCompanion Function({
      Value<String> id,
      Value<String> nombre,
      Value<String> vin,
      Value<String> dataJson,
      Value<int> rowid,
    });

class $$VehiculosCacheTableFilterComposer
    extends Composer<_$AppDatabase, $VehiculosCacheTable> {
  $$VehiculosCacheTableFilterComposer({
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

  ColumnFilters<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VehiculosCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $VehiculosCacheTable> {
  $$VehiculosCacheTableOrderingComposer({
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

  ColumnOrderings<String> get vin => $composableBuilder(
    column: $table.vin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VehiculosCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $VehiculosCacheTable> {
  $$VehiculosCacheTableAnnotationComposer({
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

  GeneratedColumn<String> get vin =>
      $composableBuilder(column: $table.vin, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$VehiculosCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VehiculosCacheTable,
          VehiculosCacheData,
          $$VehiculosCacheTableFilterComposer,
          $$VehiculosCacheTableOrderingComposer,
          $$VehiculosCacheTableAnnotationComposer,
          $$VehiculosCacheTableCreateCompanionBuilder,
          $$VehiculosCacheTableUpdateCompanionBuilder,
          (
            VehiculosCacheData,
            BaseReferences<
              _$AppDatabase,
              $VehiculosCacheTable,
              VehiculosCacheData
            >,
          ),
          VehiculosCacheData,
          PrefetchHooks Function()
        > {
  $$VehiculosCacheTableTableManager(
    _$AppDatabase db,
    $VehiculosCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VehiculosCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VehiculosCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VehiculosCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> vin = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VehiculosCacheCompanion(
                id: id,
                nombre: nombre,
                vin: vin,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                required String vin,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => VehiculosCacheCompanion.insert(
                id: id,
                nombre: nombre,
                vin: vin,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VehiculosCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VehiculosCacheTable,
      VehiculosCacheData,
      $$VehiculosCacheTableFilterComposer,
      $$VehiculosCacheTableOrderingComposer,
      $$VehiculosCacheTableAnnotationComposer,
      $$VehiculosCacheTableCreateCompanionBuilder,
      $$VehiculosCacheTableUpdateCompanionBuilder,
      (
        VehiculosCacheData,
        BaseReferences<_$AppDatabase, $VehiculosCacheTable, VehiculosCacheData>,
      ),
      VehiculosCacheData,
      PrefetchHooks Function()
    >;
typedef $$DireccionesCacheTableCreateCompanionBuilder =
    DireccionesCacheCompanion Function({
      required String id,
      required String alias,
      required String detalle,
      required String dataJson,
      Value<int> rowid,
    });
typedef $$DireccionesCacheTableUpdateCompanionBuilder =
    DireccionesCacheCompanion Function({
      Value<String> id,
      Value<String> alias,
      Value<String> detalle,
      Value<String> dataJson,
      Value<int> rowid,
    });

class $$DireccionesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $DireccionesCacheTable> {
  $$DireccionesCacheTableFilterComposer({
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

  ColumnFilters<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get detalle => $composableBuilder(
    column: $table.detalle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DireccionesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $DireccionesCacheTable> {
  $$DireccionesCacheTableOrderingComposer({
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

  ColumnOrderings<String> get alias => $composableBuilder(
    column: $table.alias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get detalle => $composableBuilder(
    column: $table.detalle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DireccionesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $DireccionesCacheTable> {
  $$DireccionesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get alias =>
      $composableBuilder(column: $table.alias, builder: (column) => column);

  GeneratedColumn<String> get detalle =>
      $composableBuilder(column: $table.detalle, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$DireccionesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DireccionesCacheTable,
          DireccionesCacheData,
          $$DireccionesCacheTableFilterComposer,
          $$DireccionesCacheTableOrderingComposer,
          $$DireccionesCacheTableAnnotationComposer,
          $$DireccionesCacheTableCreateCompanionBuilder,
          $$DireccionesCacheTableUpdateCompanionBuilder,
          (
            DireccionesCacheData,
            BaseReferences<
              _$AppDatabase,
              $DireccionesCacheTable,
              DireccionesCacheData
            >,
          ),
          DireccionesCacheData,
          PrefetchHooks Function()
        > {
  $$DireccionesCacheTableTableManager(
    _$AppDatabase db,
    $DireccionesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DireccionesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DireccionesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DireccionesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> alias = const Value.absent(),
                Value<String> detalle = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DireccionesCacheCompanion(
                id: id,
                alias: alias,
                detalle: detalle,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String alias,
                required String detalle,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => DireccionesCacheCompanion.insert(
                id: id,
                alias: alias,
                detalle: detalle,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DireccionesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DireccionesCacheTable,
      DireccionesCacheData,
      $$DireccionesCacheTableFilterComposer,
      $$DireccionesCacheTableOrderingComposer,
      $$DireccionesCacheTableAnnotationComposer,
      $$DireccionesCacheTableCreateCompanionBuilder,
      $$DireccionesCacheTableUpdateCompanionBuilder,
      (
        DireccionesCacheData,
        BaseReferences<
          _$AppDatabase,
          $DireccionesCacheTable,
          DireccionesCacheData
        >,
      ),
      DireccionesCacheData,
      PrefetchHooks Function()
    >;
typedef $$CategoriasCacheTableCreateCompanionBuilder =
    CategoriasCacheCompanion Function({
      required String id,
      required String nombre,
      required String slug,
      required String dataJson,
      Value<int> rowid,
    });
typedef $$CategoriasCacheTableUpdateCompanionBuilder =
    CategoriasCacheCompanion Function({
      Value<String> id,
      Value<String> nombre,
      Value<String> slug,
      Value<String> dataJson,
      Value<int> rowid,
    });

class $$CategoriasCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriasCacheTable> {
  $$CategoriasCacheTableFilterComposer({
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

  ColumnFilters<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriasCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriasCacheTable> {
  $$CategoriasCacheTableOrderingComposer({
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

  ColumnOrderings<String> get slug => $composableBuilder(
    column: $table.slug,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriasCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriasCacheTable> {
  $$CategoriasCacheTableAnnotationComposer({
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

  GeneratedColumn<String> get slug =>
      $composableBuilder(column: $table.slug, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$CategoriasCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriasCacheTable,
          CategoriasCacheData,
          $$CategoriasCacheTableFilterComposer,
          $$CategoriasCacheTableOrderingComposer,
          $$CategoriasCacheTableAnnotationComposer,
          $$CategoriasCacheTableCreateCompanionBuilder,
          $$CategoriasCacheTableUpdateCompanionBuilder,
          (
            CategoriasCacheData,
            BaseReferences<
              _$AppDatabase,
              $CategoriasCacheTable,
              CategoriasCacheData
            >,
          ),
          CategoriasCacheData,
          PrefetchHooks Function()
        > {
  $$CategoriasCacheTableTableManager(
    _$AppDatabase db,
    $CategoriasCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriasCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriasCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriasCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> slug = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriasCacheCompanion(
                id: id,
                nombre: nombre,
                slug: slug,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombre,
                required String slug,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => CategoriasCacheCompanion.insert(
                id: id,
                nombre: nombre,
                slug: slug,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriasCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriasCacheTable,
      CategoriasCacheData,
      $$CategoriasCacheTableFilterComposer,
      $$CategoriasCacheTableOrderingComposer,
      $$CategoriasCacheTableAnnotationComposer,
      $$CategoriasCacheTableCreateCompanionBuilder,
      $$CategoriasCacheTableUpdateCompanionBuilder,
      (
        CategoriasCacheData,
        BaseReferences<
          _$AppDatabase,
          $CategoriasCacheTable,
          CategoriasCacheData
        >,
      ),
      CategoriasCacheData,
      PrefetchHooks Function()
    >;
typedef $$PartesCacheTableCreateCompanionBuilder =
    PartesCacheCompanion Function({
      required String id,
      required String categoriaId,
      required String nombre,
      required String dataJson,
      Value<int> rowid,
    });
typedef $$PartesCacheTableUpdateCompanionBuilder =
    PartesCacheCompanion Function({
      Value<String> id,
      Value<String> categoriaId,
      Value<String> nombre,
      Value<String> dataJson,
      Value<int> rowid,
    });

class $$PartesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $PartesCacheTable> {
  $$PartesCacheTableFilterComposer({
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

  ColumnFilters<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PartesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $PartesCacheTable> {
  $$PartesCacheTableOrderingComposer({
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

  ColumnOrderings<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nombre => $composableBuilder(
    column: $table.nombre,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PartesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $PartesCacheTable> {
  $$PartesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoriaId => $composableBuilder(
    column: $table.categoriaId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get nombre =>
      $composableBuilder(column: $table.nombre, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);
}

class $$PartesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PartesCacheTable,
          PartesCacheData,
          $$PartesCacheTableFilterComposer,
          $$PartesCacheTableOrderingComposer,
          $$PartesCacheTableAnnotationComposer,
          $$PartesCacheTableCreateCompanionBuilder,
          $$PartesCacheTableUpdateCompanionBuilder,
          (
            PartesCacheData,
            BaseReferences<_$AppDatabase, $PartesCacheTable, PartesCacheData>,
          ),
          PartesCacheData,
          PrefetchHooks Function()
        > {
  $$PartesCacheTableTableManager(_$AppDatabase db, $PartesCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PartesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PartesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PartesCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> categoriaId = const Value.absent(),
                Value<String> nombre = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PartesCacheCompanion(
                id: id,
                categoriaId: categoriaId,
                nombre: nombre,
                dataJson: dataJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String categoriaId,
                required String nombre,
                required String dataJson,
                Value<int> rowid = const Value.absent(),
              }) => PartesCacheCompanion.insert(
                id: id,
                categoriaId: categoriaId,
                nombre: nombre,
                dataJson: dataJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PartesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PartesCacheTable,
      PartesCacheData,
      $$PartesCacheTableFilterComposer,
      $$PartesCacheTableOrderingComposer,
      $$PartesCacheTableAnnotationComposer,
      $$PartesCacheTableCreateCompanionBuilder,
      $$PartesCacheTableUpdateCompanionBuilder,
      (
        PartesCacheData,
        BaseReferences<_$AppDatabase, $PartesCacheTable, PartesCacheData>,
      ),
      PartesCacheData,
      PrefetchHooks Function()
    >;
typedef $$PerfilAlmacenCacheTableCreateCompanionBuilder =
    PerfilAlmacenCacheCompanion Function({
      required String id,
      required String nombreComercial,
      required String verificationStatus,
      required String dataJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$PerfilAlmacenCacheTableUpdateCompanionBuilder =
    PerfilAlmacenCacheCompanion Function({
      Value<String> id,
      Value<String> nombreComercial,
      Value<String> verificationStatus,
      Value<String> dataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PerfilAlmacenCacheTableFilterComposer
    extends Composer<_$AppDatabase, $PerfilAlmacenCacheTable> {
  $$PerfilAlmacenCacheTableFilterComposer({
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

  ColumnFilters<String> get nombreComercial => $composableBuilder(
    column: $table.nombreComercial,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PerfilAlmacenCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $PerfilAlmacenCacheTable> {
  $$PerfilAlmacenCacheTableOrderingComposer({
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

  ColumnOrderings<String> get nombreComercial => $composableBuilder(
    column: $table.nombreComercial,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PerfilAlmacenCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $PerfilAlmacenCacheTable> {
  $$PerfilAlmacenCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nombreComercial => $composableBuilder(
    column: $table.nombreComercial,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verificationStatus => $composableBuilder(
    column: $table.verificationStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PerfilAlmacenCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PerfilAlmacenCacheTable,
          PerfilAlmacenCacheData,
          $$PerfilAlmacenCacheTableFilterComposer,
          $$PerfilAlmacenCacheTableOrderingComposer,
          $$PerfilAlmacenCacheTableAnnotationComposer,
          $$PerfilAlmacenCacheTableCreateCompanionBuilder,
          $$PerfilAlmacenCacheTableUpdateCompanionBuilder,
          (
            PerfilAlmacenCacheData,
            BaseReferences<
              _$AppDatabase,
              $PerfilAlmacenCacheTable,
              PerfilAlmacenCacheData
            >,
          ),
          PerfilAlmacenCacheData,
          PrefetchHooks Function()
        > {
  $$PerfilAlmacenCacheTableTableManager(
    _$AppDatabase db,
    $PerfilAlmacenCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PerfilAlmacenCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PerfilAlmacenCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PerfilAlmacenCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nombreComercial = const Value.absent(),
                Value<String> verificationStatus = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PerfilAlmacenCacheCompanion(
                id: id,
                nombreComercial: nombreComercial,
                verificationStatus: verificationStatus,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nombreComercial,
                required String verificationStatus,
                required String dataJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PerfilAlmacenCacheCompanion.insert(
                id: id,
                nombreComercial: nombreComercial,
                verificationStatus: verificationStatus,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PerfilAlmacenCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PerfilAlmacenCacheTable,
      PerfilAlmacenCacheData,
      $$PerfilAlmacenCacheTableFilterComposer,
      $$PerfilAlmacenCacheTableOrderingComposer,
      $$PerfilAlmacenCacheTableAnnotationComposer,
      $$PerfilAlmacenCacheTableCreateCompanionBuilder,
      $$PerfilAlmacenCacheTableUpdateCompanionBuilder,
      (
        PerfilAlmacenCacheData,
        BaseReferences<
          _$AppDatabase,
          $PerfilAlmacenCacheTable,
          PerfilAlmacenCacheData
        >,
      ),
      PerfilAlmacenCacheData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SolicitudesTableTableManager get solicitudes =>
      $$SolicitudesTableTableManager(_db, _db.solicitudes);
  $$OutboxTableTableManager get outbox =>
      $$OutboxTableTableManager(_db, _db.outbox);
  $$VehiculosCacheTableTableManager get vehiculosCache =>
      $$VehiculosCacheTableTableManager(_db, _db.vehiculosCache);
  $$DireccionesCacheTableTableManager get direccionesCache =>
      $$DireccionesCacheTableTableManager(_db, _db.direccionesCache);
  $$CategoriasCacheTableTableManager get categoriasCache =>
      $$CategoriasCacheTableTableManager(_db, _db.categoriasCache);
  $$PartesCacheTableTableManager get partesCache =>
      $$PartesCacheTableTableManager(_db, _db.partesCache);
  $$PerfilAlmacenCacheTableTableManager get perfilAlmacenCache =>
      $$PerfilAlmacenCacheTableTableManager(_db, _db.perfilAlmacenCache);
}
