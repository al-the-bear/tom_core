/// A blob store that keeps one copy of each distinct content, records whose
/// every key is, and holds each owner to a quota.
///
/// [TomDeduplicatingBlobStore] is a [TomBlobStore] in front of another one —
/// the directory, S3 or database backend, called the *content store* — and a
/// [TomBlobLedger]. Callers use it like any store; underneath:
///
/// - **Deduplication.** A write streams into a staging key of the content store
///   while its SHA-256 is computed, then becomes the content for that digest or,
///   when the content is already held, is discarded. Every logical key naming
///   the same bytes shares one stored copy; a copy is a ledger write and moves
///   no bytes.
/// - **Quota.** With a [TomBlobQuota], each write and copy is charged to its
///   owner — by default the qualified id of the principal in the current zone,
///   or the owner [runAs] names — and refused when the owner would hold too
///   many blobs or too many bytes.
/// - **Reclaim.** Deleting a key removes its ledger entry; content no entry
///   names any more is deleted by [reclaim], once nothing has claimed it for
///   [reclaimGrace]. Deleting content the moment its last key goes would race a
///   concurrent write of the same bytes in another process, and the write would
///   lose; the grace is what closes that window.
///
/// Which keys no row refers to — the orphan sweep — is the persistence
/// module's question, and `TomBlobOrphanSweep` answers it over the ledger this
/// store keeps.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';
import 'package:uuid/uuid.dart';

import 'blob_ledger.dart';
import 'blob_store.dart';

/// A [TomBlobStore] storing each distinct content once, over [content], with
/// its keys, owners and contents recorded in [ledger].
class TomDeduplicatingBlobStore extends TomBlobStore {
  /// A store keeping its bytes in [content] and its record in [ledger].
  ///
  /// [contentPrefix] and [stagingPrefix] are the key prefixes the content and
  /// the in-flight writes take in [content]; they must not be used by anything
  /// else writing there. [ownerOf] names who a write counts against when no
  /// [runAs] is in effect. [clock] is the time writes and reclaims are stamped
  /// with.
  TomDeduplicatingBlobStore({
    required this.content,
    required this.ledger,
    this.quota,
    String Function()? ownerOf,
    String contentPrefix = defaultContentPrefix,
    String stagingPrefix = defaultStagingPrefix,
    this.reclaimGrace = const Duration(hours: 1),
    DateTime Function()? clock,
  }) : ownerOf = ownerOf ?? principalOwner,
       contentPrefix = TomBlobStore.validateKey(contentPrefix),
       stagingPrefix = TomBlobStore.validateKey(stagingPrefix),
       _clock = clock ?? DateTime.now {
    if (tomBlobKeyUnder(this.contentPrefix, this.stagingPrefix) ||
        tomBlobKeyUnder(this.stagingPrefix, this.contentPrefix)) {
      // throws-outside-family: programmer error — staging inside the content
      // area would make in-flight writes look like content, and the reverse.
      throw ArgumentError(
        'contentPrefix and stagingPrefix must not contain each other; got '
        '"$contentPrefix" and "$stagingPrefix".',
      );
    }
    if (reclaimGrace < Duration.zero) {
      // throws-outside-family: programmer error — a negative grace reclaims
      // content claimed in the future, which is every write in flight.
      throw ArgumentError.value(reclaimGrace, 'reclaimGrace', 'is negative');
    }
  }

  /// The prefix content is stored under in the content store by default.
  static const String defaultContentPrefix = 'tom-content';

  /// The prefix in-flight writes are staged under by default.
  static const String defaultStagingPrefix = 'tom-staging';

  /// Where the bytes are stored.
  final TomBlobStore content;

  /// The record of keys, owners and contents.
  final TomBlobLedger ledger;

  /// How much one owner may hold, or `null` for no limit.
  final TomBlobQuota? quota;

  /// Who a write counts against when no [runAs] is in effect.
  final String Function() ownerOf;

  /// The key prefix content takes in [content].
  final String contentPrefix;

  /// The key prefix in-flight writes take in [content].
  ///
  /// A write staged here is moved or deleted before it returns; a process that
  /// dies mid-write leaves its staged bytes, which nothing records and so
  /// nothing reclaims. On a content store that supports it, `deletePrefix` of
  /// this prefix while no write is in flight removes them.
  final String stagingPrefix;

