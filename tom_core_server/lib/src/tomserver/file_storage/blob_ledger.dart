/// The ledger behind [TomDeduplicatingBlobStore]: which logical keys exist,
/// whose they are, and which stored content each one names.
///
/// A blob store cannot list itself — deliberately, see [TomBlobStore] — so a
/// store that has to answer "who holds how much", "is this content still
/// wanted" and "which keys are older than a week" keeps that record beside the
/// bytes. The ledger is that record, in two parts:
///
/// | Part | One per | Holds |
/// | ---- | ------- | ----- |
/// | [TomBlobLedgerEntry] | logical key | its owner, content digest and key, size, media type, file name, write time |
/// | [TomBlobContent] | distinct content (SHA-256) | the key the bytes are stored under, their size, when it was last claimed |
///
/// Many entries may name one content; that is the deduplication. Content no
/// entry names is reclaimed by [TomDeduplicatingBlobStore.reclaim], never at
/// the moment its last entry goes — see [claimContent] for why.
library;

import 'blob_store.dart';
import 'deduplicating_blob_store.dart';

/// One logical key of a [TomDeduplicatingBlobStore].
class TomBlobLedgerEntry {
  /// An entry for [key], owned by [owner], whose bytes are the content with
  /// [digest], stored under [contentKey].
  TomBlobLedgerEntry({
    required this.key,
    required this.owner,
    required this.digest,
    required this.contentKey,
    required this.byteCount,
    required this.mediaType,
    required DateTime storedAt,
    this.fileName,
  }) : storedAt = storedAt.toUtc();

  /// The logical key.
  final String key;

  /// Who the blob counts against — a principal's qualified id, a tenant, a
  /// job; `''` for a blob of no one, which no quota counts.
  final String owner;

  /// The SHA-256 of the content, as lowercase hex.
  final String digest;

  /// The key the content's bytes are stored under in the content store — the
  /// [TomBlobContent.contentKey] of [digest], kept here so a read is one
  /// lookup.
  final String contentKey;

  /// The content's size.
  final int byteCount;

  /// The media type the blob was stored with.
  final String mediaType;

  /// The file name the blob was stored with, if any.
  final String? fileName;

  /// When the key was written, in UTC.
  final DateTime storedAt;

  /// This entry as the descriptor [TomBlobStore.describe] answers.
  TomStoredBlob toStoredBlob() => TomStoredBlob(
    key: key,
    mediaType: mediaType,
    byteCount: byteCount,
    storedAt: storedAt,
    digest: digest,
    fileName: fileName,
  );

  @override
  String toString() => 'TomBlobLedgerEntry($key, $owner, $byteCount bytes)';
}

/// One distinct content held by a [TomDeduplicatingBlobStore].
class TomBlobContent {
  /// The content with [digest], stored under [contentKey].
  TomBlobContent({
    required this.digest,
    required this.contentKey,
    required this.byteCount,
    required DateTime claimedAt,
  }) : claimedAt = claimedAt.toUtc();

  /// The SHA-256 of the content, as lowercase hex.
  final String digest;

  /// The key the bytes are stored under in the content store.
  final String contentKey;

  /// The content's size.
  final int byteCount;

  /// When a write or copy last claimed it, in UTC.
  final DateTime claimedAt;

  @override
  String toString() => 'TomBlobContent($digest at $contentKey)';
}

/// How much an owner holds: [count] blobs of [bytes] in total.
///
/// Logical bytes: an owner is charged for every blob it holds, whether or not
/// another key shares the content, so what one owner may store never depends
/// on what somebody else uploaded.
class TomBlobUsage {
  /// Usage of [count] blobs totalling [bytes].
  const TomBlobUsage({required this.count, required this.bytes});

  /// How many blobs.
  final int count;

  /// Their total size.
  final int bytes;

  @override
  String toString() => 'TomBlobUsage($count blobs, $bytes bytes)';
}

/// The record a [TomDeduplicatingBlobStore] keeps of its keys and contents.
abstract class TomBlobLedger {
  /// Creates a ledger.
  const TomBlobLedger();

