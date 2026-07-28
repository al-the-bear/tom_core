import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../datasources/types_operator.dart';
import 'crud_repository.dart';

/// Wraps a Dart [Type] so it can be carried as a value (e.g. in an annotation
/// argument list, where a bare `Type` literal is awkward to pass around).
class TomDartType {
  /// The wrapped Dart type.
  final Type type;

  /// Wraps [type].
  TomDartType(this.type);
}

/// Annotation that maps an entity class to a database table.
///
/// Applied to a `@tomReflector` entity, it tells the persistence layer which
/// [datasource] the table lives in, the [table] name, the [schema] (optional),
/// the entity field that holds the primary key ([primaryKeyField]), and — if it
/// differs — the primary-key [idColumn] name.
class TomDbTable {
  /// The name of the registered data source that holds this table.
  final String datasource;

  /// The table name.
  final String table;

  /// The schema the table belongs to, if any.
  final String? schema;

  /// The entity field that holds the primary key.
  final String primaryKeyField;

  /// The primary-key column name, when it differs from [primaryKeyField].
  final String? idColumn;

  /// Binds an entity to a table.
  const TomDbTable({
    required this.datasource,
    required this.table,
    required this.primaryKeyField,
    this.idColumn,
    this.schema,
  });
}

/// Annotation that maps an entity field to a database column.
///
/// The type parameters carry the Dart-side type ([DART_TYPE]) and the SQL-side
/// boxed type ([COL_TYPE], a [TomDbType]); [fromDbConverter] / [toDbConverter]
/// translate between them when reading and writing. [isReadOnly] columns are
/// skipped on insert/update, [noLoad] columns are not selected, and [isJson]
/// marks a column whose value is JSON-encoded.
///
/// [authKey] opts the column into **column-level access rights** (C-4): when
/// set, the repository resolves the current principal's [TomAuthState] for that
/// resource key (through `TomColumnAuthorization`, consulting `TomAuthorization`)
/// and enforces it server-authoritatively — masking the column's value on read
/// when the principal cannot see it, and rejecting a write that changes it when
/// the principal is not `full`. A column with no [authKey] is unrestricted, so
/// existing entities keep their behaviour unchanged.
class TomDbColumn<DART_TYPE, COL_TYPE extends TomDbType> {
  /// The column name; defaults to the field name when `null`.
  final String? columnName;

  /// Whether the column is excluded from inserts and updates.
  final bool isReadOnly;

  /// Whether the column is excluded from selects.
  final bool noLoad;

  /// Whether the column holds JSON-encoded data.
  final bool isJson;

  /// The resource key that gates this column's read/write access (C-4).
  ///
  /// When non-null, the repository resolves the current principal's
  /// [TomAuthState] for this key and masks the value on read / rejects an
  /// unauthorized write. `null` (the default) leaves the column unrestricted.
  final String? authKey;

  /// The Dart type, when it cannot be inferred from [DART_TYPE].
  final Type? dartType;

  /// The SQL column type, when it cannot be inferred from [COL_TYPE].
  final Type? columnType;

  /// Converts a stored [COL_TYPE] value back to the Dart [DART_TYPE].
  final DART_TYPE Function(COL_TYPE)? fromDbConverter;

  /// Converts a Dart [DART_TYPE] value to the stored [COL_TYPE].
  final COL_TYPE Function(DART_TYPE)? toDbConverter;

  /// Maps a field to a column.
  const TomDbColumn({
    required this.columnName,
    this.isReadOnly = false,
    this.noLoad = false,
    this.isJson = false,
    this.authKey,
    this.dartType,
    this.fromDbConverter,
    this.toDbConverter,
    this.columnType,
  });

  /// The declared Dart type: [DART_TYPE] when concrete, else [dartType].
  Type? declaredDartType() => DART_TYPE != dynamic ? DART_TYPE : dartType;

  /// The declared SQL column type: [COL_TYPE] when concrete, else [columnType].
  Type? declaredColumnType() =>
      (COL_TYPE != TomDbType<dynamic>) ? COL_TYPE : columnType;
}

/// Annotation marking the entity field that holds the primary key.
class TomEntityId {
  /// Marks a field as the entity id.
  const TomEntityId();
}