  /// How long content no key names is kept before [reclaim] deletes it — longer
  /// than the longest write, since a write claims its content before it
  /// records its key.
  final Duration reclaimGrace;

  final DateTime Function() _clock;

  static const Uuid _uuid = Uuid();
  static final Object _ownerZoneKey = Object();

  /// The owner the current zone's principal is: its qualified id, or `''` when
  /// no principal is set.
  static String principalOwner() =>
      getFromCurrentZone<TomPrincipal>()?.qualifiedId ?? '';

  /// Runs [body] with every write and copy it makes charged to [owner] — for
  /// work done on someone's behalf outside a request, and for a job that owns
  /// its own files.
  static Future<T> runAs<T>(String owner, Future<T> Function() body) =>
      runZoned(body, zoneValues: {_ownerZoneKey: owner});

  /// Who the write being made now counts against.
  String currentOwner() {
    final named = Zone.current[_ownerZoneKey];
    return named is String ? named : ownerOf();
  }

  @override
  bool get supportsPrefixDelete => true;

  @override
  Future<TomStoredBlob> doPut({
    required String key,
    required Stream<List<int>> bytes,
    String mediaType = TomStoredBlob.defaultMediaType,
    String? fileName,
  }) async {
    final owner = currentOwner();
    final usage = await _usageReplacing(owner, key);
    if (usage != null) quota!.check(owner, usage);

    // Hashed here rather than taken from the content store's descriptor, so a
    // backend that records no digest still deduplicates.
    final digest = TomBlobDigest();
    final staging = '$stagingPrefix/${_uuid.v4()}';
    final staged = await content.put(
      key: staging,
      bytes: bytes.map((chunk) {
        digest.add(chunk);
        return chunk;
      }),
      mediaType: mediaType,
      fileName: fileName,
    );
    try {
      if (usage != null) {
        quota!.check(owner, usage, addedBytes: staged.byteCount);
      }
      final now = _clock().toUtc();
      final hash = digest.close();
      final claimed = (await ledger.claimContent(
        hash,
        byteCount: staged.byteCount,
        contentKey: _newContentKey(hash),
        now: now,
      ))!;
      // Checked even for content the ledger already held: a write that died
      // between claiming new content and moving its bytes in leaves a record
      // with nothing behind it, and this is where that is repaired.
      if (await content.exists(claimed.contentKey)) {
        await content.delete(staging);
      } else {
        await content.move(staging, claimed.contentKey);
      }
      final entry = TomBlobLedgerEntry(
        key: key,
        owner: owner,
        digest: hash,
        contentKey: claimed.contentKey,
        byteCount: staged.byteCount,
        mediaType: mediaType,
        fileName: fileName,
        storedAt: now,
      );
      await ledger.record(entry);
      return entry.toStoredBlob();
    } on Object {
      // Moved or deleted already on the paths that got that far; a staged
      // write that did not becomes nothing.
      await content.delete(staging).catchError((Object _) => false);
      rethrow;
    }
  }

  @override
  Stream<List<int>> doGet(String key) async* {
    final entry = await _entry(key);
    yield* content.get(entry.contentKey);
  }

  @override
  Stream<List<int>> doGetRange(String key, TomBlobRange range) async* {
    final entry = await _entry(key);
    yield* content.get(entry.contentKey, range: range);
  }

  @override
  Future<TomStoredBlob?> doDescribe(String key) async =>
      (await ledger.find(key))?.toStoredBlob();

  @override
  Future<bool> doExists(String key) async => await ledger.find(key) != null;

  @override
  Future<bool> doDelete(String key) async => await ledger.remove(key) != null;

  @override
  Future<int> doDeletePrefix(String prefix) => ledger.removePrefix(prefix);

  /// A copy is a ledger entry naming the source's content, charged to the
  /// current owner; no bytes move.
  @override
  Future<TomStoredBlob> doCopy(String fromKey, String toKey) async {
    final source = await _entry(fromKey);
    final owner = currentOwner();
    final usage = await _usageReplacing(owner, toKey);
    if (usage != null) {
      quota!.check(owner, usage, addedBytes: source.byteCount);
    }
    return _recordAt(toKey, source, owner);
  }

  /// A move renames the entry; its owner stays, and no bytes move.
  @override
  Future<TomStoredBlob> doMove(String fromKey, String toKey) async {
    final source = await _entry(fromKey);
    final moved = await _recordAt(toKey, source, source.owner);
    await ledger.remove(fromKey);
    return moved;
  }

