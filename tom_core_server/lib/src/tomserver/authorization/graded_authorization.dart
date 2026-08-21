/// Server-side persistence of the four authorization states.
///
/// The kernel models per-resource-key authorization as a flat list of granted
/// keys ([TomAccessControlInformation.resourceKeys]) — a key is either present
/// (granted) or absent (denied), with no room for the middle states the UI
/// distinguishes ([TomAuthState.read] / [TomAuthState.disabled]). This library
/// closes that gap on the server side: it adds a persistable grant record
/// ([TomResourceGrant]) that stores a per-key [TomAuthState], a codec
/// ([TomAuthStateCodec]) that round-trips the state to/from its stored column
/// value, and a graded view ([TomGradedAccessControlInformation]) that resolves
/// the effective state for a key — using an explicit grade when one exists and
/// falling back to the legacy binary list otherwise.
///
/// The fallback keeps the extension backward compatible: a system that has only
/// the binary list still resolves every key to [TomAuthState.full] (granted) or
/// [TomAuthState.none] (denied), exactly as before.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../object_persistence/persistence_annotations.dart';

/// Round-trips a [TomAuthState] to and from the string value stored in a
/// database column (and bridges the legacy binary granted/denied model).
///
/// The stored representation is the enum's [TomAuthState.name]
/// (`'none'` / `'disabled'` / `'read'` / `'full'`), which is stable across
/// releases and human-readable in the table. [fromStored] is deliberately
/// lenient: an unknown or `null` value resolves to [TomAuthState.none] (the
/// closed/safe default) unless a different fallback is supplied.
class TomAuthStateCodec {
  const TomAuthStateCodec._();

  /// The canonical stored token for [state] (its [TomAuthState.name]).
  static String toStored(TomAuthState state) => state.name;

  /// Parses [stored] back to a [TomAuthState]. A `null` or unrecognised value
  /// yields [orElse] (default [TomAuthState.none]) rather than throwing, so a
  /// stray column value degrades safely to "hidden".
  static TomAuthState fromStored(
    String? stored, {
    TomAuthState orElse = TomAuthState.none,
  }) {
    if (stored == null) return orElse;
    for (final state in TomAuthState.values) {
      if (state.name == stored) return state;
    }
    return orElse;
  }

  /// Bridges the legacy binary model: a granted key maps to
  /// [TomAuthState.full], a denied key to [TomAuthState.none]. This matches the
  /// kernel's [TomAccessControl.resolveAuthState] default so the graded and
  /// binary worlds agree on the two states they share.
  static TomAuthState fromLegacyGranted(bool granted) =>
      granted ? TomAuthState.full : TomAuthState.none;

  /// [TomDbColumn] read converter: a stored [TomDbString] column → [TomAuthState].
  ///
  /// The parameter is the widest boxed type ([TomDbType]) rather than the
  /// narrower [TomDbString] on purpose: the persistence layer reads
  /// `fromDbConverter` from a **generics-erased** [TomDbColumn], so the stored
  /// function must accept a `TomDbType<dynamic>`. A narrowed parameter passes
  /// the assignment into the typed annotation field but fails the runtime
  /// function-subtype check on that erased read (parameter types are
  /// contravariant). The `access_level` column is always a [TomDbString], so
  /// the cast is total.
  static TomAuthState fromDbColumn(TomDbType column) =>
      fromStored((column as TomDbString).get());

  /// [TomDbColumn] write converter: a [TomAuthState] → the stored [TomDbString].
  ///
  /// The parameter is `dynamic` for the same erased-read reason as
  /// [fromDbColumn]: the layer reads `toDbConverter` from a generics-erased
  /// column, which requires the widest parameter type. The value passed is
  /// always a [TomAuthState], so the cast is total.
  static TomDbString toDbColumn(dynamic state) =>
      TomDbString(toStored(state as TomAuthState));
}

/// A persistable grant of a single [TomAuthState] to a `(roleName, resourceKey)`
/// pair — the storage row behind the four-state authorization model.
///
/// Mapped to the `tom_resource_grant` table via the object-persistence
/// annotations; the [accessLevel] column round-trips through
/// [TomAuthStateCodec]. Load every grant for a principal's roles, fold them with
/// [TomGradedAccessControlInformation.fromGrants], and resolve the effective
/// state per key.
///
/// The canonical DDL is published as [createTableSql] and shipped as the
/// reference migration `example/authorization/migrations/main/tomcore/
/// [1]-create_tom_resource_grants.sql`, applied through the `db_migration`
/// module.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_resource_grant',
  primaryKeyField: 'id',
)
// Authorization metadata: the grade rows feed the row scope and so must not be
// filtered by it (see [TomPrincipalResourceGrant]).
@TomDbScope.unscoped()
class TomResourceGrant {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The role the grant applies to.
  @TomDbColumn<String, TomDbString>(columnName: 'role_name')
  String roleName;