  /// The entry under [key], or `null`.
  Future<TomBlobLedgerEntry?> find(String key);

  /// Records [entry], replacing any entry under its key.
  Future<void> record(TomBlobLedgerEntry entry);

  /// Removes the entry under [key] and answers it, or `null` when there was
  /// none. The content it named stays until [TomDeduplicatingBlobStore.reclaim].
  Future<TomBlobLedgerEntry?> remove(String key);

  /// Removes the entry [prefix] names and every entry below it, matched by
  /// segment as [TomBlobStore.deletePrefix] matches; answers how many went.
  Future<int> removePrefix(String prefix);

  /// What [owner] holds.
  Future<TomBlobUsage> usageOf(String owner);

  /// Up to [limit] entries written before [before] whose key sorts after
  /// [after], in key order — the page an orphan sweep walks.
  Future<List<TomBlobLedgerEntry>> storedBefore(
    DateTime before, {
    String after = '',
    int limit = 500,
  });

  /// How many entries name the content with [digest].
  Future<int> referencesTo(String digest);

  /// The content with [digest], claimed at [now]; created under [contentKey]
  /// when there is none and [create] is set, otherwise `null` when there is
  /// none.
  ///
  /// A claim is what keeps content from being reclaimed while a write that
  /// will name it is still in flight: [reclaimable] and [dropContent] only take
  /// content claimed before their cutoff, so a claim made at the start of a
  /// write protects the content until the write has recorded its entry. That is
  /// why content is never deleted the moment its last entry goes — the delete
  /// and a concurrent write of the same bytes in another process would race,
  /// and the write would lose its content.
  ///
  /// When the content was reclaimed and is claimed again, it is created anew
  /// under the new [contentKey], so the old bytes and the new ones never share
  /// a key and a late delete of the old cannot touch the new.
  Future<TomBlobContent?> claimContent(
    String digest, {
    required int byteCount,
    required String contentKey,
    required DateTime now,
    bool create = true,
  });

  /// Up to [limit] contents no entry names and nothing claimed since
  /// [claimedBefore], oldest claim first.
  Future<List<TomBlobContent>> reclaimable(
    DateTime claimedBefore, {
    int limit = 500,
  });

  /// Removes [content]'s record if it is still unnamed and unclaimed since
  /// [claimedBefore]; answers whether it did, and so whether its bytes may go.
  Future<bool> dropContent(TomBlobContent content, DateTime claimedBefore);
}

/// Whether [key] is [prefix] or lies below it, segment by segment.
bool tomBlobKeyUnder(String key, String prefix) =>
    key == prefix || key.startsWith('$prefix/');

/// A [TomBlobLedger] in memory: right for tests and a single process whose
/// content store is in memory too, wrong for anything that outlives the
/// process.
class TomMemoryBlobLedger extends TomBlobLedger {
  /// Creates an empty ledger.
  TomMemoryBlobLedger();

  final Map<String, TomBlobLedgerEntry> _entries = {};
  final Map<String, TomBlobContent> _contents = {};

  @override
  Future<TomBlobLedgerEntry?> find(String key) async => _entries[key];

  @override
  Future<void> record(TomBlobLedgerEntry entry) async =>
      _entries[entry.key] = entry;

  @override
  Future<TomBlobLedgerEntry?> remove(String key) async => _entries.remove(key);

  @override
  Future<int> removePrefix(String prefix) async {
    final doomed = [
      for (final key in _entries.keys)
        if (tomBlobKeyUnder(key, prefix)) key,
    ];
    doomed.forEach(_entries.remove);
    return doomed.length;
  }

  @override
  Future<TomBlobUsage> usageOf(String owner) async {
    var count = 0;
    var bytes = 0;
    for (final entry in _entries.values) {
      if (entry.owner != owner) continue;
      count++;
      bytes += entry.byteCount;
    }
    return TomBlobUsage(count: count, bytes: bytes);
  }

