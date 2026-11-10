/// The relational lease lock: one row per resource, in the database the
/// application already has.
///
/// ## Why it belongs next to the relational queue
///
/// The job store and the lock **must share a failure domain**. A lock in one
/// system and a queue in another can each be healthy
/// while the other is unreachable, and the resulting disagreement — the queue
/// says node A claimed the run, the lock says node B holds it — has no
/// resolution. So this lock is meant to live in the same [TomDataSource] as
/// `TomSqlJobStore`: one connection, one thing to be up or down.
///
/// ## How exclusion is arbitrated
///
/// Every transition is a conditional statement whose affected-row count decides
/// the outcome; nothing is decided by the read that preceded it.
///
///  * **First acquisition** is `INSERT IGNORE`. One affected row means this node
///    created the resource and holds token 1; zero means the row already exists
///    and the acquire falls through to the contended path.
///  * **Extension by the live holder** is an `UPDATE` guarded on
///    `resource = :resource AND token = :token AND owner = :owner AND
///    released = 0`. It keeps the token — re-acquisition by the holder is an
///    extension, and issuing a new token would invalidate the lease that very
///    owner is already working under. The preceding read only chooses this
///    branch over takeover; it does not decide the outcome, because a lease
///    that lapsed and was taken over in between now carries a higher token, so
///    the statement matches nothing and the acquire fails rather than reviving
///    a dead lease. That is why the guard needs no `expires_at > :now` — the
///    clause belongs to [renew], which has no preceding read to stand in for
///    it.
///  * **Takeover** of a released or lapsed lease is an `UPDATE` guarded on the
///    `(token, version)` pair the node read, writing `token + 1`. Two nodes
///    racing a lapsed lease both attempt it; exactly one sees an affected row.
///
/// ## Fencing tokens
///
/// The token is a per-resource counter that only ever goes up, and it goes up
/// on every *new* acquisition — takeover, or re-acquisition after a release.
/// It survives release because the row survives release: a released lease keeps
/// its row with `released = 1`, so the counter is still there for the next
/// holder, and so [inspect] can still say who had it and whether they left
/// cleanly. That distinction is what an operator needs after an incident.
///
/// [forget] is the one operation that destroys the counter, which is why it must
/// stay restricted to per-run resource names — a resource whose name is reused
/// (a job name, say) would restart at 1, and a repeated token is not a fence.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'sql_scheduling_sql.dart';

/// A [TomLeaseLock] whose leases are rows in a [TomDataSource].
class TomSqlLeaseLock extends TomLeaseLock {
  /// Creates a lock over [datasource].
  ///
  /// [table] names the lease table. With [createSchema] left `true` the table is
  /// created on first use; set it `false` when the schema is owned by the
  /// migration module. [clock] is injectable so tests can expire leases without
  /// waiting — expiry is absolute-instant arithmetic done here and stored, not
  /// computed by the database, so the two nodes never have to agree about
  /// *whose* clock the database is using, only about the instant it was told.
  TomSqlLeaseLock(
    TomDataSource datasource, {
    this.table = defaultLeaseTable,
    this.createSchema = true,
    DateTime Function()? clock,
  }) : datasource = TomFrameworkTable.systemOf(datasource),
       clock = clock ?? DateTime.now;

