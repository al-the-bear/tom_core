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
import '../datasources/sql_instant.dart';
import '../little_things/server_exception.dart';
import '../object_persistence/persistence_annotations.dart';
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
  /// Throws a [TomServerException] when no such data source is registered — a
  /// configuration error far better caught at start-up than on the first
  /// audited action, which the fail-closed trail would turn into a failed
  /// request.
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

  /// The columns an insert names, in bind order.
  static const String _insertColumns =
      'writer, entry_index, entry_id, recorded_at, actor, action, target, '
      'target_key, outcome, request_id, previous_hash, hash, record';

  /// The columns a read projects. `seq` is not among them: it orders the read
  /// but is not part of the entry.
  static const String _selectColumns =
      'entry_index, previous_hash, hash, record';

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
      await datasource.executeCommand(auditTrailTableDdl(table));
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
      'SELECT hash, entry_index FROM $table WHERE writer = :writer '
      'ORDER BY seq DESC LIMIT 1',
      {'writer': writer},
    );
    return rows.isEmpty
        ? (hash: tomAuditGenesisHash, entryCount: 0)
        : (hash: rows.first.hash, entryCount: rows.first.entryIndex + 1);
  }

  @override
  Future<TomAuditEntry> write(TomAuditRecord record) {
    if (_closed) {
      throw TomAuditException(
        'audit.sink.closed',
        'Audit sink for $table is closed and cannot accept records.',
      );
    }
    final result = _queue.then((_) => _writeSerialised(record));
    // Keep the queue alive on failure: one failed write must not wedge the
    // sink, and the error is delivered to the caller through `result`.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<TomAuditEntry> _writeSerialised(TomAuditRecord record) async {
    await open();
    final entry = TomAuditEntry.chain(record, _headHash, index: _entryCount);
    try {
      await datasource.executeCommand(
        'INSERT INTO $table ($_insertColumns) VALUES '
        '(:writer, :entryIndex, :entryId, :recordedAt, :actor, :action, '
        ':target, :targetKey, :outcome, :requestId, :previousHash, :hash, '
        ':record)',
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
  Future<List<TomAuditEntry>> readAll() async {
    await open();
    final rows = await datasource.executeQuery<TomAuditTrailRow>(
      'SELECT $_selectColumns FROM $table WHERE writer = :writer ORDER BY seq',
      {'writer': writer},
    );
    return rows.map(_entryOf).toList(growable: false);
  }

  /// Verifies the retained entries, starting from the oldest retained link.
  ///
  /// Retention may have removed the head of the chain, so verification starts
  /// from what survives — the point is to detect edits within the retained
  /// window, not to complain about a deletion the policy asked for.
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
      'WHERE EVENT_OBJECT_SCHEMA = DATABASE() '
      'AND EVENT_OBJECT_TABLE = :table AND ACTION_TIMING = :timing',
      {'table': table, 'timing': 'BEFORE'},
    );
    return {
      for (final row in rows) row.eventManipulation: row.triggerName,
    };
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
      'entryId': _fit(record.id, 191),
      'recordedAt': sqlInstant(record.timestamp),
      'actor': _fit(record.actor.username, 160),
      'action': record.action.name,
      'target': _fit(record.target, 160),
      'targetKey': _fitOrNull(record.targetKey, 191),
      'outcome': record.outcome.name,
      'requestId': _fitOrNull(record.requestId, 191),
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

  /// Truncates [value] to [limit] characters.
  ///
  /// The projection columns are an index, not the record: the authoritative
  /// text lives in `record` and is never truncated. Trimming here rather than
  /// letting the database reject the row keeps an over-long username from
  /// failing an audited action — the trail is fail-closed, so a rejected insert
  /// would take the action down with it.
  static String _fit(String value, int limit) =>
      value.length <= limit ? value : value.substring(0, limit);

  static String? _fitOrNull(String? value, int limit) =>
      value == null ? null : _fit(value, limit);

  /// Closes the sink.
  ///
  /// Nothing can be lost: every [write] awaits its `INSERT` before it returns,
  /// so there is no buffered entry to drop. The [datasource] is deliberately
  /// **not** closed — it is registered process-wide and is not this sink's to
  /// dispose of.
  @override
  void close() {
    _closed = true;
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
  primaryKeyField: "irrelevant",
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
  primaryKeyField: "irrelevant",
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
  primaryKeyField: "irrelevant",
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
  primaryKeyField: "irrelevant",
)
class TomAuditTriggerRow {
  /// The trigger's name.
  @TomDbColumn(columnName: "trigger_name")
  String triggerName = "";

  /// The statement it intercepts — `INSERT`, `UPDATE` or `DELETE`.
  @TomDbColumn(columnName: "event_manipulation")
  String eventManipulation = "";
}
