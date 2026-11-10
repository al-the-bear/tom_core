/// Values a request computes once: the per-request memo the framework's
/// authorization lookups share.
library;

import 'dart:async';

/// A cache that lives for one request, so a lookup the request makes many times
/// — the caller's row scopes, grants and delegations — reads the database once.
///
/// The endpoint pipeline runs every request's handler inside [run], which
/// installs a fresh cache on a zone of its own: two requests never share one.
/// Outside [run] nothing is cached and [memo] computes every time.
///
/// **A write empties it.** What a request writes may change what it may see —
/// a project created with its owner grant, a share revoked — so every
/// statement that changes data clears the cache (the SQL data source calls
/// [invalidateAfter]) unless it wrote one of the framework's
/// [bookkeepingTables], and so does a rollback, whose writes vanish. A lookup after
/// a write therefore reads the database again. Across requests nothing is
/// kept, so a revocation takes effect on the caller's next request.
///
/// **The zone bounds reachability, not lifetime.** Anything [run]'s body
/// schedules without awaiting inherits the zone and reads this cache when it
/// later runs; work meant to outlive the request starts outside it.
abstract final class TomRequestCache {
  static const Object _zoneKey = #tomRequestCache;

  static Map<Object, Future<Object?>>? get _current =>
      Zone.current[_zoneKey] as Map<Object, Future<Object?>>?;

  /// Runs [body] with a fresh cache.
  static Future<T> run<T>(FutureOr<T> Function() body) => runZoned(
    () => Future.sync(body),
    zoneValues: {_zoneKey: <Object, Future<Object?>>{}},
  );

  /// Whether the current zone has a cache.
  static bool get isActive => _current != null;

  /// The value [compute] answers for [key], computed once while the cache
  /// lasts: a second lookup of [key] — concurrent or later — shares the first
  /// one's result. A lookup that fails is not kept. Without a cache, [compute]
  /// runs every time.
  ///
  /// [key] must identify everything the value depends on (`==` and
  /// `hashCode`), e.g. a record of the asking object and the principal id.
  static Future<V> memo<V>(Object key, Future<V> Function() compute) {
    final cache = _current;
    if (cache == null) return compute();
    final held = cache[key];
    if (held != null) return held.then((value) => value as V);
    final pending = compute();
    cache[key] = pending;
    unawaited(
      pending.then<void>(
        (_) {},
        onError: (Object _) => cache.removeWhere(
          (held, value) => held == key && identical(value, pending),
        ),
      ),
    );
    return pending;
  }

  /// Empties the current cache, if any.
  static void invalidate() => _current?.clear();

  /// The framework's bookkeeping tables, at their default names: the job
  /// queue and its locks, the blob store, the audit trail and its saved
  /// questions, the outbox's inbox, delivery reports and suppression list,
  /// idempotency keys, sagas, keys, the export register, the sync change
  /// log, the tenant registry, service accounts and API keys, and the rate
  /// limiter's counters. No lookup the cache keeps reads them, so a write
  /// to one leaves it as it is — an upload's blob rows would otherwise empty it
  /// in the middle of a request. `test/request_cache_test.dart` holds the set
  /// to the tables `frameworkOwnedTables` lists.
  static const Set<String> bookkeepingTables = {
    'tom_job_run',
    'tom_lease',
    'tom_scheduler_node',
    'tom_job_pause',
    'tom_job_run_archive',
    'tom_blob',
    'tom_blob_chunk',
    'tom_blob_ledger',
    'tom_blob_content',
    'tom_audit_trail',
    'tom_audit_question',
    'tom_oauth_state',
    'tom_delivery_report',
    'tom_message_suppression',
    'tom_cache_invalidation',
    'tom_scim_resource',
    'tom_message_inbox',
    'tom_idempotency_key',
    'tom_saga',
    'tom_encryption_key',
    'tom_subject_key',
    'tom_transaction_decision',
    'tom_export',
    'tom_sync_change',
    'tom_sync_sequence',
    'tom_tenant',
    'tom_service_account',
    'tom_api_key',
    'tom_rate_limit',
  };

  static final RegExp _target = RegExp(
    r'^\s*(?:INSERT(?:\s+IGNORE)?\s+INTO|REPLACE\s+INTO|MERGE\s+INTO|UPDATE|'
    r'DELETE\s+FROM|TRUNCATE(?:\s+TABLE)?)\s+([`"\w.]+)',
    caseSensitive: false,
  );

  /// Empties the current cache after [statement] changed data — unless it
  /// wrote one of the [bookkeepingTables], which no cached lookup reads.
  static void invalidateAfter(String statement) {
    final cache = _current;
    if (cache == null || cache.isEmpty) return;
    final target = _target.firstMatch(statement)?.group(1);
    if (target != null) {
      final table = target
          .replaceAll('`', '')
          .replaceAll('"', '')
          .split('.')
          .last
          .toLowerCase();
      if (bookkeepingTables.contains(table)) return;
    }
    cache.clear();
  }
}
