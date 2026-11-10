/// The persisted form of one default preference — a row of
/// `tom_preference_default`.
///
/// A default is a value a principal reads under a key it has not written
/// itself. It belongs to the whole deployment ([TomPreferenceDefaultScope.deployment])
/// or to the holders of one role ([TomPreferenceDefaultScope.role]); a
/// principal's own value always wins over both, and a role's over the
/// deployment's.
///
/// Unlike [TomUserPreference] the entity declares no row scope: a default is
/// nobody's own row. Every principal reads the defaults that apply to it, and
/// writing them is an administrative act — [TomPreferenceDefaults] is a
/// server-side service, and no endpoint ships for it.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../object_persistence/crud_repository.dart';
import '../object_persistence/persistence_annotations.dart';

/// Who a [TomPreferenceDefault] applies to.
enum TomPreferenceDefaultScope {
  /// Every principal of the deployment.
  deployment,

  /// The principals holding one role ([TomPreferenceDefault.scopeName]).
  role,
}

/// One default preference.
@tomReflector
@TomTenantTable()
@TomDbTable(
  datasource: 'main',
  table: 'tom_preference_default',
  primaryKeyFields: ['id'],
)
class TomPreferenceDefault {
  /// Surrogate primary key (`-1` until persisted).
  @TomEntityId()
  @TomDbColumn(columnName: 'id', isReadOnly: true)
  int id;

  /// The tenant the row belongs to (`@TomTenantTable`): filled by the
  /// repository from the tenant in context and bound into every statement.
  @TomDbColumn(columnName: 'tenant_id')
  String tenantId;

  /// The [TomPreferenceDefaultScope] name: `deployment` or `role`.
  @TomDbColumn(columnName: 'scope_kind')
  String scopeKind;

  /// The role a role default applies to; `''` for a deployment default.
  @TomDbColumn(columnName: 'scope_name')
  String scopeName;

  /// The preference key.
  @TomDbColumn(columnName: 'preference_key')
  String preferenceKey;

  /// The name of the type [valueJson] was written as.
  @TomDbColumn(columnName: 'value_type')
  String valueType;

  /// The value's JSON text.
  @TomDbColumn(columnName: 'value_json')
  String valueJson;

  /// Which role default wins when a principal holds several roles defaulting
  /// one key: the highest precedence, then the role name in code-unit order.
  /// `0` for a deployment default, which has no rival.
  @TomDbColumn(columnName: 'precedence')
  int precedence;

  /// When the default was last written (UTC).
  @TomDbColumn(columnName: 'updated_at')
  DateTime? updatedAt;

  /// Creates a row. Every field defaults, because the repository instantiates a
  /// blank entity and fills it column by column when mapping a result.
  TomPreferenceDefault({
    this.id = -1,
    this.tenantId = '',
    this.scopeKind = '',
    this.scopeName = '',
    this.preferenceKey = '',
    this.valueType = '',
    this.valueJson = '',
    this.precedence = 0,
    this.updatedAt,
  });

  /// The scope this default applies to.
  TomPreferenceDefaultScope get scope =>
      TomPreferenceDefaultScope.values.byName(scopeKind);

  /// This default as the wire DTO a principal reads it as, its
  /// [TomUserPreferenceDto.origin] naming where it came from.
  TomUserPreferenceDto toDto() => TomUserPreferenceDto(
    key: preferenceKey,
    valueType: valueType,
    value: valueJson,
    updatedAt: updatedAt?.toUtc(),
    origin: scope == TomPreferenceDefaultScope.role
        ? tomUserPreferenceOriginRole
        : tomUserPreferenceOriginDeployment,
  );

  /// The DDL this entity expects, reproduced verbatim by the framework
  /// migration — `test/reference_migrations_test.dart` fails if they drift.
  ///
  /// `(tenant_id, scope_kind, scope_name, preference_key)` is unique because
  /// the triple is the default's identity within its tenant, and it is the
  /// conflict key the single-statement
  /// write ([TomSqlDatasourceRepository.upsert]) replaces a default on. The
  /// key and name columns are `COLLATE utf8mb4_bin` for the reason
  /// `tom_user_preference`'s are: identity and order stay case-sensitive.
  static const String createTableSql = '''
CREATE TABLE IF NOT EXISTS tom_preference_default (
  id BIGINT NOT NULL AUTO_INCREMENT,
  tenant_id VARCHAR(32) NOT NULL DEFAULT 'default',
  scope_kind VARCHAR(16) NOT NULL,
  scope_name VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  preference_key VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_type VARCHAR(191) COLLATE utf8mb4_bin NOT NULL,
  value_json TEXT NULL,
  precedence INT NOT NULL DEFAULT 0,
  updated_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tom_preference_default (tenant_id, scope_kind, scope_name, preference_key)
);''';
}

/// The repository for [TomPreferenceDefault].
class TomPreferenceDefaultRepository
    extends TomSqlDatasourceRepository<TomPreferenceDefault, int> {}