/// Annotation declaring the **row-level data scope** of an entity (C-3).
///
/// Applied to a `@tomReflector` entity, it restricts which rows the repository
/// returns to those the current principal is allowed to see. [field] names the
/// entity field/column that carries the scope value (e.g. `ownerId`), and
/// [scope] names the scope *kind* — a key into `TomDataScopeRegistry` whose
/// resolver maps the current `TomPrincipal` to the set of [field] values the
/// principal may see (the default `'owner'` resolves to the principal's own id).
///
/// At query time the repository resolves the principal's allowed values and
/// binds them into an additional prepared `WHERE <field> IN (?, …)` clause; no
/// value is ever concatenated into the SQL text (C-7). An entity *without* this
/// annotation is unscoped — every row is visible.
class TomDbScope {
  /// The entity field whose value is matched against the principal's allowed
  /// scope values.
  final String field;

  /// The scope kind — a key into `TomDataScopeRegistry` selecting the resolver
  /// that turns the principal into its set of allowed [field] values.
  final String scope;

  /// Declares that the annotated entity's rows are scoped by [field] under the
  /// named [scope] resolver (default `'owner'`).
  const TomDbScope({required this.field, this.scope = 'owner'});
}

/// Annotation marking a `String` column that holds a **blob storage key**
/// rather than the file's bytes (the server half of the CodeSpecs CE-DB
/// file-reference column).
///
/// The column is an ordinary `@TomDbColumn` as far as SQL is concerned — a
/// short `VARCHAR` — and every other persistence feature keeps working on it
/// unchanged: it is scoped by `@TomDbScope` with the rest of the row, it can
/// carry an `authKey` and be masked or write-protected like any column, and it
/// appears in the audit trail as the key it holds. What the annotation adds is
/// the *bytes*: `TomSqlDatasourceRepository.saveFile` uploads a stream and
/// writes the resulting key here, `openFile` streams it back, and the
/// repository deletes the superseded or orphaned blob when the row is updated
/// or deleted.
///
/// Storing the key rather than the bytes is what makes the streaming API
/// possible at all: the row stays small enough to read, diff, audit and mask
/// like every other row, and the payload — which may be gigabytes — never
/// passes through a `SELECT`.
///
/// [store] names the entry in `TomBlobStoreInfo`; `null` uses the default
/// store, so a deployment with one place to put files configures nothing per
/// column. [keyPrefix] namespaces the generated keys (typically the entity or
/// a tenant), [mediaType] is the type assumed when an upload names none, and
/// [cascadeDelete] governs whether deleting the row deletes the blob — set it
/// `false` for a key the application shares between rows or manages itself.
class TomFileReference {
  /// The named blob store to use, or `null` for the default store.
  final String? store;

  /// The prefix generated keys are placed under, e.g. `invoices`.
  final String keyPrefix;

  /// Whether deleting (or clearing) the owning row deletes the blob.
  final bool cascadeDelete;

  /// The media type assumed when an upload does not name one.
  ///
  /// Mirrors `TomStoredBlob.defaultMediaType`; spelled literally so the
  /// annotation library does not depend on the storage module.
  final String mediaType;

  /// Declares that the annotated column holds a blob storage key.
  const TomFileReference({
    this.store,
    this.keyPrefix = '',
    this.cascadeDelete = true,
    this.mediaType = 'application/octet-stream',
  });
}

/// Annotation describing a many-to-many join table between two entities.
///
/// Note: declared for future use — the persistence layer does not yet detect or
/// apply this annotation (see the quest completion steps).
class TomJoinTable {
  /// The entity on the far side of the join.
  final Type targetEntity;

  /// The repository type that loads [targetEntity].
  final Type repositoryType;

  /// The entity on the near side of the join.
  final Type originEntity;

  /// The key type linking the two sides.
  final Type keyType;

  /// The join-table columns on the origin side.
  final List<String> leftSideColumns;

  /// The join-table columns on the target side.
  final List<String> rightSideColumns;

  /// Extra join-table columns carried as context.
  final List<String> contextColumns;

