/// The register of stored exports, and what it makes possible: a per-owner
/// quota and a scheduled purge.
///
/// [TomExportStore] holds bytes under keys and deliberately cannot list them —
/// over an object store a listing is a paginated call, over a blob table a
/// scan, and neither says *whose* an export is or how old it is. The register
/// is the record that says so: one [TomExportRecord] per stored export, written
/// by [TomExportService.storeAs] beside the bytes. Retention is then a query
/// over it, and a quota a sum.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'export_store.dart';
import 'tabular_result.dart';

/// What the register knows about one stored export.
class TomExportRecord {
  /// A record of the export stored under [key] for [owner].
  TomExportRecord({
    required this.key,
    required this.owner,
    required this.mediaType,
    required this.byteCount,
    required DateTime storedAt,
    this.title,
  }) : storedAt = storedAt.toUtc();

  /// The export's storage key.
  final String key;

  /// Who the export counts against — a user, a tenant, a report job; `''` for
  /// an export that belongs to no one, which no quota counts.
  final String owner;

  /// The export's media type.
  final String mediaType;

  /// Its size.
  final int byteCount;

  /// When it was stored, in UTC.
  final DateTime storedAt;

  /// The report's title, when the export was stored with one.
  final String? title;

  @override
  String toString() => 'TomExportRecord($key, $owner, $byteCount bytes)';
}

/// How much an owner holds: [count] exports of [bytes] in total.
class TomExportUsage {
  /// Usage of [count] exports totalling [bytes].
  const TomExportUsage({required this.count, required this.bytes});

  /// How many exports.
  final int count;

  /// Their total size.
  final int bytes;

  @override
  String toString() => 'TomExportUsage($count exports, $bytes bytes)';
}

/// The record of stored exports: who stored what, how large, and when.
abstract class TomExportRegister {
  /// Creates a register.
  const TomExportRegister();

  /// Records [record], replacing any record under its key.
  Future<void> record(TomExportRecord record);

  /// The record under [key], or `null`.
  Future<TomExportRecord?> find(String key);

  /// [owner]'s exports, newest first.
  Future<List<TomExportRecord>> ownedBy(String owner);

  /// What [owner] holds.
  Future<TomExportUsage> usageOf(String owner);

  /// Up to [limit] exports stored before [before], oldest first.
  Future<List<TomExportRecord>> storedBefore(
    DateTime before, {
    int limit = 500,
  });

  /// Removes the record under [key]; answers whether there was one.
  Future<bool> remove(String key);
}

/// A [TomExportRegister] in memory: right for tests and a single process whose
/// store is in memory too, wrong for anything that outlives the process.
class TomMemoryExportRegister extends TomExportRegister {
  /// Creates an empty register.
  TomMemoryExportRegister();

  final Map<String, TomExportRecord> _records = {};

  @override
  Future<void> record(TomExportRecord record) async =>
      _records[record.key] = record;

  @override
  Future<TomExportRecord?> find(String key) async => _records[key];

  @override
  Future<List<TomExportRecord>> ownedBy(String owner) async =>
      _records.values.where((r) => r.owner == owner).toList()
        ..sort((a, b) => b.storedAt.compareTo(a.storedAt));

  @override
  Future<TomExportUsage> usageOf(String owner) async {
    var count = 0;
    var bytes = 0;
    for (final record in _records.values) {
      if (record.owner != owner) continue;
      count++;
      bytes += record.byteCount;
    }
    return TomExportUsage(count: count, bytes: bytes);
  }

  @override
  Future<List<TomExportRecord>> storedBefore(
    DateTime before, {
    int limit = 500,
  }) async =>
      (_records.values.where((r) => r.storedAt.isBefore(before)).toList()
            ..sort((a, b) => a.storedAt.compareTo(b.storedAt)))
          .take(limit)
          .toList();

  @override
  Future<bool> remove(String key) async => _records.remove(key) != null;
}

/// How much one owner may hold: at most [maxCount] exports, at most [maxBytes]
/// in total; `null` leaves that dimension unbounded.
///
/// Checked by [TomExportService.storeAs] for an export stored with an owner.
/// The count and the bytes already held are checked before rendering, so a
/// full owner costs no render; the size of the new export is only known once
/// it is stored, so a store that takes the owner past [maxBytes] is undone —
/// the export deleted, its record removed — and refused.
class TomExportQuota {
  /// A quota of [maxCount] exports and [maxBytes] bytes per owner.
  const TomExportQuota({this.maxCount, this.maxBytes});

