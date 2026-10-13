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
/// and the entity fields that hold the primary key ([primaryKeyFields]).
///
/// One field is the common case — a surrogate key the database assigns:
///
/// ```dart
/// @TomDbTable(datasource: 'app', table: 'task', primaryKeyFields: ['id'])
/// ```
///
/// Several fields key a table by the combination of their columns, the shape
/// of a join table keyed only by its two foreign keys:
///
/// ```dart
/// @TomDbTable(
///   datasource: 'auth',
///   table: 'user_role',
///   primaryKeyFields: ['userId', 'roleId'],
/// )
/// ```
///
/// Such an entity's repository addresses a row by a `TomCompositeKey` of those
/// fields, and `save` inserts or updates by whether a row with that key exists,
/// since a key the caller supplies says nothing about whether it is stored yet.
class TomDbTable {
  /// The name of the registered data source that holds this table.
  final String datasource;

  /// The table name.
  final String table;

  /// The schema the table belongs to, if any.
  final String? schema;

  /// The entity fields that hold the primary key, in key order; never empty.
  final List<String> primaryKeyFields;

  /// Binds an entity to a table.
  const TomDbTable({
    required this.datasource,
    required this.table,
    required this.primaryKeyFields,
    this.schema,
  });
}

/// Annotation that maps an entity field to a database column.
///
/// The column's storage type is the field's Dart type unless [columnType] says
/// otherwise: `columnType: TomDbString` on a `TomAuthState` field stores the
/// enum as text. [dartType] overrides the field's Dart type for the same
/// purpose. Both are plain fields because an annotation is read back through
/// reflection, which reconstructs it without type arguments — a type parameter
/// on this class would be documented API that nothing at run time could see.
/// One resolver, `TomAnnotationAnalyzer.familyOf`, turns them into a storage
/// family for every consumer.
///
/// [fromDbConverter] / [toDbConverter] translate between the stored boxed value
/// and the Dart value when reading and writing. [isReadOnly] columns are
/// skipped on insert/update, [noLoad] columns are not selected, and [isJson]
/// marks a column whose value is JSON-encoded (stored as text).
///
/// [authKey] opts the column into **column-level access rights** (C-4): when
/// set, the repository resolves the current principal's [TomAuthState] for that
/// resource key (through `TomColumnAuthorization`, consulting `TomAuthorization`)
/// and enforces it server-authoritatively — masking the column's value on read
/// when the principal cannot see it, and rejecting a write that changes it when
/// the principal is not `full`. A column with no [authKey] is unrestricted, so
/// existing entities keep their behaviour unchanged.
class TomDbColumn {
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

  /// The Dart type the column is read as, when it is not the field's own.
  final Type? dartType;

  /// The type the column is stored as, when it is not the field's Dart type:
  /// a [TomDbType] box (`TomDbString`), or the Dart type whose storage it shares
  /// (`bool`).
  final Type? columnType;

  /// Converts a stored boxed value back to the field's Dart value.
  ///
  /// Typed with the widest box because that is the value the datasource holds
  /// when it calls it; a converter for one column narrows inside, by cast.
  final Object? Function(TomDbType value)? fromDbConverter;

  /// Converts the field's Dart value to the boxed value to store.
  final TomDbType Function(dynamic value)? toDbConverter;

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
}

/// Annotation marking the entity field that holds the primary key.
class TomEntityId {
  /// Marks a field as the entity id.
  const TomEntityId();
}

/// Marks an entity as owned by a tenant: every row carries its tenant in
/// [field], and a repository reads and writes only the rows of the tenant in
/// context (`TomTenantContext`).
///
/// It is independent of [TomDbScope] and is ANDed with it: an entity can be a
/// tenant's *and* scoped to its owner or to a resource grant. Concretely:
///
/// - every read — `findAll`, `findById`, `count`, `findWhere`, the existence
///   checks — carries `<field> = <tenant>` as a bound predicate;
/// - every update and delete may touch only rows that predicate admits;
/// - an insert whose [field] is unset is filled with the current tenant, and
///   one naming another tenant is refused;
/// - with no tenant in context, the entity is unreadable and unwritable.
///
/// The predicate applies in every isolation model. Where the tenant's rows live
/// in a schema or a database of their own, it is a second wall rather than the
/// only one — which is also what makes moving a tenant between models a data
/// copy rather than a schema change.
///
/// ```dart
/// @tomReflector
/// @TomTenantOwned()
/// @TomDbTable(datasource: 'main', table: 'invoice', primaryKeyFields: ['id'])
/// class Invoice {
///   @TomDbColumn(columnName: 'tenant_id')
///   String? tenantId;
///   // …
/// }
/// ```
class TomTenantOwned {
  /// Marks the entity tenant-owned, with its tenant in [field].
  const TomTenantOwned({this.field = 'tenantId'});

