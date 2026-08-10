/// The persisted form of one user preference — a row of `tom_user_preference`.
///
/// Mapped through the ordinary object-persistence annotations, like every other
/// framework table that has an entity ([TomUserTwoFactorEnrolment],
/// [TomPrincipalResourceGrant], [TomPrincipalDelegation]): a second persistence
/// path for one table would have to reimplement binding, row mapping, the audit
/// hook and the row scope, and would drift from all four.
///
/// ## The scope is the authorization
///
/// The entity declares `@TomDbScope(field: 'principal_id', scope: 'owner')`, and
/// that single line is the whole "a principal reads and writes only their own"
/// rule. The CRUD repository ANDs `principal_id IN (:__tomscope_0)` into every
/// read, rejects an update or delete that would touch an out-of-scope row, and
/// rejects an insert scoped to a principal other than the caller — all from the
/// principal in the request zone, none of it restated in a handler. A
/// hand-written `if (principal.id != row.principalId)` in the service would be a
/// second copy of a rule that already exists, and the copy that is forgotten on
/// the fourth endpoint is the one that leaks (C-3).
///
/// [principalId] is an `int` rather than the stringified id
/// [TomUserTwoFactorEnrolment.principalId] carries, because the built-in
/// `'owner'` resolver yields `TomPrincipal.id` — an `int`. A `String` column
/// would compare a stringified id against an integer bind value and match
/// nothing, which is a scope that denies everything: secure, and silently
/// useless.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/types_operator.dart';
import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';

/// One preference of one principal.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_user_preference',
  primaryKeyField: 'id',
)
@TomDbScope(field: 'principal_id', scope: 'owner')
class TomUserPreference {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn<int, TomDbInt>(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal the preference belongs to ([TomPrincipal.id]) — the scope
  /// column.
  @TomDbColumn<int, TomDbInt>(columnName: 'principal_id')
  int principalId;

  /// The preference key (see [TomUserPreferenceKeys] for the framework's own).
  @TomDbColumn<String, TomDbString>(columnName: 'preference_key')
  String preferenceKey;

  /// The name of the type [valueJson] was written as
  /// ([TomUserPreferenceDto.valueType]).
  @TomDbColumn<String, TomDbString>(columnName: 'value_type')
  String valueType;

  /// The value's JSON text.
  @TomDbColumn<String, TomDbString>(columnName: 'value_json')
  String valueJson;

  /// When the preference was last written (UTC).
  @TomDbColumn<DateTime?, TomDbDateTime>(columnName: 'updated_at')
  DateTime? updatedAt;

  /// Creates a row. Every field defaults, because the repository instantiates a
  /// blank entity and fills it column by column when mapping a result.
  TomUserPreference({
    this.id = -1,
    this.principalId = -1,
    this.preferenceKey = '',
    this.valueType = '',
    this.valueJson = '',
    this.updatedAt,
  });

  /// This row as the wire DTO.
  ///
  /// [updatedAt] is normalised to UTC on the way out. MariaDB's `DATETIME`
  /// carries no zone, so the datasource writes a UTC instant as its local
  /// equivalent and reads it back through `DateTime.parse` — the same moment,
  /// but flagged local. That is the right convention *inside* the server, and
  /// the wrong one at its edge: this DTO is serialized to ISO-8601 for a client
  /// that may be in another zone, and a local-flagged instant renders without an
  /// offset, so the client would read the server's wall clock as its own. The
  /// moment is unchanged by the conversion; only the flag the encoder acts on
  /// is.
  TomUserPreferenceDto toDto() => TomUserPreferenceDto(
    key: preferenceKey,
    valueType: valueType,
    value: valueJson,
    updatedAt: updatedAt?.toUtc(),
  );

  /// The DDL this entity expects, reproduced verbatim by the framework
  /// migration so the two cannot drift — `test/reference_migrations_test.dart`
  /// fails if they do.
  ///
  /// `(principal_id, preference_key)` is unique because that pair *is* the
  /// preference's identity: writing a key twice must replace the value, and a
  /// duplicate would make which value a user gets depend on row order.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_user_preference (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id BIGINT NOT NULL,
  preference_key VARCHAR(191) NOT NULL,
  value_type VARCHAR(191) NOT NULL,
  value_json TEXT NULL,
  updated_at DATETIME NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_user_preference (principal_id, preference_key),
  KEY idx_tom_user_preference_principal (principal_id)
);''';
}

/// The repository for [TomUserPreference].
///
/// Shipped rather than left to the deployment (as the authorization tables are)
/// because [TomUserPreferences] is itself shipped and would otherwise be
/// unusable without the caller writing this one empty line.
class TomUserPreferenceRepository
    extends TomSqlDatasourceRepository<TomUserPreference, int> {}
