/// The shared rate limiter: sliding-window counters in a table every node
/// writes, so a limit is one limit across the cluster.
///
/// One row per key and fixed window. A request is counted with a single
/// `INSERT … ON DUPLICATE KEY UPDATE`, atomic on the server, which also hands
/// back this request's place in the count; the previous window's count is read
/// beside it, and the decision follows —
/// the same arithmetic as the in-process limiter
/// (`TomRateLimitDecision.slidingWindow`). Rows two windows old are deleted by
/// an occasional sweep.
///
/// The cost is two statements per counted request on a shared database, which
/// is the price of one global number; a deployment that can live with N times
/// the limit on N nodes keeps the in-process default.
library;

import '../datasources/datasource_initialization.dart';
import '../datasources/queries.dart';
import '../datasources/framework_table.dart';
import '../object_persistence/persistence_annotations.dart';
import 'package:tom_core_kernel/tom_core_kernel.dart';
import '../ratelimit/rate_limit.dart';

/// The default name of the counter table.
const String defaultRateLimitTable = 'tom_rate_limit';

/// The counter table, named [table].
TomFrameworkTable rateLimitTable(String table) => TomFrameworkTable(
  name: table,
  origin: 'rateLimitTable',
  kind: TomTableKind.system,
  columns: const [
    TomFrameworkColumn('bucket', 'VARCHAR(191)'),
    TomFrameworkColumn('rule', 'VARCHAR(64)'),
    TomFrameworkColumn('window_index', 'BIGINT'),
    TomFrameworkColumn('hits', 'INT'),
  ],
  primaryKey: const ['bucket', 'window_index'],
  keys: const [
    TomFrameworkKey('rule_window', ['rule', 'window_index']),
  ],
);

/// A [TomRateLimiter] over a shared data source.
class TomSqlRateLimiter implements TomRateLimiter {
  /// A limiter counting in [table] of [datasource], creating the table on
  /// first use unless [createSchema] is false.
  TomSqlRateLimiter(
    TomDataSource datasource, {
    this.table = defaultRateLimitTable,
    this.createSchema = true,
    DateTime Function()? clock,
  }) : datasource = TomFrameworkTable.systemOf(datasource),
       _clock = clock ?? DateTime.now;

  /// The data source the counters live in.
  final TomDataSource datasource;

  /// The counter table's name.
  final String table;

  /// Whether the limiter creates its table on first use.
  final bool createSchema;

  final DateTime Function() _clock;
  final TomSchemaProvisioning _schema = TomSchemaProvisioning();
  late final TomFrameworkTable _counters = rateLimitTable(table);
  int _hits = 0;
  TomPreparedStatement<TomRateLimitRow>? _increment;

  /// Creates the table when [createSchema] asks for it; once per limiter.
  Future<void> ensureSchema() => _schema.ensure(() async {
    if (createSchema) await _counters.create(datasource);
  });

  @override
  Future<TomRateLimitDecision> hit(String bucket, TomRateLimitRule rule) async {
    await ensureSchema();
    final now = _clock().microsecondsSinceEpoch;
    final w = rule.window.inMicroseconds;
    final index = now ~/ w;
    // The window index is per rule (each rule has its own window length), and
    // the bucket already names the rule, so one table serves every rule.
    //
    // The count is taken and read in one statement, which reports the new
    // value as its generated id (`TomStandardSqlDialect.incrementCounter`).
    // Reading it with a second statement would be wrong under concurrency —
    // every request would see the final total rather than its own place in
    // it, and a burst would be refused almost whole.
    _increment ??= await datasource.prepareStatement<TomRateLimitRow>(
      TomLiteralSelect(
        [TomRateLimitRow],
        query: datasource.sqlDialect.incrementCounter(
          table,
          const {
            'bucket': ':bucket',
            'rule': ':rule',
            'window_index': ':index',
          },
          'hits',
          conflictKey: _counters.primaryKey,
        ),
        parameters: const ['bucket', 'rule', 'index'],
      ),
    );
    final outcome = await _increment!.run({
      'bucket': bucket,
      'rule': rule.name,
      'index': index,
    });
    final current = outcome.generatedId ?? 1;
    final rows = await datasource.executeQuery<TomRateLimitRow>(
      'SELECT window_index, hits FROM $table '
      'WHERE bucket = :bucket AND window_index = :previous',
      {'bucket': bucket, 'previous': index - 1},
    );
    final previous = rows.isEmpty ? 0 : rows.first.hits;
    if (++_hits % 512 == 0) await _sweep(rule.name, index);
    return TomRateLimitDecision.slidingWindow(
      limit: rule.limit,
      window: rule.window,
      elapsed: Duration(microseconds: now - index * w),
      current: current,
      previous: previous,
    );
  }

  /// Deletes [rule]'s counters of windows that can no longer be read.
  ///
  /// Per rule, because a window index is measured in its own rule's window
  /// length: an hour-long rule's current index is far smaller than a
  /// minute-long rule's, and one cut-off for both would delete it live.
  Future<void> _sweep(String rule, int index) async {
    try {
      await datasource.executeCommand(
        'DELETE FROM $table WHERE rule = :rule AND window_index < :oldest',
        {'rule': rule, 'oldest': index - 1},
      );
    } on Object catch (e) {
      // A failed sweep leaves rows that are merely unread; the next sweep
      // retries, and the count of the request in hand is already decided.
      tomLog.warn('Sweeping the rate-limit counters failed: $e');
    }
  }

  /// Deletes every counter. Test-support.
  Future<void> deleteAll() async {
    await ensureSchema();
    await datasource.executeCommand('DELETE FROM $table');
  }
}

/// One counter row, as the data source maps it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomRateLimitRow {
  /// `window_index`.
  @TomDbColumn(columnName: "window_index")
  int windowIndex = 0;

  /// `hits`.
  @TomDbColumn(columnName: "hits")
  int hits = 0;
}
