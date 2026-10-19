/// A relational audit sink: one row per entry, in the database the application
/// already operates.
///
/// ## Why a table is the hard case
///
/// `TomFileAuditSink` is append-only *by construction* — the only file
/// operation it performs is "append a line", and rotation renames rather than
/// rewrites. A table has no such property. `UPDATE` and `DELETE` are ordinary
/// statements, so a trail stored in one is append-only only because something
/// outside the code says so. That "something" is the deployment's write-once
/// story, and this sink cannot supply it: **the grant is the guarantee, and a
/// grant is not a thing a library can hold.**
///
/// What the framework can do, and does here, is three things:
///
///  * take its **own** [TomDataSource], named explicitly and never defaulted to
///    the application's, so the restricted credential has somewhere to live;
///  * **probe** the deployment at open — see [verifyWriteOnce] — and report
///    what it found instead of assuming; and
///  * refuse to start when the deployment asked for the guarantee and the probe
///    says it is absent ([requireWriteOnce]).
///
/// The full reasoning, and the three postures a deployment may take, are in
/// `doc/audit.md` § "The Write-Once Story".
///
/// ## Why not through the repository
///
/// `TomSqlDatasourceRepository` is itself an audit chokepoint: every `save` it
/// performs writes an audit record. A repository-backed sink would therefore
/// audit its own writes, and each entry would produce another. The regress
/// could be broken with `TomAuditTrail.runUnaudited`, but a bypass is the
/// weaker guarantee — it holds only as long as every write path remembers to
/// wrap itself. Talking to the data source directly makes the regress
/// impossible instead of merely avoided.
///
/// ## Why the chain is per writer
///
/// Each entry hashes the previous entry's hash, so a chain has exactly one
/// head. Two processes appending to one table each track their own head in
/// memory; interleaved, their rows read back as a sequence that fails its own
/// verification — not because anything was tampered with, but because it was
/// never one chain. [writer] is therefore a **required** argument: a per-node
/// chain makes a clustered deployment correct, and making the argument
/// mandatory makes the question impossible to overlook. The unique key on
/// `(writer, previous_hash)` then turns a fork into a duplicate-key error at
/// insert time rather than silent corruption found at the next audit.
library;

import 'dart:async';
import 'dart:convert';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../datasources/datasource_initialization.dart';
import '../datasources/framework_table.dart';
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
import 'audit_query.dart';
import 'audit_record.dart';
import 'audit_sink.dart';
import 'sql_audit_sql.dart';

/// What a deployment's audit table actually permits, as observed rather than
/// as configured.
///
/// Two independent observations, because neither alone is conclusive:
///
///  * a **privilege** probe — an `UPDATE`/`DELETE` restricted to no rows, which
///    still fails at permission-check time when the grant is missing; and
///  * a **trigger** probe of `information_schema.TRIGGERS`, because a
///    zero-row statement matches nothing and therefore fires no `FOR EACH ROW`
///    trigger. A trigger-protected table looks perfectly mutable to the
///    privilege probe alone.
class TomAuditWriteOnceCheck {
  /// Creates a check result.
  const TomAuditWriteOnceCheck({
    required this.table,
    required this.grantsUpdate,
    required this.grantsDelete,
    this.updateGuardTrigger,
    this.deleteGuardTrigger,
  });

  /// The table that was probed.
  final String table;

  /// Whether the connected user may `UPDATE` the table.
  final bool grantsUpdate;

  /// Whether the connected user may `DELETE` from the table.
  final bool grantsDelete;

  /// The name of a `BEFORE UPDATE` trigger on the table, when one exists.
  final String? updateGuardTrigger;

  /// The name of a `BEFORE DELETE` trigger on the table, when one exists.
  final String? deleteGuardTrigger;

  /// Whether an existing entry can be rewritten in place.
  ///
  /// The property that matters most. An attacker who can `UPDATE` can rewrite
  /// the whole chain from the point of an edit onwards and recompute every hash
  /// after it, which is exactly the attack the chain cannot detect on its own.
  bool get updatesBlocked => !grantsUpdate || updateGuardTrigger != null;