  /// Deletes content no key has named, and nothing has claimed, for
  /// [reclaimGrace] before [now] (default: the current time), in batches of
  /// [batchSize]; answers how many contents went.
  ///
  /// The content's record goes before its bytes, and only while it is still
  /// unnamed and unclaimed, so a write claiming the same content concurrently
  /// either keeps it or gets new content under a new key — never bytes that
  /// are being deleted. A failure deleting the bytes after their record went
  /// leaves them unreachable rather than referenced; it is reported, not
  /// retried.
  Future<int> reclaim({DateTime? now, int batchSize = 500}) async {
    if (batchSize < 1) {
      // throws-outside-family: programmer error — a batch of nothing never
      // makes progress.
      throw ArgumentError.value(batchSize, 'batchSize', 'must be at least 1');
    }
    final cutoff = (now ?? _clock()).toUtc().subtract(reclaimGrace);
    var reclaimed = 0;
    while (true) {
      final batch = await ledger.reclaimable(cutoff, limit: batchSize);
      var dropped = 0;
      for (final candidate in batch) {
        if (!await ledger.dropContent(candidate, cutoff)) continue;
        await content.delete(candidate.contentKey);
        dropped++;
      }
      reclaimed += dropped;
      // A batch in which nothing could be dropped would come back unchanged.
      if (batch.length < batchSize || dropped == 0) return reclaimed;
    }
  }

  /// A job running [reclaim] on [schedule] (default: hourly), for a
  /// [TomScheduler] to run in its own isolate ([TomInlineJobDispatcher]),
  /// since its body holds this store.
  TomJobDefinition reclaimJobDefinition({
    String name = 'tom.storage.reclaim',
    TomSchedule? schedule,
  }) => TomJobDefinition(
    name: name,
    schedule: schedule ?? TomIntervalSchedule(const Duration(hours: 1)),
    body: (_) => _TomBlobReclaimCommand(this),
    missedWindowPolicy: TomMissedWindowPolicy.runOnce,
  );

  @override
  Future<void> close() => content.close();

  /// The entry under [key], or `storage.blob.not_found`.
  Future<TomBlobLedgerEntry> _entry(String key) async =>
      await ledger.find(key) ?? (throw TomBlobStore.notFound(key));

  /// [owner]'s usage with whatever it holds under [key] taken out — the usage
  /// a write over [key] is checked against — or `null` when no quota applies.
  Future<TomBlobUsage?> _usageReplacing(String owner, String key) async {
    if (quota == null || owner.isEmpty) return null;
    final held = await ledger.usageOf(owner);
    final previous = await ledger.find(key);
    if (previous == null || previous.owner != owner) return held;
    return TomBlobUsage(
      count: held.count - 1,
      bytes: held.bytes - previous.byteCount,
    );
  }

  /// Records [toKey] as naming [source]'s content for [owner], after claiming
  /// the content so a reclaim cannot take it in between.
  Future<TomStoredBlob> _recordAt(
    String toKey,
    TomBlobLedgerEntry source,
    String owner,
  ) async {
    final now = _clock().toUtc();
    final claimed = await ledger.claimContent(
      source.digest,
      byteCount: source.byteCount,
      contentKey: source.contentKey,
      now: now,
      create: false,
    );
    if (claimed == null) throw TomBlobStore.notFound(source.key);
    final entry = TomBlobLedgerEntry(
      key: toKey,
      owner: owner,
      digest: source.digest,
      contentKey: claimed.contentKey,
      byteCount: source.byteCount,
      mediaType: source.mediaType,
      fileName: source.fileName,
      storedAt: now,
    );
    await ledger.record(entry);
    return entry.toStoredBlob();
  }

  /// A fresh key for the content with [digest]: fanned out by its first two
  /// hex digits, and suffixed so content reclaimed and stored again never
  /// reuses the key a late delete of the old bytes could still reach.
  String _newContentKey(String digest) =>
      '$contentPrefix/${digest.substring(0, 2)}/$digest-'
      '${_uuid.v4().replaceAll('-', '').substring(0, 12)}';
}

/// One run of [TomDeduplicatingBlobStore.reclaim].
class _TomBlobReclaimCommand extends TomCommand {
  _TomBlobReclaimCommand(this._store);

  final TomDeduplicatingBlobStore _store;

  @override
  Future<Object?> execute() => _store.reclaim();
}