  /// The resource key being graded.
  @TomDbColumn<String, TomDbString>(columnName: 'resource_key')
  String resourceKey;

  /// The graded access level for `(roleName, resourceKey)`.
  @TomDbColumn<TomAuthState, TomDbString>(
    columnName: 'access_level',
    fromDbConverter: TomAuthStateCodec.fromDbColumn,
    toDbConverter: TomAuthStateCodec.toDbColumn,
  )
  TomAuthState accessLevel;

  /// Creates a grant. [accessLevel] defaults to [TomAuthState.none] (denied).
  ///
  /// [roleName] and [resourceKey] default to the empty string so the entity is
  /// **no-arg constructible**: `TomSqlDatasourceRepository` loads a row by
  /// instantiating a blank grant via reflection (`newInstance('', [])`) and
  /// then populating each `@TomDbColumn` field from the result set. A `required`
  /// constructor parameter would make that blank instantiation throw, so this
  /// own-table entity could not be read back through its own repository.
  /// Callers that build a fully-specified grant still pass the named arguments.
  TomResourceGrant({
    this.id = -1,
    this.roleName = '',
    this.resourceKey = '',
    this.accessLevel = TomAuthState.none,
  });

  /// The canonical DDL for the `tom_resource_grant` table.
  ///
  /// The `access_level` column is constrained to the four [TomAuthState]
  /// tokens, so the database itself rejects an out-of-range grade. Shipped
  /// verbatim as the reference `db_migration` script, so the two cannot drift —
  /// `test/reference_migrations_test.dart` fails if they do.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_resource_grant (
  id BIGINT NOT NULL AUTO_INCREMENT,
  role_name VARCHAR(255) NOT NULL,
  resource_key VARCHAR(255) NOT NULL,
  access_level ENUM('none', 'disabled', 'read', 'full') NOT NULL DEFAULT 'none',
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_resource_grant_role_key (role_name, resource_key)
);''';

  @override
  String toString() =>
      'TomResourceGrant($roleName, $resourceKey -> ${accessLevel.name})';
}

/// A graded view over resource-key authorization that resolves the effective
/// [TomAuthState] for a key.
///
/// Built from persisted [TomResourceGrant]s (the graded source of truth) and,
/// optionally, the kernel's binary [TomAccessControlInformation] (the legacy
/// fallback). [resolveState] returns the explicit grade when one exists and
/// otherwise bridges the binary list: a key present in
/// [TomAccessControlInformation.resourceKeys] resolves to [TomAuthState.full],
/// an absent key to [TomAuthState.none].
class TomGradedAccessControlInformation {
  final Map<String, TomAuthState> _grades;
  final TomAccessControlInformation _binary;

  /// Wraps explicit per-key [grades] over an optional [binary] fallback ACI.
  TomGradedAccessControlInformation({
    Map<String, TomAuthState>? grades,
    TomAccessControlInformation? binary,
  }) : _grades = {...?grades},
       _binary = binary ?? TomAccessControlInformation();

  /// Builds a graded view from grants loaded from the database.
  ///
  /// When several rows grade the same key (e.g. a principal holds two roles),
  /// the **most permissive** grade wins ([TomAuthState.widen]) — holding any
  /// role that grants write should not be undone by another that grants less.
  /// [binary] supplies the fallback for keys with no explicit grant.
  factory TomGradedAccessControlInformation.fromGrants(
    Iterable<TomResourceGrant> grants, {
    TomAccessControlInformation? binary,
  }) {
    final grades = <String, TomAuthState>{};
    for (final grant in grants) {
      final existing = grades[grant.resourceKey];
      grades[grant.resourceKey] = existing == null
          ? grant.accessLevel
          : existing.widen(grant.accessLevel);
    }
    return TomGradedAccessControlInformation(grades: grades, binary: binary);
  }

  /// Unmodifiable view of the explicit per-key grades.
  Map<String, TomAuthState> get grades => Map.unmodifiable(_grades);

  /// The effective [TomAuthState] for [resourceKey]: the explicit grade when
  /// present, otherwise the binary fallback (granted → [TomAuthState.full],
  /// denied → [TomAuthState.none]).
  TomAuthState resolveState(String resourceKey) {
    final graded = _grades[resourceKey];
    if (graded != null) return graded;
    return TomAuthStateCodec.fromLegacyGranted(
      _binary.resourceKeys.contains(resourceKey),
    );
  }

  /// Materialises the explicit grades back into persistable grants for
  /// [roleName] — the inverse of [TomGradedAccessControlInformation.fromGrants].
  List<TomResourceGrant> toGrants(String roleName) => [
    for (final entry in _grades.entries)
      TomResourceGrant(
        roleName: roleName,
        resourceKey: entry.key,
        accessLevel: entry.value,
      ),
  ];
}