  /// Creates a lock over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] keyed `scheduling.lock.unknown_datasource`
  /// when no such data source is registered — a configuration error far better
  /// caught at start-up than on the first claim. The base class rather than a
  /// subtype is deliberate; [TomServerException] says why.
  factory TomSqlLeaseLock.named(
    String datasourceName, {
    String table = defaultLeaseTable,
    bool createSchema = true,
    DateTime Function()? clock,
  }) {
    final info = TomDataSourceInfo.getBaseDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'scheduling.lock.unknown_datasource',
        'The lease lock refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlLeaseLock(
      info.datasource,
      table: table,
      createSchema: createSchema,
      clock: clock,
    );
  }

  /// The data source the lease table lives in.
  final TomDataSource datasource;

  /// The lease table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  /// The clock every expiry is computed against.
  final DateTime Function() clock;

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();

  /// The lease table's single column declaration — see `sql_scheduling_sql.dart`.
  late final TomFrameworkTable _leases = leaseTable(table);

  /// The columns a first acquisition writes, and what each is given.
  ///
  /// Four are bound and three are literals — a first lease is always token 1,
  /// unreleased, at version 1 — which is why this is a name-keyed map rather
  /// than a column list beside a parallel value list. The two halves cannot
  /// drift out of step when neither half exists separately.
  static const Map<String, String> _acquireColumns = {
    'resource': ':resource',
    'owner': ':owner',
    'token': '1',
    'acquired_at': ':acquiredAt',
    'expires_at': ':expiresAt',
    'released': '0',
    'version': '1',
  };

  /// Creates the lease table if it does not exist.
  ///
  /// Idempotent and called automatically by every operation; exposed so a
  /// start-up sequence can provision the schema before serving traffic.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) {
      await _leases.create(datasource);
    }
  });

  @override
  Future<TomLease?> acquire(String resource, String owner, Duration ttl) async {
    await ensureSchema();
    final now = clock().toUtc();
    final expiresAt = now.add(ttl);

    // The uncontended path, as a single atomic create-if-absent. IGNORE turns
    // the duplicate-key collision into a zero row count instead of an
    // exception, which is exactly the answer wanted: someone else owns the
    // resource row, go and look at it.
    final created = await datasource.executeCommand(
      _leases.insertRow(
        datasource.sqlDialect,
        _acquireColumns,
        ignoreConflict: true,
      ),
      {
        'resource': resource,
        'owner': owner,
        'acquiredAt': sqlInstant(now),
        'expiresAt': sqlInstant(expiresAt),
      },
    );
    if (created == BigInt.one) {
      return TomLease(
        resource: resource,
        owner: owner,
        token: 1,
        acquiredAt: now,
        expiresAt: expiresAt,
      );
    }

    final record = await _read(resource);
    // The row vanished between the insert and the read — a concurrent forget().
    // The acquisition is reported as not taken and the method stops there: it
    // makes no second attempt. Retrying belongs to the caller, which already
    // has the loop for it — `TomScheduler` hands the claim back with
    // `TomJobStore.release`, which deliberately does not charge an attempt, so
    // the run is offered again on the next tick at no cost to its retry budget.
    // A second attempt from inside here would only spin against a caller that
    // is actively deleting the resource.
    if (record == null) return null;

    if (record.isHeldAt(now)) {
      if (record.owner != owner) return null;
      // Re-acquisition by the live holder extends and keeps the token.
      final extended = await datasource.executeCommand(
        'UPDATE $table SET acquired_at = :acquiredAt, expires_at = :expiresAt, '
        'version = version + 1 WHERE resource = :resource AND token = :token '
        'AND owner = :owner AND released = 0',
        {
          'acquiredAt': sqlInstant(now),
          'expiresAt': sqlInstant(expiresAt),
          'resource': resource,
          'token': record.token,
          'owner': owner,
        },
      );
      if (extended != BigInt.one) return null;
      return TomLease(
        resource: resource,
        owner: owner,
        token: record.token,
        acquiredAt: now,
        expiresAt: expiresAt,
      );
    }

    // Released or lapsed: a fresh acquisition, and it gets the next token up.
    // The compare-and-set on (token, version) is what makes exactly one of a
    // set of racing takeovers succeed.
    final token = record.token + 1;
    final taken = await datasource.executeCommand(
      'UPDATE $table SET owner = :owner, token = :token, '
      'acquired_at = :acquiredAt, expires_at = :expiresAt, released = 0, '
      'version = version + 1 '
      'WHERE resource = :resource AND token = :priorToken '
      'AND version = :version',
      {
        'owner': owner,
        'token': token,
        'acquiredAt': sqlInstant(now),
        'expiresAt': sqlInstant(expiresAt),
        'resource': resource,
        'priorToken': record.token,
        'version': record.version,
      },
    );
    if (taken != BigInt.one) return null;
    return TomLease(
      resource: resource,
      owner: owner,
      token: token,
      acquiredAt: now,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<TomLease?> renew(TomLease lease, Duration ttl) async {
    await ensureSchema();
    final now = clock().toUtc();
    final expiresAt = now.add(ttl);

    // Guarded on token *and* owner *and* liveness: the same owner re-acquiring
    // after a takeover gets a new token, and the old lease must stay dead. The
    // `expires_at > :now` clause is what makes a lapsed lease unrenewable
    // without a separate read.
    final renewed = await datasource.executeCommand(
      'UPDATE $table SET acquired_at = :acquiredAt, expires_at = :expiresAt, '
      'version = version + 1 WHERE resource = :resource AND owner = :owner '
      'AND token = :token AND released = 0 AND expires_at > :now',
      {
        'acquiredAt': sqlInstant(now),
        'expiresAt': sqlInstant(expiresAt),
        'resource': lease.resource,
        'owner': lease.owner,
        'token': lease.token,
        'now': sqlInstant(now),
      },
    );
    if (renewed != BigInt.one) return null;
    return TomLease(
      resource: lease.resource,
      owner: lease.owner,
      token: lease.token,
      acquiredAt: now,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> release(TomLease lease) async {
    await ensureSchema();
    // Guarded on the token, so the classic late release — a displaced holder
    // finishing its work and freeing a lock it no longer owns — does nothing.
    // The row is marked, never deleted: it carries the fencing counter, and it
    // is what lets inspect() distinguish an orderly departure from a death.
    await datasource.executeCommand(
      'UPDATE $table SET released = 1, version = version + 1 '
      'WHERE resource = :resource AND owner = :owner AND token = :token',
      {'resource': lease.resource, 'owner': lease.owner, 'token': lease.token},
    );
  }

  @override
  Future<TomLeaseInfo> inspect(String resource) async {
    await ensureSchema();
    final record = await _read(resource);
    if (record == null) return TomLeaseInfo.free(resource);
    return TomLeaseInfo(
      resource: resource,
      lease: record.toLease(),
      isHeld: record.isHeldAt(clock().toUtc()),
      wasReleased: record.released,
    );
  }

  @override
  Future<void> forget(TomOneShotResource resource) async {
    await ensureSchema();
    await datasource.executeCommand(
      'DELETE FROM $table WHERE resource = :resource',
      {'resource': resource},
    );
  }

  /// Empties the lease table.
  ///
  /// Not part of [TomLeaseLock], and destructive in the same way [forget] is:
  /// every fencing counter goes back to zero. For provisioning and tests only.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }

  Future<_LeaseRecord?> _read(String resource) async {
    final rows = await datasource.executeQuery<TomLeaseRow>(
      'SELECT ${_leases.columnList} FROM $table WHERE resource = :resource',
      {'resource': resource},
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return _LeaseRecord(
      resource: row.resource,
      owner: row.owner,
      token: row.token,
      acquiredAt: parseSqlInstant(row.acquiredAt),
      expiresAt: parseSqlInstant(row.expiresAt),
      released: row.released != 0,
      version: row.version,
    );
  }

  @override
  String toString() => 'TomSqlLeaseLock($table)';
}

/// The lease row's fields, decoupled from the reflected row holder so nothing
/// outside this file depends on the mapping type.
class _LeaseRecord {
  const _LeaseRecord({
    required this.resource,
    required this.owner,
    required this.token,
    required this.acquiredAt,
    required this.expiresAt,
    required this.released,
    required this.version,
  });

  final String resource;
  final String owner;
  final int token;
  final DateTime acquiredAt;
  final DateTime expiresAt;
  final bool released;
  final int version;

  bool isHeldAt(DateTime now) => !released && now.isBefore(expiresAt);

  TomLease toLease() => TomLease(
    resource: resource,
    owner: owner,
    token: token,
    acquiredAt: acquiredAt,
    expiresAt: expiresAt,
  );
}

/// One row of the lease table, as the result mapper materialises it.
///
/// The instant columns are typed `String` for the same reason as
/// `TomJobRunRow`'s: the driver's `DateTime` mapping produces a *local*
/// `DateTime`, which would compare unequal to the UTC value that was written.
/// `released` is an `int` because the column is `TINYINT(1)`.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomLeaseRow {
  /// The resource the lease names.
  @TomDbColumn(columnName: "resource")
  String resource = "";

  /// The node holding — or last to have held — the resource.
  @TomDbColumn(columnName: "owner")
  String owner = "";

  /// The fencing token of the current or most recent lease.
  @TomDbColumn(columnName: "token")
  int token = 0;

  /// When the lease was granted, as stored UTC text.
  @TomDbColumn(columnName: "acquired_at")
  String acquiredAt = "";

  /// When the lease lapses, as stored UTC text.
  @TomDbColumn(columnName: "expires_at")
  String expiresAt = "";

  /// `1` when the holder released the lease deliberately.
  @TomDbColumn(columnName: "released")
  int released = 0;

  /// The write counter, incremented on every update of this row.
  @TomDbColumn(columnName: "version")
  int version = 1;
}
