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
/// [principalId] holds [TomPrincipal.qualifiedId] — the principal's id
/// qualified by its tenant — because that is what the built-in `'owner'`
/// resolver yields. A principal id is unique within its tenant only, so under
/// `shared` isolation, where every tenant's preferences sit in this one table,
/// the qualified key is what keeps two tenants' `u1` apart.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';
import '../privacy/personal_data.dart';

/// One preference of one principal.
@tomReflector
@TomDbTable(
  datasource: 'main',
  table: 'tom_user_preference',
  primaryKeyFields: ['id'],
)
@TomDbScope(field: 'principal_id', scope: 'owner')
class TomUserPreference {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int id;

  /// The principal the preference belongs to ([TomPrincipal.qualifiedId]) —
  /// the scope column.
  @TomDataSubject()
  @TomDbColumn(columnName: 'principal_id')
  String principalId;

  /// The preference key (see [TomUserPreferenceKeys] for the framework's own).
  @TomDbColumn(columnName: 'preference_key')
  String preferenceKey;

  /// The name of the type [valueJson] was written as
  /// ([TomUserPreferenceDto.valueType]).
  @TomDbColumn(columnName: 'value_type')
  String valueType;

  /// The value's JSON text.
  @TomPersonal()
  @TomDbColumn(columnName: 'value_json')
  String valueJson;

  /// When the preference was last written (UTC).
  @TomDbColumn(columnName: 'updated_at')
  DateTime? updatedAt;

  /// Creates a row. Every field defaults, because the repository instantiates a
  /// blank entity and fills it column by column when mapping a result.
  TomUserPreference({
    this.id = -1,
    this.principalId = '',
    this.preferenceKey = '',
    this.valueType = '',
    this.valueJson = '',
    this.updatedAt,
  });

  /// This row as the wire DTO.
  ///
  /// [updatedAt] is normalised to UTC on the way out. A value read from the
  /// column already arrives UTC-flagged — the datasource applies the instant
  /// convention (`datasources/sql_instant.dart`) to every `TomDbDateTime`
  /// column — so for that path the conversion is a no-op. It is kept because
  /// this DTO is also built from rows this entity did not load and from values
  /// set in memory, and at the server's edge the flag is load-bearing: the DTO
  /// is serialized to ISO-8601 for a client that may be in another zone, and a
  /// local-flagged instant renders without an offset, so the client would read
  /// the server's wall clock as its own. The moment is unchanged either way;
  /// only the flag the encoder acts on is.
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
  ///
  /// `preference_key` and `value_type` are `COLLATE utf8mb4_bin`, so that
  /// identity and the key order are case-sensitive whatever the server's
  /// default collation is: under a case-insensitive default, `device.Theme`
  /// and `device.theme` would be one row, and `ORDER BY preference_key` would
  /// not be the code-unit order the contract promises. Schema convergence
  /// does not compare collations, so the DDL is the only place this is stated.
  ///
  /// `updated_at` is `DATETIME(6)`, the width the instant convention writes
  /// (`../datasources/sql_instant.dart`); a plain `DATETIME` rounds off the
  /// microseconds it always renders.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_user_preference (
  id BIGINT NOT NULL AUTO_INCREMENT,
  principal_id VARCHAR(255) NOT NULL,
  preference_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_type VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_json TEXT NULL,
  updated_at DATETIME(6) NULL,
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