  /// The entity field holding the row's tenant id.
  final String field;
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
/// value is ever concatenated into the SQL text (C-7).
///
/// **An entity that carries a resource-key column is scoped automatically**
/// under the [resourceScope] kind, without an annotation: the analyzer
/// synthesizes exactly the `TomDbScope(field: 'resource_key', scope:
/// 'resource')` a developer would otherwise have written, so grant-driven
/// scoping is the default rather than something each entity has to remember to
/// opt into. An entity that must stay global despite carrying such a column —
/// a lookup table, a configuration table, the authorization metadata tables
/// themselves — says so with [TomDbScope.unscoped]. An entity with neither an
/// annotation nor a resource-key column is unscoped: every row is visible.
class TomDbScope {
  /// The scope kind resolving a principal's granted resource keys — direct
  /// ownership grants folded with the delegations active right now (C-5 ∪ C-6).
  static const String resourceScope = 'resource';

  /// The sentinel [scope] of [TomDbScope.unscoped] — an entity explicitly
  /// declaring that it carries no row scope at all.
  static const String noScope = '';

  /// The entity field whose value is matched against the principal's allowed
  /// scope values.
  final String field;

  /// The scope kind — a key into `TomDataScopeRegistry` selecting the resolver
  /// that turns the principal into its set of allowed [field] values.
  final String scope;

  /// Declares that the annotated entity's rows are scoped by [field] under the
  /// named [scope] resolver (default `'owner'`).
  const TomDbScope({required this.field, this.scope = 'owner'});

  /// Declares that the annotated entity is **deliberately unscoped** — every
  /// row is visible to every principal.
  ///
  /// Needed only where automatic scoping would otherwise apply, i.e. on an
  /// entity that carries a resource-key column but must stay global. The
  /// authorization metadata tables are the framework's own instance: the rows
  /// that *say* who may see what cannot themselves be filtered by who may see
  /// what, or the resolver would deny itself its own input.
  const TomDbScope.unscoped() : field = '', scope = noScope;

  /// Whether this annotation is the explicit opt-out ([TomDbScope.unscoped])
  /// rather than a scope declaration.
  bool get isOptOut => scope == noScope;
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
///
/// [exposed] opts the column into the framework's HTTP file endpoint
/// (`TomFileService`). It defaults to `false`, and that default is the point:
/// whether a file may be fetched over HTTP is an authorization decision, so it
/// is declared here — next to the column it exposes — rather than in a separate
/// table that can drift away from it. Reflection must never publish a column by
/// accident.
class TomFileReference {
  /// The named blob store to use, or `null` for the default store.
  final String? store;

  /// The prefix generated keys are placed under, e.g. `invoices`.
  ///
  /// Must satisfy `TomBlobStore.isValidKeyPrefix`: it is joined to the rest of
  /// the key, so it obeys the same grammar and carries no trailing slash. A
  /// `const` constructor cannot refuse a value, so the check happens where the
  /// key is minted — `TomFileReferenceKeys.generate`.
  final String keyPrefix;

  /// Whether deleting (or clearing) the owning row deletes the blob.
  final bool cascadeDelete;

  /// The media type assumed when an upload does not name one.
  ///
  /// Mirrors `TomStoredBlob.defaultMediaType`; spelled literally so the
  /// annotation library does not depend on the storage module.
  final String mediaType;