  /// Whether an existing entry can be removed.
  ///
  /// Weaker than [updatesBlocked] as a requirement, because retention needs
  /// `DELETE`: a serving credential without it is the stronger posture, and
  /// pruning is then an operator action performed with a different credential.
  bool get deletesBlocked => !grantsDelete || deleteGuardTrigger != null;

  /// Whether the table admits nothing but inserts.
  bool get isAppendOnly => updatesBlocked && deletesBlocked;

  /// A one-line description of what was found, for start-up logging.
  String get summary {
    String how(bool blocked, bool granted, String? trigger) => blocked
        ? (granted ? 'blocked by $trigger' : 'not granted')
        : 'PERMITTED';
    return 'audit table $table: '
        'UPDATE ${how(updatesBlocked, grantsUpdate, updateGuardTrigger)}, '
        'DELETE ${how(deletesBlocked, grantsDelete, deleteGuardTrigger)}';
  }

  @override
  String toString() => summary;
}

/// A [TomAuditSink] whose entries are rows in a [TomDataSource].
///
/// ## This sink retains nothing on its own
///
/// `TomFileAuditSink` takes `retention` and `maxFiles` as constructor arguments
/// and enforces them itself, on every open and every rotation. **This sink has
/// no equivalent.** [purgeBefore] and [purgeToMaxEntries] exist, but nothing in
/// the framework ever calls them: a trail in a table grows without bound until
/// the deployment schedules a purge. That asymmetry is easy to read as a gap in
/// the API and is not one — it follows from the same fact as the whole
/// write-once story above. Deleting a row needs `DELETE`, the credential that
/// serves this sink should not hold it, and a sink cannot quietly prune a table
/// it was deliberately not granted permission to prune.
///
/// The intended home for the call is the **scheduler** — `TomScheduler` and
/// `@TomScheduledJob` in `tom_core_kernel`. A purge is a good fit for it: it is
/// idempotent, which is what the scheduler's at-least-once guarantee requires,
/// and it is exactly the nightly housekeeping a job store exists to drive.
/// `tom_core_samples/advanced_ops_server` shows the shape in `OpsPurgeJob` —
/// including computing the cutoff from the run's `scheduledFor` rather than
/// `DateTime.now()`, so a recovered run trims the window it was planned for.
///
/// Two things to get right when scheduling it:
///
///  * **Both purges are scoped to [writer].** A single clustered job trims only
///    the chain of the sink that node happens to hold, so a deployment with
///    several writers must either run the job on every node or give one job a
///    sink per writer. A nightly purge that silently trims one node's rows is
///    worse than none, because the table still grows and the job reports
///    success.
///  * **A `BEFORE DELETE` guard trigger blocks it.** That is the trade
///    `auditTrailNoDeleteTriggerDdl` makes explicit: a table nothing can delete
///    from is a table nothing can prune. Choose one.
///
/// This is *not* the same case as anchoring, which
/// `advanced_ops_server/lib/src/ops_anchoring.dart` keeps deliberately off the
/// scheduler. An anchor records one writer's head, so it must be published by
/// each process for itself; a purge is storage housekeeping over rows that are
/// already written, and running it from a job store is right. What the two
/// share is only that the chain is per writer -- see "Why the chain is per
/// writer" above, which is why the purge is writer-scoped too.
class TomSqlAuditSink implements TomAuditSink {
  /// Creates a sink over [datasource].
  ///
  /// [writer] names this chain — see the library comment; give each process
  /// that appends to the same table a distinct, stable value (the node name is
  /// the usual choice, never a value that changes across restarts, since the
  /// head is recovered by it).
  ///
  /// [table] names the trail table. With [createSchema] left `true` the table
  /// is created on first use, which is what a test or a single-service
  /// deployment wants; set it `false` when the schema is owned by the migration
  /// module — which is also the arrangement a restricted grant requires, since
  /// the serving user should not hold DDL rights on its own audit table.
  ///
  /// [requireWriteOnce] turns the start-up probe from a warning into a refusal.
  /// Left `false` by default: a sink that refused to start on a developer
  /// machine would push people towards not installing one at all, and an
  /// unprotected trail is still better than no trail. A deployment that has
  /// made the write-once arrangement should set it `true`, because a silently
  /// mis-granted credential is precisely the failure it exists to catch.
  TomSqlAuditSink(
    this.datasource, {
    required this.writer,
    this.table = defaultAuditTrailTable,
    this.createSchema = true,
    this.requireWriteOnce = false,
  });

