/// The idempotent receiver: processing each message once, although a broker
/// delivers it at least once.
///
/// A broker that promises at-least-once delivery redelivers a message whose
/// acknowledgement it did not receive — after a consumer crashed between doing
/// the work and acknowledging, after a network blip, after a rebalance. A
/// consumer that simply does the work again charges a card twice or sends a
/// second welcome mail. The inbox closes that gap:
///
/// 1. **In one database transaction** it records `(consumer, message id)` in
///    the inbox table and runs the consumer's work. The record is an insert the
///    table's primary key refuses for a message already processed; then the
///    work is skipped.
/// 2. **After the commit** it acknowledges the message to the broker — for a
///    message it skipped as well, so the broker stops redelivering it.
///
/// A crash before the commit rolls back both the record and the work, and the
/// broker redelivers a message that was never processed. A crash after the
/// commit and before the acknowledgement makes the broker redeliver a message
/// the inbox recognises and skips. Either way the work is done exactly once:
/// at-least-once delivery becomes effectively-once processing.
///
/// Two deliveries of one message processed at the same moment — two nodes
/// after a rebalance — are serialised by the database: the second insert waits
/// on the first transaction's key, and finds the row once it commits (or claims
/// it, if the first rolled back).
///
/// The consumer's work must write to the inbox's data source, so both commit
/// together: work on another data source joins the same transaction only when
/// both are XA data sources (see `transactions.md`). Work that is not a database
/// write at all — a call to another service — is not covered and must be
/// idempotent itself.
///
/// The inbox does not know the broker. A consumer hands [TomInbox.process] the
/// message id and two functions — the work and the acknowledgement — so any
/// broker's consumer loop can use it, and the message bus wraps its handlers
/// in it.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import '../transactions/transaction_manager.dart';
import 'inbox_sql.dart';

/// An inbox argument that cannot be used.
///
/// | Key | Meaning |
/// | --- | ------- |
/// | `messaging.inbox.invalid_consumer` | The consumer name is empty or longer than 150 characters. |
/// | `messaging.inbox.invalid_message_id` | The message id is empty or longer than 191 characters. |
class TomInboxException extends TomServerException {
  /// Creates the exception; see [TomServerException] for the fields.
  TomInboxException(super.key, super.defaultUserMessage, {super.parameters})
    : super(clientThrow: false);
}

/// The outcome of [TomInbox.process].
enum TomInboxOutcome {
  /// The message was new: the work ran and was committed with its record.
  processed,

  /// The consumer had processed the message before: the work was skipped.
  duplicate,
}

/// An idempotent receiver — see the library documentation.
abstract class TomInbox {
  /// Processes the message [messageId] for [consumer] once.
  ///
  /// Records the message and runs [work] in one transaction; a message already
  /// recorded skips [work]. After the commit — for a processed and for a
  /// duplicate message — calls [acknowledge], the broker's acknowledgement.
  /// When [work] throws, the transaction rolls back (the record with it),
  /// [acknowledge] is not called and the error is rethrown, so the broker
  /// redelivers the message.
  ///
  /// Throws `messaging.inbox.invalid_consumer` / `invalid_message_id` for an
  /// empty or over-long name, before anything is written.
  Future<TomInboxOutcome> process(
    String consumer,
    String messageId,
    FutureOr<void> Function() work, {
    FutureOr<void> Function()? acknowledge,
  }) async {
    _require(consumer, 150, 'consumer', 'messaging.inbox.invalid_consumer');
    _require(
      messageId,
      191,
      'message id',
      'messaging.inbox.invalid_message_id',
    );
    final outcome = await recordAndRun(consumer, messageId, work);
    if (acknowledge != null) await acknowledge();
    return outcome;
  }

  /// Records [messageId] for [consumer] and runs [work], atomically; answers
  /// [TomInboxOutcome.duplicate] without running [work] when the record
  /// exists. The step [process] wraps with validation and acknowledgement.
  Future<TomInboxOutcome> recordAndRun(
    String consumer,
    String messageId,
    FutureOr<void> Function() work,
  );

  /// Whether [consumer] has processed [messageId].
  Future<bool> hasProcessed(String consumer, String messageId);

  /// Removes the records of messages processed before [before]; answers how
  /// many were removed.
  ///
  /// A record must outlive every redelivery of its message, so [before] lies
  /// further back than the broker's longest redelivery window (its retention or
  /// its dead-letter delay). Nothing purges automatically: how long a broker can
  /// redeliver is a deployment's knowledge, not the inbox's.
  Future<int> purgeProcessedBefore(DateTime before);

  static void _require(String value, int max, String what, String key) {
    if (value.isNotEmpty && value.length <= max) return;
    throw TomInboxException(
      key,
      'The inbox $what must be 1 to $max characters long; it was '
      '${value.length}.',
      parameters: {'length': value.length, 'max': max},
    );
  }
}