  /// Describes a join table.
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

/// Annotation describing a reference (association) from one entity to another,
/// resolved through a join entity.
///
/// The type parameters bind the [TARGET] entity, its key [K], and the [REPO]
/// that loads it. [isOneToOne] marks a single-valued association; otherwise the
/// reference is to-many.
class TomReference<
  TARGET extends Object,
  K,
  REPO extends TomRepository<TARGET, K>
> {
  /// The referenced entity type.
  final Type targetEntity;

  /// The repository type that loads [targetEntity].
  final Type repositoryType;

  /// The entity that models the join.
  final Type joinEntity;

  /// The key type linking the two sides.
  final Type keyType;

  /// The join columns on this (owning) side.
  final List<String> leftSideColumns;

  /// The join columns on the referenced side.
  final List<String> rightSideColumns;

  /// Extra join columns carried as context.
  final List<String> contextColumns;

  /// Whether this is a one-to-one (single-valued) association.
  final bool isOneToOne;

  /// Describes a reference to [targetEntity] via [joinEntity].
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

  /// The referenced entity type ([targetEntity]).
  Type getReferencedType() => targetEntity;

  /// The repository type that loads the referenced entity ([repositoryType]).
  Type getRepositoryType() => repositoryType;

  /// The key type linking the two sides ([keyType]).
  Type getKeyType() => keyType;

  @override
  String toString() =>
      "TomReference Target: ${getReferencedType()}, Key: ${getKeyType()}, Repo: ${getRepositoryType()}, 1:1: $isOneToOne joinEntity: $joinEntity leftSide: $leftSideColumns, rightSide: $rightSideColumns, context: $contextColumns";
}

/// Annotation registering lifecycle callbacks for an entity ([DBTYPE]).
///
/// Note: declared for future use — the persistence layer does not yet detect or
/// invoke these callbacks (see the quest completion steps).
class TomPersistenceEventHandler<DBTYPE> {
  /// Called after the entity is persisted.
  final void Function(DBTYPE)? postPersist;

  /// Called after the entity is loaded.
  final void Function(DBTYPE)? postLoad;

  /// Called before the entity is persisted.
  final void Function(DBTYPE)? prePersist;

  /// Called before the entity is loaded.
  final void Function(DBTYPE)? preLoad;

  /// Registers the lifecycle callbacks.
  TomPersistenceEventHandler({
    this.postPersist,
    this.postLoad,
    this.preLoad,
    this.prePersist,
  });
}

/// The resolved persistence metadata for a single entity field.
///
/// Produced by [TomAnnotationAnalyzer] from the field's annotations, it bundles
/// the owning [table], the field's [column] / [entityId] / [reference] /
/// [eventHandler] annotations, the [declaredType] and [declaredName], and the
/// mapped column [field]. It also provides reflection-backed accessors to read
/// and write the field on a concrete entity instance.
class TomColumnInformation {
  /// The entity type that owns this field.
  Type tableType;

  /// The table the owning entity maps to.
  TomDbTable table;

  /// The field's column mapping, if annotated.
  TomDbColumn? column;

  /// The entity-id annotation, if this field is the primary key.
  TomEntityId? entityId;

  /// The reference annotation, if this field is an association.
  TomReference? reference;

  /// The lifecycle-callback annotation, if any.
  TomPersistenceEventHandler? eventHandler;

  /// The file-reference annotation, if this column holds a blob storage key.
  TomFileReference? fileReference;

  /// The declared Dart type of the field.
  Type declaredType;

  /// The field's name on the entity.
  String declaredName;

  /// The mapped column name.
  String field;

  /// Bundles the resolved metadata for one entity field.
  ///
  /// [fileReference] is named and optional because it arrived after the
  /// positional list was in use across the module; every existing construction
  /// keeps working and only a file-reference column passes it.
  TomColumnInformation(
    this.table,
    this.tableType,
    this.column,
    this.entityId,
    this.reference,
    this.eventHandler,
    this.declaredType,
    this.declaredName,
    this.field, {
    this.fileReference,
  });

  /// The owning entity type ([tableType]).
  Type getDatabaseType() {
    return tableType;
  }

  /// The column name to use in a query: the annotated [TomDbColumn.columnName]
  /// when present, else the [declaredName].
  String getQueryFieldName() {
    return column?.columnName ?? declaredName;
  }

  /// Reads this field's value from [instance] via reflection.
  Object? getVariableValue(Object instance) {
    InstanceMirror tMirror = tomReflector.reflect(instance);
    return tMirror.invokeGetter(declaredName);
  }

  /// Writes [value] to this field on [instance] via reflection.
  Object? setVariableValue(Object instance, Object? value) {
    InstanceMirror tMirror = tomReflector.reflect(instance);
    return tMirror.invokeSetter(declaredName, value);
  }
}