  @override
  Future<List<TomBlobLedgerEntry>> storedBefore(
    DateTime before, {
    String after = '',
    int limit = 500,
  }) async =>
      (_entries.values
              .where(
                (e) =>
                    e.storedAt.isBefore(before) && e.key.compareTo(after) > 0,
              )
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .take(limit)
          .toList();

  @override
  Future<int> referencesTo(String digest) async =>
      _entries.values.where((e) => e.digest == digest).length;

  @override
  Future<TomBlobContent?> claimContent(
    String digest, {
    required int byteCount,
    required String contentKey,
    required DateTime now,
    bool create = true,
  }) async {
    final held = _contents[digest];
    if (held == null && !create) return null;
    return _contents[digest] = TomBlobContent(
      digest: digest,
      contentKey: held?.contentKey ?? contentKey,
      byteCount: held?.byteCount ?? byteCount,
      claimedAt: now,
    );
  }

  @override
  Future<List<TomBlobContent>> reclaimable(
    DateTime claimedBefore, {
    int limit = 500,
  }) async {
    final named = {for (final entry in _entries.values) entry.digest};
    return (_contents.values
            .where(
              (c) =>
                  c.claimedAt.isBefore(claimedBefore) &&
                  !named.contains(c.digest),
            )
            .toList()
          ..sort((a, b) => a.claimedAt.compareTo(b.claimedAt)))
        .take(limit)
        .toList();
  }

  @override
  Future<bool> dropContent(
    TomBlobContent content,
    DateTime claimedBefore,
  ) async {
    final held = _contents[content.digest];
    if (held == null ||
        held.contentKey != content.contentKey ||
        !held.claimedAt.isBefore(claimedBefore) ||
        _entries.values.any((e) => e.digest == content.digest)) {
      return false;
    }
    _contents.remove(content.digest);
    return true;
  }
}

/// How much one owner may hold in a [TomDeduplicatingBlobStore]: at most
/// [maxCount] blobs, at most [maxBytes] in total; `null` leaves that dimension
/// unbounded.
///
/// Checked on every write and copy made for an owner. The count and the bytes
/// already held are checked before anything is written, so a full owner costs
/// no upload; the size of the new blob is only known once its bytes have
/// arrived, so a write that takes the owner past [maxBytes] is undone before it
/// is recorded and refused. The check reads the ledger and then writes it, so
/// two writes racing for the last of an owner's space can both pass; the quota
/// bounds an owner, it is not a reservation.
class TomBlobQuota {
  /// A quota of [maxCount] blobs and [maxBytes] bytes per owner.
  const TomBlobQuota({this.maxCount, this.maxBytes});

  /// The most blobs one owner may hold.
  final int? maxCount;

  /// The most bytes one owner's blobs may total.
  final int? maxBytes;

  /// Throws unless [owner], holding [usage], may hold one more blob.
  ///
  /// Before the write, [addedBytes] is `0` and the bytes already held are
  /// compared with [maxBytes]; after it, [addedBytes] is the written size and
  /// the total must fit. [countingNew] is `false` for a write that replaces a
  /// blob the owner already holds, which adds nothing to the count; the caller
  /// takes the replaced blob's bytes out of [usage] first.
  ///
  /// Keyed `storage.quota.count_exceeded` or `storage.quota.bytes_exceeded`.
  void check(
    String owner,
    TomBlobUsage usage, {
    int addedBytes = 0,
    bool countingNew = true,
  }) {
    final maxCount = this.maxCount;
    if (maxCount != null && countingNew && usage.count >= maxCount) {
      throw TomStorageException(
        'storage.quota.count_exceeded',
        'The file cannot be stored: its owner already holds the most files '
            'allowed. Delete one first.',
        parameters: {'owner': owner, 'count': usage.count, 'limit': maxCount},
      );
    }
    final maxBytes = this.maxBytes;
    final total = usage.bytes + addedBytes;
    if (maxBytes != null &&
        (total > maxBytes || (addedBytes == 0 && total >= maxBytes))) {
      throw TomStorageException(
        'storage.quota.bytes_exceeded',
        'The file cannot be stored: its owner\'s files would exceed the space '
            'allowed. Delete some first.',
        parameters: {'owner': owner, 'bytes': total, 'limit': maxBytes},
      );
    }
  }
}
