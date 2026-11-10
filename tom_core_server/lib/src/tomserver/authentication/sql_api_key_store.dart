/// Service accounts and API keys in a data source every node shares.
///
/// Two framework tables, `tom_service_account` and `tom_api_key`. The key
/// table holds the SHA-256 of each secret and never the secret itself, so a
/// read of the table hands nobody a working key. A write replaces the row
/// whole (`REPLACE`): a key's record changes only by revocation, expiry and
/// its last-used stamp, and the service always writes the record it read.
library;

import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../object_persistence/persistence_annotations.dart';
import 'api_keys.dart';

/// The default name of the service-account table.
const String defaultServiceAccountTable = 'tom_service_account';

/// The default name of the API-key table.
const String defaultApiKeyTable = 'tom_api_key';

/// The service-account table, named [table].
TomFrameworkTable serviceAccountTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'serviceAccountTable',
  kind: TomTableKind.system,
  columns: const [
    TomFrameworkColumn('id', 'VARCHAR(191)'),
    TomFrameworkColumn('name', 'VARCHAR(191)'),
    TomFrameworkColumn('roles', 'TEXT'),
    TomFrameworkColumn('tenant', 'VARCHAR(32)', nullable: true),
    TomFrameworkColumn('organization', 'VARCHAR(191)', nullable: true),
    TomFrameworkColumn('disabled', 'TINYINT(1)', defaultValue: '0'),
  ],
  primaryKey: const ['id'],
);

/// The API-key table, named [table].
TomFrameworkTable apiKeyTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'apiKeyTable',
  kind: TomTableKind.system,
  columns: const [
    TomFrameworkColumn('id', 'VARCHAR(64)'),
    TomFrameworkColumn('account_id', 'VARCHAR(191)'),
    TomFrameworkColumn('secret_hash', 'CHAR(64)'),
    TomFrameworkColumn('roles', 'TEXT'),
    TomFrameworkColumn('label', 'VARCHAR(191)'),
    TomFrameworkColumn('created_at', 'DATETIME(6)'),
    TomFrameworkColumn('expires_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('revoked_at', 'DATETIME(6)', nullable: true),
    TomFrameworkColumn('last_used_at', 'DATETIME(6)', nullable: true),
  ],
  primaryKey: const ['id'],
  keys: const [
    TomFrameworkKey('account', ['account_id']),
  ],
);

/// A [TomApiKeyStore] over a data source.
class TomSqlApiKeyStore implements TomApiKeyStore {
  /// A store over [datasource], in [accountTable] and [keyTable], creating
  /// them on first use unless [createSchema] is false (a deployment whose
  /// migrations create them).
  TomSqlApiKeyStore(
    TomDataSource datasource, {
    this.accountTable = defaultServiceAccountTable,
    this.keyTable = defaultApiKeyTable,
    this.createSchema = true,
  }) : datasource = TomFrameworkTable.systemOf(datasource);

  /// The data source holding both tables.
  final TomDataSource datasource;

  /// The service-account table's name.
  final String accountTable;

  /// The API-key table's name.
  final String keyTable;

  /// Whether the store creates its tables on first use.
  final bool createSchema;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  late final TomFrameworkTable _accounts = serviceAccountTable(accountTable);
  late final TomFrameworkTable _keys = apiKeyTable(keyTable);