  /// Whether this column is reachable over the framework's HTTP file endpoint.
  ///
  /// Default-closed. Setting it `true` makes the column addressable as the slot
  /// `<table>/<id>/<column>`; it does **not** decide *whether* a caller may have
  /// it, which stays with the row scope (C-3) and column grade (C-4) the
  /// repository already enforces.
  final bool exposed;

  /// Declares that the annotated column holds a blob storage key.
  const TomFileReference({
    this.store,
    this.keyPrefix = '',
    this.cascadeDelete = true,
    this.mediaType = 'application/octet-stream',
    this.exposed = false,
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
  ///
  /// Required, because a join table is always a mapped `@TomDbTable` entity:
  /// there is no form of this annotation over a bare table. Mapping an existing
  /// join table costs one class and changes nothing in the schema, and it gives
  /// the join row what every other row has — an address, a `@TomDbScope` and
  /// column grades — none of which a bare table could carry.
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

/// The resolved persistence metadata for a single entity field.
///
/// Produced by [TomAnnotationAnalyzer] from the field's annotations, it bundles
/// the owning [table], the field's [column] / [entityId] / [reference]
/// annotations, the [declaredType] and [declaredName], and the mapped column
/// [field]. It also provides reflection-backed accessors to read
/// and write the field on a concrete entity instance.
///
/// Every field is `final`, because an instance is not private to the caller who
/// obtained it: the analyzer resolves an entity's columns once and hands the
/// same objects to every repository, query compiler and datasource for the life
/// of the isolate. A single assignment to [field] or [column] would therefore
/// change what every subsequent query on that entity compiles to, at no point
/// raising an error — the mistake would surface as wrong SQL somewhere else
/// entirely. Nothing needs the mutability: the analyzer knows all ten values
/// before it constructs the instance, and re-resolving an entity means clearing
/// the analyzer's memo, not editing the metadata in place.
class TomColumnInformation {
  /// The entity type that owns this field.
  final Type tableType;

  /// The table the owning entity maps to.
  final TomDbTable table;

  /// The field's column mapping, if annotated.
  final TomDbColumn? column;

  /// The entity-id annotation, if this field is the primary key.
  final TomEntityId? entityId;

  /// The reference annotation, if this field is an association.
  final TomReference? reference;

  /// The file-reference annotation, if this column holds a blob storage key.
  final TomFileReference? fileReference;

  /// The kernel's field-protection annotation, if the field carries one.
  final TomProtectedField? protectedField;

  /// The resource key that gates this column (C-4): the column's own
  /// [TomDbColumn.authKey], else the field's [TomProtectedField] key, else
  /// `null` for an unrestricted column.
  ///
  /// Reading the kernel annotation here is what makes one `@TomProtectedField`
  /// protect a field in both automatic tiers it passes through — the JSON
  /// serializer and this repository — without the key being written twice.
  String? get authKey => column?.authKey ?? protectedField?.resourceKey;

  /// The declared Dart type of the field.
  final Type declaredType;

  /// The field's name on the entity.
  final String declaredName;

  /// The mapped column name.
  final String field;

  /// Bundles the resolved metadata for one entity field.
  ///
  /// The five required parameters are the ones every mapped field has: the
  /// owning entity type ([tableType]) and its table ([table]), and the field's
  /// own [declaredType], [declaredName] and mapped [field] name. The five
  /// optional ones each correspond to an annotation the field may or may not
  /// carry — [column], [entityId], [reference], [fileReference],
  /// [protectedField] — and are `null` when it does not.
  ///
  /// All are named. Two pairs are the reason: [declaredName] and [field] are
  /// both `String`, and passing them the wrong way round type-checks — it maps
  /// the entity's field name to itself as a column and the column name to
  /// itself as a field, so the error surfaces as wrong SQL somewhere else. So
  /// does confusing [declaredType] with [tableType], both `Type`, which
  /// misreports every column of the entity as being of the entity's own type.
  /// A named argument cannot be given to the wrong parameter by miscounting.
  TomColumnInformation({
    required this.tableType,
    required this.table,
    required this.declaredType,
    required this.declaredName,
    required this.field,
    this.column,
    this.entityId,
    this.reference,
    this.fileReference,
    this.protectedField,
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
