/// Read replicas: which statements a replica of a SQL data source may serve.
///
/// A data source configured with `replicas` keeps a pool per replica beside its
/// own, and routes a statement to a replica only when every one of these holds
/// — otherwise it runs on the primary, as it would without replicas:
///
/// 1. **Read-only work.** The statement runs in a read-only context: a
///    read-only transaction, a `GET` or `HEAD` request
///    ([TomReplicaRouting.routeSafeRequests]), or a
///    [TomReplicaRouting.readOnly] block. Everything inside a write transaction
///    runs on the primary.
/// 2. **A repository read.** It is issued by a repository's read method —
///    `findById`, `findAll`, `findByQuerySentence`, `count` and the others — for
///    an entity not marked [TomPrimaryReads]. The framework's own stores (the
///    audit sink, the scheduler, the lease lock, the idempotency, saga and
///    inbox stores) talk to the data source directly and read the primary:
///    they act on what they read, and a replica's lag would make them act on
///    the past.
/// 3. **A read.** The statement is a `SELECT` (or `WITH … SELECT`) that locks
///    nothing and calls no session function — [TomReplicaRouting.isReadStatement],
///    which answers `false` when in doubt.
/// 4. **No recent write.** The principal (per tenant) has not written to the
///    data source within its `replicaStickinessMs` — read-your-writes: a user
///    who has just saved something reads it back from where it was written.
///
/// [TomReplicaRouting.primary] sends every read of a block to the primary
/// whatever the context.
library;

import 'dart:async';

import '../object_persistence/annotation_analyzer.dart';
import '../transactions/transaction_manager.dart';

/// Marks an entity whose reads are always served by the primary, never by a
/// read replica — data a decision is taken on the moment it changes: grants,
/// delegations, second-factor enrolments.
class TomPrimaryReads {
  /// Pins the entity's reads to the primary.
  const TomPrimaryReads();
}

/// The routing rules of read replicas — see the library documentation.
abstract final class TomReplicaRouting {
  /// Whether a `GET` or `HEAD` request is read-only work, so its repository
  /// reads may be served by a replica. On by default; a deployment whose safe
  /// requests write turns it off.
  static bool routeSafeRequests = true;

  static final Object _readOnlyKey = Object();
  static final Object _primaryKey = Object();
  static final Object _repositoryReadKey = Object();
  static final Map<Type, bool> _pinned = {};

  /// Runs [body] as read-only work: its repository reads may be served by a
  /// replica.
  static Future<R> readOnly<R>(Future<R> Function() body) =>
      runZoned(body, zoneValues: {_readOnlyKey: true});

  /// Runs [body] with every read on the primary.
  static Future<R> primary<R>(Future<R> Function() body) =>
      runZoned(body, zoneValues: {_primaryKey: true});

  /// Runs [body], a read of [entity] by its repository, marked as one a
  /// replica may serve — unless [entity] is [TomPrimaryReads].
  static Future<R> repositoryRead<R>(Type entity, Future<R> Function() body) =>
      readsFromPrimary(entity)
      ? body()
      : runZoned(body, zoneValues: {_repositoryReadKey: true});

  /// Whether the current zone is read-only work: a [readOnly] block, or a
  /// running read-only transaction.
  static bool get isReadOnlyContext {
    final transaction = TomTransactionManager.getCurrentTransaction();
    if (transaction != null && transaction.isRunning) {
      return transaction.isReadOnly;
    }
    return Zone.current[_readOnlyKey] == true;
  }

  /// Whether the current zone sends every read to the primary.
  static bool get isPrimaryForced => Zone.current[_primaryKey] == true;

  /// Whether the current zone is a repository read of an entity a replica may
  /// serve.
  static bool get isRepositoryRead => Zone.current[_repositoryReadKey] == true;

  /// Whether [entity] is [TomPrimaryReads].
  static bool readsFromPrimary(Type entity) => _pinned[entity] ??=
      TomAnnotationAnalyzer.findMirror(
        entity,
      )?.metadata.any((m) => m is TomPrimaryReads) ??
      false;

  static final RegExp _comments = RegExp(r'--[^\n]*|/\*[\s\S]*?\*/');
  static final RegExp _writes = RegExp(
    r'\b(INSERT|UPDATE|DELETE|MERGE|REPLACE|UPSERT|CREATE|ALTER|DROP|TRUNCATE|'
    r'GRANT|REVOKE|CALL|LOCK|INTO|NEXTVAL|SETVAL|GET_LOCK|RELEASE_LOCK|'
    r'IS_FREE_LOCK|LAST_INSERT_ID|PG_ADVISORY_LOCK|PG_TRY_ADVISORY_LOCK|'
    r'PG_ADVISORY_XACT_LOCK|PG_ADVISORY_UNLOCK|SLEEP|PG_SLEEP)\b',
  );

  /// Whether [sql] only reads: it starts with `SELECT` (or `WITH`, or an
  /// opening bracket before one), and names no locking clause, no writing
  /// keyword and no session function anywhere — a `FOR UPDATE`, a `SELECT …
  /// INTO`, a `GET_LOCK` or a `nextval` all read the primary.
  ///
  /// Conservative on purpose: a word inside a string literal counts too, which
  /// sends an innocent read to the primary rather than a writing one to a
  /// replica.
  static bool isReadStatement(String sql) {
    final text = sql.replaceAll(_comments, ' ').trim().toUpperCase();
    final start = text.replaceFirst(RegExp(r'^\(+\s*'), '');
    if (!start.startsWith('SELECT') && !start.startsWith('WITH')) {
      return false;
    }
    return !_writes.hasMatch(text) &&
        !text.contains(' FOR SHARE') &&
        !text.contains(' FOR NO KEY');
  }
}
