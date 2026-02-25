import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/types_operator.dart';
import 'crud_repository.dart';

class TomDartType {
  final Type type;
  TomDartType(this.type);
}

class TomDbTable {
  final String datasource;
  final String table;
  final String? schema;
  final String primaryKeyField;
  final String? idColumn;

  const TomDbTable({
    required this.datasource,
    required this.table,
    required this.primaryKeyField,
    this.idColumn,
    this.schema,
  });
}

class TomDbColumn<DART_TYPE, COL_TYPE extends TomDbType> {
  final String? columnName;
  final bool isReadOnly;
  final bool noLoad;
  final bool isJson;
  final Type? dartType;
  final Type? columnType;
  final DART_TYPE Function(COL_TYPE)? fromDbConverter;
  final COL_TYPE Function(DART_TYPE)? toDbConverter;

  const TomDbColumn({
    required this.columnName,
    this.isReadOnly = false,
    this.noLoad = false,
    this.isJson = false,
    this.dartType,
    this.fromDbConverter,
    this.toDbConverter,
    this.columnType,
  });

  Type? declaredDartType() => DART_TYPE != dynamic ? DART_TYPE : dartType;
  Type? declaredColumnType() =>
      (COL_TYPE != TomDbType<dynamic>) ? COL_TYPE : columnType;
}

class TomEntityId {
  const TomEntityId();
}

// TODO: include detection and usage of this...
class TomJoinTable {
  final Type targetEntity;
  final Type repositoryType;
  final Type originEntity;
  final Type keyType;
  final List<String> leftSideColumns;
  final List<String> rightSideColumns;
  final List<String> contextColumns;

  const TomJoinTable({
    required this.targetEntity,
    required this.repositoryType,
    required this.keyType,
    required this.originEntity,
    required this.leftSideColumns,
    required this.rightSideColumns,
    this.contextColumns = const [],
  });
}

class TomReference<
  TARGET extends Object,
  K,
  REPO extends TomRepository<TARGET, K>
> {
  final Type targetEntity;
  final Type repositoryType;
  final Type joinEntity;
  final Type keyType;
  final List<String> leftSideColumns;
  final List<String> rightSideColumns;
  final List<String> contextColumns;
  final bool isOneToOne;
  const TomReference({
    required this.targetEntity,
    required this.repositoryType,
    required this.keyType,
    required this.joinEntity,
    required this.leftSideColumns,
    required this.rightSideColumns,
    this.contextColumns = const [],
    this.isOneToOne = false,
  });

  Type getReferencedType() => targetEntity;
  Type getRepositoryType() => repositoryType;
  Type getKeyType() => keyType;

  @override
  String toString() =>
      "TomReference Target: ${getReferencedType()}, Key: ${getKeyType()}, Repo: ${getRepositoryType()}, 1:1: $isOneToOne joinEntity: $joinEntity leftSide: $leftSideColumns, rightSide: $rightSideColumns, context: $contextColumns";
}

// TODO: include detection and usage of this...
class TomPersistenceEventHandler<DBTYPE> {
  final void Function(DBTYPE)? postPersist;
  final void Function(DBTYPE)? postLoad;
  final void Function(DBTYPE)? prePersist;
  final void Function(DBTYPE)? preLoad;
  TomPersistenceEventHandler({
    this.postPersist,
    this.postLoad,
    this.preLoad,
    this.prePersist,
  });
}

class TomColumnInformation {
  Type tableType;
  TomDbTable table;
  TomDbColumn? column;
  TomEntityId? entityId;
  TomReference? reference;
  TomPersistenceEventHandler? eventHandler;
  Type declaredType;
  String declaredName;
  String field;

  TomColumnInformation(
    this.table,
    this.tableType,
    this.column,
    this.entityId,
    this.reference,
    this.eventHandler,
    this.declaredType,
    this.declaredName,
    this.field,
  );

  Type getDatabaseType() {
    return tableType;
  }

  String getQueryFieldName() {
    return column?.columnName ?? declaredName;
  }

  Object? getVariableValue(Object instance) {
    InstanceMirror tMirror = tomReflector.reflect(instance);
    return tMirror.invokeGetter(declaredName);
  }

  Object? setVariableValue(Object instance, Object? value) {
    InstanceMirror tMirror = tomReflector.reflect(instance);
    return tMirror.invokeSetter(declaredName, value);
  }
}