/// The inbox of one process, in memory: for tests and for a single process
/// whose work is in memory too. It forgets everything on restart, so it cannot
/// stand behind a durable broker.
class TomMemoryInbox extends TomInbox {
  /// An empty inbox reading [clock] for the processing time.
  TomMemoryInbox({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, DateTime> _processed = {};
  final Set<String> _inFlight = {};

  static String _key(String consumer, String messageId) =>
      '$consumer\u0000$messageId';

  @override
  Future<TomInboxOutcome> recordAndRun(
    String consumer,
    String messageId,
    FutureOr<void> Function() work,
  ) async {
    final key = _key(consumer, messageId);
    // A delivery arriving while the same message is being processed waits for
    // it, as the second insert does in a database.
    while (_inFlight.contains(key)) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    if (_processed.containsKey(key)) return TomInboxOutcome.duplicate;
    _inFlight.add(key);
    try {
      await work();
      _processed[key] = _clock().toUtc();
      return TomInboxOutcome.processed;
    } finally {
      _inFlight.remove(key);
    }
  }

  @override
  Future<bool> hasProcessed(String consumer, String messageId) async =>
      _processed.containsKey(_key(consumer, messageId));

  @override
  Future<int> purgeProcessedBefore(DateTime before) async {
    final old = [
      for (final e in _processed.entries)
        if (e.value.isBefore(before.toUtc())) e.key,
    ];
    old.forEach(_processed.remove);
    return old.length;
  }
}

/// The inbox in a SQL data source, written in the same transaction as the
/// consumer's work — see the library documentation.
class TomSqlInbox extends TomInbox {
  /// An inbox in [table] of [datasource] — placed per call for the tenant in
  /// context ([TomFrameworkTable.placed]): the inbox is a tenant table, kept
  /// where the tenant's data and the consumer's work are.
  ///
  /// With [createSchema] (the default) the table is created on first use; a
  /// deployment whose database user may not run DDL applies the shipped
  /// migration instead and passes `false`.
  TomSqlInbox(
    this.datasource, {
    this.table = defaultInboxTable,
    this.createSchema = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// The data source the store was built over; [placedDatasource] is where the
  /// inbox and the consumer's work meet for the tenant in context.
  final TomDataSource datasource;

  /// The data source the inbox is reached in for the tenant in context.
  TomDataSource get placedDatasource => _inbox.placed(datasource);

  /// The tenant in context as the `tenant` column holds it — `''` for none.
  static String get _tenant => TomTenantContext.currentId ?? '';

  /// The inbox table's name.
  final String table;

  /// Whether the table is created on first use.
  final bool createSchema;

  final DateTime Function() _clock;
  final Expando<TomSchemaProvisioning> _schemas = Expando();
  late final TomFrameworkTable _inbox = inboxTable(table);

  /// Creates the inbox table in the tenant in context's data source if it does
  /// not exist. Idempotent, and called by every operation; exposed so a
  /// start-up can provision it before consuming.
  Future<void> ensureSchema() {
    final target = placedDatasource;
    return (_schemas[target] ??= TomSchemaProvisioning()).ensure(() async {
      if (createSchema) await _inbox.create(target);
    });
  }

  @override
  Future<TomInboxOutcome> recordAndRun(
    String consumer,
    String messageId,
    FutureOr<void> Function() work,
  ) async {
    // Outside the transaction: DDL commits implicitly on MariaDB, and must not
    // end the consumer's transaction half way.
    await ensureSchema();
    final target = placedDatasource;
    return TomTransactionManager.runInTransaction((_) async {
      final inserted = await target.executeCommand(
        _inbox.insertRow(target.sqlDialect, const {
          'tenant': ':tenant',
          'consumer': ':consumer',
          'message_id': ':messageId',
          'processed_at': ':processedAt',
        }, ignoreConflict: true),
        {
          'tenant': _tenant,
          'consumer': consumer,
          'messageId': messageId,
          'processedAt': sqlInstant(_clock()),
        },
      );
      if (inserted == BigInt.zero) return TomInboxOutcome.duplicate;
      await work();
      return TomInboxOutcome.processed;
    });
  }

  @override
  Future<bool> hasProcessed(String consumer, String messageId) async {
    await ensureSchema();
    final rows = await placedDatasource.executeQuery<TomInboxRow>(
      'SELECT consumer, message_id FROM $table WHERE tenant = :tenant '
      'AND consumer = :consumer AND message_id = :messageId',
      {'tenant': _tenant, 'consumer': consumer, 'messageId': messageId},
    );
    return rows.isNotEmpty;
  }

  /// Purges the data source the tenant in context reaches — the records of
  /// every tenant kept there; a tenant with a schema or a database of its own
  /// is purged inside that tenant (`TomTenancy.forEachTenant`).
  @override
  Future<int> purgeProcessedBefore(DateTime before) async {
    await ensureSchema();
    final removed = await placedDatasource.executeCommand(
      'DELETE FROM $table WHERE processed_at < :before',
      {'before': sqlInstant(before)},
    );
    return removed.toInt();
  }

  /// Empties the inbox. Not part of [TomInbox] — no consumer should want it;
  /// it exists for provisioning and tests.
  Future<void> deleteAll() async {
    await ensureSchema();
    await placedDatasource.executeCommand('DELETE FROM $table');
  }
}

/// One row of the inbox table, as [TomSqlInbox.hasProcessed] reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["consumer", "messageId"],
)
class TomInboxRow {
  /// The consumer.
  @TomDbColumn(columnName: "consumer")
  String consumer = "";

  /// The message.
  @TomDbColumn(columnName: "message_id")
  String messageId = "";
}