  /// Creates the tables when [createSchema] asks for it; once per store.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (!createSchema) return;
    await _accounts.create(datasource);
    await _keys.create(datasource);
  });

  @override
  Future<void> saveAccount(TomServiceAccount account) async {
    await ensureSchema();
    await _accounts.replaceRow(
      datasource,
      const {
        'id': ':id',
        'name': ':name',
        'roles': ':roles',
        'tenant': ':tenant',
        'organization': ':organization',
        'disabled': ':disabled',
      },
      {
        'id': account.id,
        'name': account.name,
        'roles': jsonEncode(account.roles),
        'tenant': account.tenant,
        'organization': account.organization,
        'disabled': account.disabled ? 1 : 0,
      },
    );
  }

  @override
  Future<TomServiceAccount?> findAccount(String id) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomServiceAccountRow>(
      'SELECT ${_accounts.columnList} FROM $accountTable WHERE id = :id',
      {'id': id},
    );
    return rows.isEmpty ? null : _accountOf(rows.first);
  }

  @override
  Future<List<TomServiceAccount>> accounts() async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomServiceAccountRow>(
      'SELECT ${_accounts.columnList} FROM $accountTable ORDER BY id',
    );
    return [for (final row in rows) _accountOf(row)];
  }

  @override
  Future<void> saveKey(TomApiKey key) async {
    await ensureSchema();
    await _keys.replaceRow(
      datasource,
      const {
        'id': ':id',
        'account_id': ':accountId',
        'secret_hash': ':secretHash',
        'roles': ':roles',
        'label': ':label',
        'created_at': ':createdAt',
        'expires_at': ':expiresAt',
        'revoked_at': ':revokedAt',
        'last_used_at': ':lastUsedAt',
      },
      {
        'id': key.id,
        'accountId': key.accountId,
        'secretHash': key.secretHash,
        'roles': jsonEncode(key.roles),
        'label': key.label,
        'createdAt': sqlInstant(key.createdAt),
        'expiresAt': _instantOrNull(key.expiresAt),
        'revokedAt': _instantOrNull(key.revokedAt),
        'lastUsedAt': _instantOrNull(key.lastUsedAt),
      },
    );
  }

  @override
  Future<TomApiKey?> findKey(String id) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomApiKeyRow>(
      'SELECT ${_keys.columnList} FROM $keyTable WHERE id = :id',
      {'id': id},
    );
    return rows.isEmpty ? null : _keyOf(rows.first);
  }

  @override
  Future<List<TomApiKey>> keysOf(String accountId) async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomApiKeyRow>(
      'SELECT ${_keys.columnList} FROM $keyTable '
      'WHERE account_id = :accountId ORDER BY created_at',
      {'accountId': accountId},
    );
    return [for (final row in rows) _keyOf(row)];
  }

  @override
  Future<void> touch(String keyId, DateTime at) async {
    await ensureSchema();
    await datasource.executeCommand(
      'UPDATE $keyTable SET last_used_at = :at WHERE id = :id',
      {'id': keyId, 'at': sqlInstant(at)},
    );
  }

  /// Deletes every account and key. Test-support.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $keyTable');
    await datasource.executeCommand('DELETE FROM $accountTable');
  }

  static String? _instantOrNull(DateTime? at) =>
      at == null ? null : sqlInstant(at);

  static DateTime? _parseOrNull(String? at) =>
      at == null || at.isEmpty ? null : parseSqlInstant(at);

  static List<String> _roles(String json) =>
      json.isEmpty ? const [] : (jsonDecode(json) as List).cast<String>();

  static TomServiceAccount _accountOf(TomServiceAccountRow row) =>
      TomServiceAccount(
        id: row.id,
        name: row.name,
        roles: _roles(row.roles),
        tenant: row.tenant,
        organization: row.organization,
        disabled: row.disabled,
      );

  static TomApiKey _keyOf(TomApiKeyRow row) => TomApiKey(
    id: row.id,
    accountId: row.accountId,
    secretHash: row.secretHash,
    roles: _roles(row.roles),
    label: row.label,
    createdAt: parseSqlInstant(row.createdAt),
    expiresAt: _parseOrNull(row.expiresAt),
    revokedAt: _parseOrNull(row.revokedAt),
    lastUsedAt: _parseOrNull(row.lastUsedAt),
  );
}

/// One row of the service-account table, as the data source maps it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomServiceAccountRow {
  /// `id`.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// `name`.
  @TomDbColumn(columnName: "name")
  String name = "";

  /// `roles`, a JSON array.
  @TomDbColumn(columnName: "roles")
  String roles = "";

  /// `tenant`.
  @TomDbColumn(columnName: "tenant")
  String? tenant;

  /// `organization`.
  @TomDbColumn(columnName: "organization")
  String? organization;

  /// `disabled`.
  @TomDbColumn(columnName: "disabled")
  bool disabled = false;
}

/// One row of the API-key table, as the data source maps it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomApiKeyRow {
  /// `id`.
  @TomDbColumn(columnName: "id")
  String id = "";

  /// `account_id`.
  @TomDbColumn(columnName: "account_id")
  String accountId = "";

  /// `secret_hash`.
  @TomDbColumn(columnName: "secret_hash")
  String secretHash = "";

  /// `roles`, a JSON array.
  @TomDbColumn(columnName: "roles")
  String roles = "";

  /// `label`.
  @TomDbColumn(columnName: "label")
  String label = "";

  /// `created_at`.
  @TomDbColumn(columnName: "created_at")
  String createdAt = "";

  /// `expires_at`.
  @TomDbColumn(columnName: "expires_at")
  String? expiresAt;

  /// `revoked_at`.
  @TomDbColumn(columnName: "revoked_at")
  String? revokedAt;

  /// `last_used_at`.
  @TomDbColumn(columnName: "last_used_at")
  String? lastUsedAt;
}