  /// Creates a sink over the registered data source named [datasourceName].
  ///
  /// Throws a [TomServerException] keyed `audit.sink.unknown_datasource` when
  /// no such data source is registered — a configuration error far better
  /// caught at start-up than on the first audited action, which the fail-closed
  /// trail would turn into a failed request. The base class rather than a
  /// subtype is deliberate; [TomServerException] says why.
  factory TomSqlAuditSink.named(
    String datasourceName, {
    required String writer,
    String table = defaultAuditTrailTable,
    bool createSchema = true,
    bool requireWriteOnce = false,
  }) {
    final info = TomDataSourceInfo.getDataSourceInfo(datasourceName);
    if (info == null) {
      throw TomServerException(
        'audit.sink.unknown_datasource',
        'The audit sink refers to a data source that is not registered.',
        parameters: {'datasource': datasourceName},
      );
    }
    return TomSqlAuditSink(
      info.datasource,
      writer: writer,
      table: table,
      createSchema: createSchema,
      requireWriteOnce: requireWriteOnce,
    );
  }

  /// The data source the trail table lives in.
  final TomDataSource datasource;

  /// The name of the chain this sink appends to.
  final String writer;

  /// The trail table.
  final String table;

  /// Whether to create the table on first use.
  final bool createSchema;

  /// Whether an unprotected table is a start-up failure rather than a warning.
  final bool requireWriteOnce;

  String _headHash = tomAuditGenesisHash;
  int _entryCount = 0;
  bool _closed = false;

  /// The close under way, once [close] has been called; every later call gets
  /// this one.
  Future<void>? _closing;

  Future<void>? _opening;
  TomAuditWriteOnceCheck? _writeOnceCheck;

  /// Serialises writes.
  ///
  /// Each entry's hash depends on the previous entry's, so two concurrent
  /// writes would race for the head and produce a chain that fails its own
  /// verification. The database would catch the fork — that is what the unique
  /// key on `(writer, previous_hash)` is for — but catching it means one of the
  /// two writes *fails*, and the trail is fail-closed, so the audited action
  /// fails with it. Serialising here means the constraint never has to fire.
  Future<void> _queue = Future<void>.value();

  /// The trail table's single column declaration — see `audit/sql_audit_sql.dart`.
  late final TomFrameworkTable _trail = auditTrailTable(table);

  /// The columns an insert names, keyed so the value cannot drift out of
  /// position when a column is added. `seq` is absent because the database
  /// assigns it.
  static const Map<String, String> _insertColumns = {
    'writer': ':writer',
    'entry_index': ':entryIndex',
    'entry_id': ':entryId',
    'recorded_at': ':recordedAt',
    'actor': ':actor',
    'action': ':action',
    'target': ':target',
    'target_key': ':targetKey',
    'outcome': ':outcome',
    'request_id': ':requestId',
    'previous_hash': ':previousHash',
    'hash': ':hash',
    'record': ':record',
  };

  /// The columns a read projects — exactly the ones [TomAuditTrailRow] maps.
  /// `seq` is not among them: it orders the read but is not part of the entry.
  static const List<String> _selectColumns = [
    'entry_index',
    'previous_hash',
    'hash',
    'record',
  ];

  @override
  String get headHash => _headHash;

  @override
  int get entryCount => _entryCount;

  /// What the last [verifyWriteOnce] found, or `null` before [open].
  TomAuditWriteOnceCheck? get writeOnceCheck => _writeOnceCheck;

