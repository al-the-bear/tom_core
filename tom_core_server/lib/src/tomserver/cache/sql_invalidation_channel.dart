/// Invalidations carried between nodes through a table every node can read.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../authorization/authorization_cache.dart';
import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../object_persistence/persistence_annotations.dart';
import 'bus_invalidation_channel.dart';
import 'cache_invalidation.dart';
import 'invalidation_sql.dart';
import 'server_cache.dart';

/// A [TomInvalidationChannel] over a database every node already has.
///
/// [publish] inserts a row into the invalidation log; every node polls the log
/// every [pollInterval] for rows above the highest id it has seen, and applies
/// the ones other nodes wrote. No new infrastructure is needed, and the
/// staleness bound is the poll interval: a revocation raised on one node is
/// applied on every other within [pollInterval] plus one query.
///
/// On [start] a node first applies every revocation raised within
/// [retention] — the revocations still in force — so a node that joins the
/// cluster, or restarts, does not serve a token another node revoked before it
/// was there. Rows older than [retention] are deleted as the log is polled.
///
/// The table is also a [TomInvalidationLog]: [record] writes a row and
/// [revocationsInForce] reads the revocations within [retention], which is how
/// `TomBusInvalidationChannel` remembers revocations without polling.
class TomSqlInvalidationChannel
    implements TomInvalidationChannel, TomInvalidationLog {
  /// Creates a channel over [datasource].
  ///
  /// With [createSchema] left `true` the log table is created on first use;
  /// set it `false` when the migration module owns the schema. [retention]
  /// defaults to [TomAuthorizationCache.revocationRetention], which is how long
  /// a revocation has to be remembered.
  TomSqlInvalidationChannel(
    this.datasource, {
    this.table = defaultInvalidationTable,
    this.pollInterval = const Duration(seconds: 2),
    Duration? retention,
    this.createSchema = true,
  }) : retention = retention ?? TomAuthorizationCache.revocationRetention;

  /// Creates a channel over the registered data source named [datasourceName].
  ///
  /// Throws a [TomCacheException] keyed
  /// `cache.invalidation.unknown_datasource` when no such data source is
  /// registered — a configuration error far better caught at start-up.
  factory TomSqlInvalidationChannel.named(
    String datasourceName, {
    String table = defaultInvalidationTable,
    Duration pollInterval = const Duration(seconds: 2),
    Duration? retention,
    bool createSchema = true,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomCacheException(
        'cache.invalidation.unknown_datasource',
        'The cache-invalidation channel refers to a data source that is not '
            'registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlInvalidationChannel(
      info.datasource,
      table: table,
      pollInterval: pollInterval,
      retention: retention,
      createSchema: createSchema,
    );
  }

  /// The data source the log lives in.
  final TomDataSource datasource;

  /// The log table.
  final String table;

  /// How often the log is read; also the [stalenessBound].
  final Duration pollInterval;

  /// How long a row is kept, and how far back [start] looks for revocations.
  final Duration retention;

  /// Whether to create the log table on first use.
  final bool createSchema;

  late final TomFrameworkTable _rows = invalidationTable(table);

  final TomSchemaProvisioning _schema = TomSchemaProvisioning();
  int _lastSeenId = 0;
  Timer? _timer;
  bool _polling = false;
  DateTime? _lastPruned;
  Future<void> Function(TomCacheInvalidation)? _deliver;

  @override
  Duration get stalenessBound => pollInterval;

  /// Whether the channel is polling.
  bool get isRunning => _timer != null;

  /// Creates the log table if it does not exist. Idempotent.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) {
      await _rows.create(datasource);
    }
  });

  @override
  Future<void> start(
    Future<void> Function(TomCacheInvalidation invalidation) deliver,
  ) async {
    await ensureSchema();
    _deliver = deliver;
    final watermark = await datasource.executeQuery<TomCacheInvalidationRow>(
      'SELECT COALESCE(MAX(id), 0) AS id FROM $table',
    );
    _lastSeenId = watermark.isEmpty ? 0 : watermark.single.id;
    final inForce = await datasource.executeQuery<TomCacheInvalidationRow>(
      'SELECT ${_rows.columnList} FROM $table '
      "WHERE kind = 'principal' AND raised_at >= :cutoff AND id <= :last "
      'ORDER BY id',
      {
        'cutoff': DateTime.now().toUtc().subtract(retention),
        'last': _lastSeenId,
      },
    );
    for (final row in inForce) {
      await deliver(row.toInvalidation());
    }
    _timer?.cancel();
    // In the root zone, so the request or start-up flow that happens to
    // install the channel does not end up owning process-lifetime work.
    _timer = Zone.root.createPeriodicTimer(pollInterval, (_) => poll());
  }

  /// Reads the rows above the last one seen and delivers those other nodes
  /// wrote; prunes rows past [retention] at most once per [retention] / 24.
  ///
  /// Runs on the timer; callable directly, which is what a test does. A poll
  /// still running when the next is due is not overlapped. A failure is
  /// logged and the next poll tries again, from the same row.
  Future<void> poll() async {
    final deliver = _deliver;
    if (_polling || deliver == null) return;
    _polling = true;
    try {
      final rows = await datasource.executeQuery<TomCacheInvalidationRow>(
        'SELECT ${_rows.columnList} FROM $table WHERE id > :last '
        'ORDER BY id LIMIT 1000',
        {'last': _lastSeenId},
      );
      for (final row in rows) {
        if (row.origin != TomCacheInvalidator.nodeId) {
          await deliver(row.toInvalidation());
        }
        _lastSeenId = row.id;
      }
      await _pruneIfDue();
    } catch (error) {
      tomLog.warn(
        'TomSqlInvalidationChannel: reading $table failed, retrying at the '
        'next poll: $error',
      );
    } finally {
      _polling = false;
    }
  }

  Future<void> _pruneIfDue() async {
    final now = DateTime.now().toUtc();
    final last = _lastPruned;
    if (last != null && now.difference(last) < retention ~/ 24) return;
    _lastPruned = now;
    await datasource.executeCommand(
      'DELETE FROM $table WHERE raised_at < :cutoff',
      {'cutoff': now.subtract(retention)},
    );
  }

  /// Writes [invalidation] to the log — which is all [publish] does: the other
  /// nodes read it at their next poll.
  @override
  Future<void> publish(TomCacheInvalidation invalidation) =>
      record(invalidation);

  @override
  Future<List<TomCacheInvalidation>> revocationsInForce() async {
    await ensureSchema();
    final rows = await datasource.executeQuery<TomCacheInvalidationRow>(
      'SELECT ${_rows.columnList} FROM $table '
      "WHERE kind = 'principal' AND raised_at >= :cutoff ORDER BY id",
      {'cutoff': DateTime.now().toUtc().subtract(retention)},
    );
    return [for (final row in rows) row.toInvalidation()];
  }

  @override
  Future<void> record(TomCacheInvalidation invalidation) async {
    await ensureSchema();
    await datasource.executeCommand(
      _rows.insertRow(datasource.sqlDialect, const {
        'kind': ':kind',
        'target': ':target',
        'entry_key': ':entryKey',
        'origin': ':origin',
        'raised_at': ':raisedAt',
      }),
      {
        'kind': invalidation.kind.name,
        'target': invalidation.target,
        'entryKey': invalidation.key,
        'origin': invalidation.origin,
        'raisedAt': invalidation.at,
      },
    );
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _deliver = null;
  }
}

/// One row of the invalidation log, as the channel reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomCacheInvalidationRow {
  /// The row's place in the log.
  @TomDbColumn(columnName: "id")
  int id = 0;

  /// The [TomInvalidationKind] name.
  @TomDbColumn(columnName: "kind")
  String kind = "";

  /// The username or cache name.
  @TomDbColumn(columnName: "target")
  String target = "";

  /// The entry key of a single-entry invalidation.
  @TomDbColumn(columnName: "entry_key")
  String? entryKey;

  /// The node that wrote it.
  @TomDbColumn(columnName: "origin")
  String origin = "";

  /// When it was raised, as the stored `DATETIME(6)` text.
  @TomDbColumn(columnName: "raised_at")
  String raisedAt = "";

  /// The invalidation this row records.
  TomCacheInvalidation toInvalidation() => TomCacheInvalidation.fromParts(
    kind: kind,
    target: target,
    key: entryKey,
    at: parseSqlInstant(raisedAt),
    origin: origin,
  );
}