  /// The most exports one owner may hold.
  final int? maxCount;

  /// The most bytes one owner's exports may total.
  final int? maxBytes;

  /// Throws unless [owner], holding [usage], may hold one more export.
  ///
  /// Before the store, [addedBytes] is `0` and the bytes already held are
  /// compared with [maxBytes]; after it, [addedBytes] is the stored size and the
  /// total must fit. [countingNew] is `false` for a store that replaces an
  /// export the owner already holds, which adds no export to the count.
  ///
  /// Keyed `export.quota.count_exceeded` or `export.quota.bytes_exceeded`.
  void check(
    String owner,
    TomExportUsage usage, {
    int addedBytes = 0,
    bool countingNew = true,
  }) {
    final maxCount = this.maxCount;
    if (maxCount != null && countingNew && usage.count >= maxCount) {
      throw TomExportException(
        'export.quota.count_exceeded',
        'The export cannot be stored: its owner already holds the most '
            'exports allowed. Delete one first.',
        parameters: {'owner': owner, 'count': usage.count, 'limit': maxCount},
      );
    }
    final maxBytes = this.maxBytes;
    final total = usage.bytes + addedBytes;
    if (maxBytes != null &&
        (total > maxBytes || (addedBytes == 0 && total >= maxBytes))) {
      throw TomExportException(
        'export.quota.bytes_exceeded',
        'The export cannot be stored: its owner\'s exports would exceed the '
            'space allowed. Delete some first.',
        parameters: {'owner': owner, 'bytes': total, 'limit': maxBytes},
      );
    }
  }
}

/// Deletes stored exports older than [maxAge] — the bytes from [store], the
/// records from [register].
///
/// Run it by hand ([purge]) or on a scheduler ([jobDefinition]); either way it
/// works from the register, so it reaches every export the service stored,
/// whatever the store's backend.
class TomExportRetention {
  /// Keeps exports in [store] for [maxAge], working through [register] in
  /// batches of [batchSize].
  TomExportRetention({
    required this.store,
    required this.register,
    required this.maxAge,
    this.batchSize = 500,
  }) {
    if (maxAge <= Duration.zero || batchSize < 1) {
      // throws-outside-family: programmer error — a retention that deletes
      // everything at once, or never makes progress.
      throw ArgumentError(
        'maxAge must be positive and batchSize at least 1; got $maxAge and '
        '$batchSize.',
      );
    }
  }

  /// Where the exports are stored.
  final TomExportStore store;

  /// The record of what was stored when.
  final TomExportRegister register;

  /// How long an export is kept.
  final Duration maxAge;

  /// How many exports one batch deletes.
  final int batchSize;

  /// Deletes every export stored before [now] (default: the current time)
  /// minus [maxAge], and answers how many went.
  ///
  /// The bytes go before the record, so an interrupted purge leaves a record
  /// whose bytes are gone — which the next purge deletes again, harmlessly —
  /// and never bytes nobody can find.
  Future<int> purge({DateTime? now}) async {
    final cutoff = (now ?? DateTime.now()).toUtc().subtract(maxAge);
    var purged = 0;
    while (true) {
      final batch = await register.storedBefore(cutoff, limit: batchSize);
      if (batch.isEmpty) return purged;
      for (final record in batch) {
        await store.delete(record.key);
        await register.remove(record.key);
        purged++;
      }
    }
  }

  /// A job running [purge] on [schedule] (default: hourly), for a
  /// [TomScheduler] to run.
  ///
  /// Its body holds this retention, so the scheduler must run it in its own
  /// isolate ([TomInlineJobDispatcher]) — the same requirement the message
  /// outbox's delivery has.
  TomJobDefinition jobDefinition({
    String name = 'tom.export.purge',
    TomSchedule? schedule,
  }) => TomJobDefinition(
    name: name,
    schedule: schedule ?? TomIntervalSchedule(const Duration(hours: 1)),
    body: (_) => _TomExportPurgeCommand(this),
    missedWindowPolicy: TomMissedWindowPolicy.runOnce,
  );
}

/// One run of [TomExportRetention.purge].
class _TomExportPurgeCommand extends TomCommand {
  _TomExportPurgeCommand(this._retention);

  final TomExportRetention _retention;

  @override
  Future<Object?> execute() => _retention.purge();
}