  /// Provisions the table, probes the deployment, and recovers the chain head.
  ///
  /// Idempotent and awaited by every write, so a sink is never used unopened;
  /// exposed so a start-up sequence can pay the cost — and surface a
  /// misconfiguration — before serving traffic rather than on the first audited
  /// action.
  ///
  /// A failed open clears the memo so the next write retries: a database blip
  /// during start-up must not wedge the trail for the life of the process.
  Future<void> open() {
    final pending = _opening;
    if (pending != null) return pending;
    return _opening = _open().catchError((Object error, StackTrace stack) {
      _opening = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<void> _open() async {
    if (createSchema) {
      await _trail.create(datasource);
    }
    final check = await verifyWriteOnce();
    _writeOnceCheck = check;
    if (!check.updatesBlocked) {
      if (requireWriteOnce) {
        throw TomAuditException(
          'audit.sql.not_write_once',
          'The audit table can be rewritten in place, and this sink was asked '
              'to require otherwise.',
          parameters: {
            'table': table,
            'datasource': '$datasource',
            'found': check.summary,
          },
        );
      }
      // Warned, not tolerated silently: a trail whose rows can be edited is a
      // materially weaker artefact than the file sink's, and an operator who
      // never sees that stated will assume otherwise.
      tomLog.warn(
        'Audit trail is not write-once — ${check.summary}. See the write-once '
        'story in the audit documentation.',
      );
    }
    final head = await _recoverHead();
    _headHash = head.hash;
    _entryCount = head.entryCount;
  }

  /// Reads the last chain hash and position for [writer] from the table.
  ///
  /// A restart that began a fresh chain would present every pre-restart entry
  /// as unverifiable, which is indistinguishable from tampering — so the head
  /// is recovered rather than reset. Both values come from the *same* row, in
  /// one statement: read separately they could straddle a concurrent insert and
  /// yield a count that belongs to a different head.
  Future<({String hash, int entryCount})> _recoverHead() async {
    final rows = await datasource.executeQuery<TomAuditHeadRow>(
      'SELECT ${_trail.columnsOf(const ['hash', 'entry_index'])} FROM $table '
      'WHERE writer = :writer ORDER BY seq DESC LIMIT 1',
      {'writer': writer},
    );
    return rows.isEmpty
        ? (hash: tomAuditGenesisHash, entryCount: 0)
        : (hash: rows.first.hash, entryCount: rows.first.entryIndex + 1);
  }

  /// `async` so that the guard below fails the *future* rather than the call —
  /// see the note on the file sink's [TomFileAuditSink.write], which carries
  /// the same marking for the same reason.
  @override
  Future<TomAuditEntry> write(TomAuditRecord record) async {
    if (_closed) throw _closedException();
    final result = _queue.then((_) => _writeSerialised(record));
    // Keep the queue alive on failure: one failed write must not wedge the
    // sink, and the error is delivered to the caller through `result`.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  TomAuditException _closedException() => TomAuditException(
    'audit.sink.closed',
    'Audit sink for $table is closed and cannot accept records.',
  );

  /// Inserts one queued record. Never refuses: [write] turns records away at
  /// enqueue time once [close] has been called, and [close] waits for every
  /// record enqueued before it — so a record that reaches this body is one the
  /// sink has promised to store.
  Future<TomAuditEntry> _writeSerialised(TomAuditRecord record) async {
    await open();
    final entry = TomAuditEntry.chain(record, _headHash, index: _entryCount);
    try {
      await datasource.executeCommand(
        _trail.insertRow(datasource.sqlDialect, _insertColumns),
        _bindOf(entry),
      );
    } catch (e, stack) {
      throw TomAuditException(
        'audit.sink.write_failed',
        'Could not write the audit record to $table: $e',
        parameters: {'table': table, 'writer': writer, 'record': record.id},
        rootException: e,
        stack: stack,
      );
    }
    _headHash = entry.hash;
    _entryCount++;
    return entry;
  }

  /// Reads every retained entry of this writer's chain, oldest first.
  ///
  /// Asynchronous — it is a query — and **not** a [TomAuditSink] member:
  /// read-back is per implementation by design, for the reasons set out on
  /// that interface. Note what this reads: *every* row of the chain, so on a
  /// large trail prefer [purgeBefore]-bounded windows or a direct query to
  /// calling it on a routine schedule.
  Future<List<TomAuditEntry>> readAll() async {
    await open();
    final rows = await datasource.executeQuery<TomAuditTrailRow>(
      'SELECT ${_trail.columnsOf(_selectColumns)} FROM $table '
      'WHERE writer = :writer ORDER BY seq',
      {'writer': writer},
    );
    return rows.map(_entryOf).toList(growable: false);
  }

  /// Answers [query] from this writer's chain, without reading the rest of it.
  ///
  /// The counterpart of `filterAuditEntries` for a trail that is in a table
  /// rather than in memory, and the reason the two are separate calls rather
  /// than one: here the filter is pushed into the database, where the indexes
  /// on `(target, action)`, `(actor)` and `(writer, recorded_at)` are — the
  /// indexes this table has carried since it was declared. Reading every row
  /// back and filtering in Dart would answer the same question and is what
  /// [readAll] is for; on a trail of ten million rows it is not a query.
  ///
  /// ## The projection narrows, the record decides
  ///
  /// The columns the `WHERE` clause tests are the **lossy** ones: they are
  /// truncated to fit, so they can say *maybe* and never *yes*. Two rules
  /// follow, and both are structural here rather than advisory:
  ///
  ///  * every search term is cut to its column's width by [_fit] before it is
  ///    bound, the same call the insert makes. Comparing a full term against a
  ///    column the writer shortened would match nothing and report it as "no
  ///    such entry" — a false negative, which in an audit query is the failure
  ///    that matters;
  ///  * every row that comes back is decoded and re-judged by
  ///    [TomAuditQuery.matches] against the record itself. The cut above admits
  ///    rows that merely share a prefix, and those are dropped here and counted
  ///    in [TomAuditQueryResult.rejectedByProjection] rather than returned.
  ///
  /// So the answer never contains a row the index merely thought looked right,
  /// and never omits one it stored short.
  ///
  /// Scoped to [writer], like [readAll] and both purges: a sink is one chain's
  /// handle on the table. A deployment whose trail carries several writers asks
  /// each of them, which is also how it keeps the entry indexes in the answer
  /// meaningful — they are positions within a chain, and there is no order
  /// across two.
  ///
  /// Paging is by window, not by offset: narrow [TomAuditQuery.to] to the
  /// oldest instant already seen and ask again. An offset would have to be
  /// counted over the projection's matches rather than the record's, which is
  /// the one number this method deliberately does not let a caller act on.
  Future<TomAuditQueryResult> query(TomAuditQuery query) async {
    await open();
    final conditions = <String>['writer = :writer'];
    final parameters = <String, dynamic>{'writer': writer};

    void narrow(String column, String parameter, String? value) {
      if (value == null) return;
      conditions.add('$column = :$parameter');
      parameters[parameter] = _fit(value, column);
    }

    narrow('actor', 'actor', query.actor);
    narrow('target', 'target', query.target);
    narrow('target_key', 'targetKey', query.targetKey);
    narrow('request_id', 'requestId', query.requestId);
    // Enumerated, so the stored text is the name in full and no cut applies.
    narrow('action', 'action', query.action?.name);
    narrow('outcome', 'outcome', query.outcome?.name);

    if (query.from != null) {
      conditions.add('recorded_at >= :from');
      parameters['from'] = sqlInstant(query.from!);
    }
    if (query.to != null) {
      conditions.add('recorded_at < :to');
      parameters['to'] = sqlInstant(query.to!);
    }

    // One row beyond the limit, which is how the result can say whether the
    // trail held more without counting what it did not read.
    final rows = await datasource.executeQuery<TomAuditTrailRow>(
      'SELECT ${_trail.columnsOf(_selectColumns)} FROM $table '
      'WHERE ${conditions.join(' AND ')} '
      'ORDER BY seq ${query.newestFirst ? 'DESC' : 'ASC'} '
      'LIMIT ${query.limit + 1}',
      parameters,
    );

    final hasMore = rows.length > query.limit;
    final examined = hasMore ? query.limit : rows.length;
    final entries = <TomAuditEntry>[];
    for (final row in rows.take(examined)) {
      // Decoded once. The record is the authority for the filter and is also
      // what the entry carries, so decoding it twice would cost the JSON parse
      // of every examined row for nothing.
      final entry = _entryOf(row);
      if (query.matches(entry.record)) entries.add(entry);
    }

    return TomAuditQueryResult(
      entries: List.unmodifiable(entries),
      hasMore: hasMore,
      examined: examined,
      rejectedByProjection: examined - entries.length,
    );
  }

  /// Verifies the retained entries, starting from the oldest retained link.
  ///
  /// Retention may have removed the head of the chain, so verification starts
  /// from what survives — the point is to detect edits within the retained
  /// window, not to complain about a deletion the policy asked for.
  ///
  /// Asynchronous, like [readAll] whose whole result it consumes, and not on
  /// [TomAuditSink] either.
  Future<TomAuditChainVerification> verify() async {
    final entries = await readAll();
    return verifyAuditChain(
      entries,
      startHash: entries.isEmpty
          ? tomAuditGenesisHash
          : entries.first.previousHash,
    );
  }

  /// Deletes every entry of this writer's chain recorded before [before],
  /// returning how many rows went.
  ///
  /// Retention on a table is expressed in **rows**, where the file sink
  /// expresses it in files — but the rule is the same one: delete a contiguous
  /// **prefix**, never an interior row. A hole in the middle of a chain is
  /// indistinguishable from tampering, so a retention pass that could make one
  /// would destroy the property the trail exists to have.
  ///
  /// That is why the cutoff is resolved to a *sequence* boundary before
  /// anything is deleted: `DELETE ... WHERE recorded_at < :before` would look
  /// equivalent and is not. Timestamps come from the record, sequence numbers
  /// come from the insert, and a clock adjustment — or simply two nodes a few
  /// milliseconds apart — is enough to leave an older-stamped row sitting after
  /// a newer-stamped one. Deleting by timestamp would then punch a hole.
  Future<int> purgeBefore(DateTime before) async {
    await open();
    final boundary = await _firstSeqAtOrAfter(before);
    final removed = boundary == null
        // Nothing at or after the cutoff, so every retained row is older than
        // it: the whole chain is the prefix.
        ? await datasource.executeCommand(
            'DELETE FROM $table WHERE writer = :writer',
            {'writer': writer},
          )
        : await datasource.executeCommand(
            'DELETE FROM $table WHERE writer = :writer AND seq < :boundary',
            {'writer': writer, 'boundary': boundary},
          );
    return removed.toInt();
  }

  /// Keeps the newest [maxEntries] entries of this writer's chain, deleting the
  /// prefix in front of them, and returns how many rows went.
  Future<int> purgeToMaxEntries(int maxEntries) async {
    if (maxEntries < 0) {
      throw TomAuditException(
        'audit.retention.negative_limit',
        'An audit retention limit cannot be negative.',
        parameters: {'table': table, 'maxEntries': maxEntries},
      );
    }
    await open();
    // `LIMIT`/`OFFSET` are interpolated rather than bound — the driver binds
    // values, not clause arguments — which is safe here because the value has
    // been checked to be a non-negative `int`.
    final rows = await datasource.executeQuery<TomAuditSeqRow>(
      'SELECT seq FROM $table WHERE writer = :writer ORDER BY seq DESC '
      'LIMIT 1 OFFSET $maxEntries',
      {'writer': writer},
    );
    if (rows.isEmpty) return 0;
    final boundary = rows.first.seq;
    final removed = await datasource.executeCommand(
      'DELETE FROM $table WHERE writer = :writer AND seq <= :boundary',
      {'writer': writer, 'boundary': boundary},
    );
    return removed.toInt();
  }

  /// Observes what the connected user and the table's triggers actually permit.
  ///
  /// Called by [open]; exposed so a health check or an operator tool can ask
  /// the same question without opening a second sink.
  Future<TomAuditWriteOnceCheck> verifyWriteOnce() async {
    final grantsUpdate = await _permits(
      'UPDATE $table SET writer = writer WHERE 1 = 0',
    );
    final grantsDelete = await _permits('DELETE FROM $table WHERE 1 = 0');
    final triggers = await _guardTriggers();
    return TomAuditWriteOnceCheck(
      table: table,
      grantsUpdate: grantsUpdate,
      grantsDelete: grantsDelete,
      updateGuardTrigger: triggers['UPDATE'],
      deleteGuardTrigger: triggers['DELETE'],
    );
  }

  /// Whether [statement] is permitted, established by running it.
  ///
  /// The statement matches no rows, so running it changes nothing; what it
  /// exercises is the permission check, which MariaDB performs before it
  /// discovers that the `WHERE` selects nothing. The exception is not being
  /// swallowed here — it **is** the answer.
  Future<bool> _permits(String statement) async {
    try {
      await datasource.executeCommand(statement);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The `BEFORE`-timed guard triggers on the table, keyed by the event they
  /// intercept.
  Future<Map<String, String>> _guardTriggers() async {
    final rows = await datasource.executeQuery<TomAuditTriggerRow>(
      'SELECT TRIGGER_NAME AS trigger_name, '
      'EVENT_MANIPULATION AS event_manipulation '
      'FROM information_schema.TRIGGERS '
      'WHERE EVENT_OBJECT_SCHEMA = ${datasource.sqlDialect.currentSchema} '
      'AND EVENT_OBJECT_TABLE = :table AND ACTION_TIMING = :timing',
      {'table': table, 'timing': 'BEFORE'},
    );
    return {for (final row in rows) row.eventManipulation: row.triggerName};
  }

  Future<int?> _firstSeqAtOrAfter(DateTime instant) async {
    final rows = await datasource.executeQuery<TomAuditSeqRow>(
      'SELECT MIN(seq) AS seq FROM $table '
      'WHERE writer = :writer AND recorded_at >= :instant',
      {'writer': writer, 'instant': sqlInstant(instant)},
    );
    return rows.isEmpty ? null : rows.first.seq;
  }

  Map<String, dynamic> _bindOf(TomAuditEntry entry) {
    final record = entry.record;
    return {
      'writer': writer,
      'entryIndex': entry.index,
      'entryId': _fit(record.id, 'entry_id'),
      'recordedAt': sqlInstant(record.timestamp),
      'actor': _fit(record.actor.username, 'actor'),
      'action': record.action.name,
      'target': _fit(record.target, 'target'),
      'targetKey': _fit(record.targetKey, 'target_key'),
      'outcome': record.outcome.name,
      'requestId': _fit(record.requestId, 'request_id'),
      'previousHash': entry.previousHash,
      'hash': entry.hash,
      // Exactly the text that was hashed, so a row verifies against its own
      // hash without the reader having to reproduce the encoding.
      'record': jsonEncode(record.toJson()),
    };
  }

  TomAuditEntry _entryOf(TomAuditTrailRow row) {
    try {
      return TomAuditEntry(
        record: TomAuditRecord.fromJson(
          (jsonDecode(row.record) as Map).cast<String, Object?>(),
        ),
        previousHash: row.previousHash,
        hash: row.hash,
        index: row.entryIndex,
      );
    } catch (e, stack) {
      // A row whose record text will not parse is itself a finding, exactly as
      // a malformed line is for the file sink. Returning a placeholder would
      // hide the damage the chain exists to reveal.
      throw TomAuditException(
        'audit.sql.malformed_record',
        'An audit row does not contain a readable record: $e',
        parameters: {'table': table, 'writer': writer, 'hash': row.hash},
        rootException: e,
        stack: stack,
      );
    }
  }

  /// Truncates [value] to what [column] can hold.
  ///
  /// The projection columns are an index, not the record: the authoritative
  /// text lives in `record` and is never truncated. Trimming here rather than
  /// letting the database reject the row keeps an over-long username from
  /// failing an audited action — the trail is fail-closed, so a rejected insert
  /// would take the action down with it.
  ///
  /// The width comes from the column's own declaration, and [query] narrows its
  /// search terms through the same call. That is what makes a search over a
  /// truncated column find the row it shortened: both ends cut at the same
  /// place because both ask the same declaration where it is.
  String? _fit(String? value, String column) =>
      auditProjectionPrefix(value, _trail.column(column)?.maxCharacters);

  /// Waits for the queued records to be inserted, then closes.
  ///
  /// Every [write] that has *returned* has already committed its `INSERT`;
  /// this waits for the ones still queued, so a shutdown that awaits it has
  /// every record written before the close in the table. A record written
  /// after the call is refused with `audit.sink.closed` — see
  /// [TomAuditSink.close] for why refusing beats writing it anyway or dropping
  /// it silently. Idempotent: every call is handed the same close.
  ///
  /// The drain awaits `_queue` rather than the individual write futures
  /// because `_queue` is the tail of the chain: awaiting it means every record
  /// enqueued before this call has run. It swallows nothing — `_queue` already
  /// absorbs write errors so one failure cannot wedge the sink, and each error
  /// was delivered to its own caller through the future [write] returned.
  ///
  /// The [datasource] is deliberately **not** closed — it is registered
  /// process-wide and is not this sink's to dispose of.
  @override
  Future<void> close() => _closing ??= _drain();

  Future<void> _drain() async {
    // Closed to new records first, then waited on: that order gives the drain
    // a fixed point to reach while a caller keeps writing.
    _closed = true;
    await _queue;
  }

  @override
  String toString() => 'TomSqlAuditSink($table, writer: $writer)';
}

/// One row of the audit trail table, as the result mapper materialises it.
///
/// Reflected and `@TomDbTable`-annotated because the data source's row mapper
/// requires both; the annotation values are placeholders because the real table
/// name is a constructor argument of [TomSqlAuditSink]. Same arrangement, and
/// same reason, as `TomJobRunRow` in the scheduling module.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomAuditTrailRow {
  /// The entry's position in its writer's chain, counted from genesis.
  @TomDbColumn(columnName: "entry_index")
  int entryIndex = 0;

  /// The hash of the preceding entry.
  @TomDbColumn(columnName: "previous_hash")
  String previousHash = "";

  /// This entry's hash.
  @TomDbColumn(columnName: "hash")
  String hash = "";

  /// The canonical JSON of the audited record — the authoritative content.
  @TomDbColumn(columnName: "record")
  String record = "";
}

/// The single column [TomSqlAuditSink] projects when recovering a chain head.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomAuditHeadRow {
  /// The newest entry's hash.
  @TomDbColumn(columnName: "hash")
  String hash = "";

  /// The newest entry's position, from which the chain's length follows.
  @TomDbColumn(columnName: "entry_index")
  int entryIndex = 0;
}

/// A projected sequence number — nullable, because the aggregate that resolves
/// a retention boundary yields `NULL` when no row matches.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomAuditSeqRow {
  /// The sequence number, or `null` when the aggregate matched nothing.
  @TomDbColumn(columnName: "seq")
  int? seq;
}

/// One `information_schema.TRIGGERS` row, as the write-once probe reads it.
@tomReflector
@TomDbTable(
  datasource: "irrelevant",
  table: "irrelevant",
  primaryKeyFields: ["irrelevant"],
)
class TomAuditTriggerRow {
  /// The trigger's name.
  @TomDbColumn(columnName: "trigger_name")
  String triggerName = "";

  /// The statement it intercepts — `INSERT`, `UPDATE` or `DELETE`.
  @TomDbColumn(columnName: "event_manipulation")
  String eventManipulation = "";
}
