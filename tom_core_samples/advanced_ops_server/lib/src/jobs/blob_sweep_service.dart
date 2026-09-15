/// The blob store's own maintenance: the chunk rows no manifest refers to.
///
/// ## The residue this collects
///
/// `TomDatabaseBlobStore` stores a blob as one manifest row plus N chunk rows,
/// and the manifest is what makes it visible. Every path that removes a blob
/// therefore removes the manifest row *first* and the chunks after — a delete, a
/// replace, a prefix purge — and a failure between the two leaves chunk rows
/// nothing points at. That residue is invisible: no read finds it, no count
/// reports it, and the only symptom is a table that is larger than the blobs it
/// holds.
///
/// `purgeOrphanedChunks` is the sweep for it, and until this job existed nothing
/// outside the framework's own tests called it. A maintenance operation a
/// backend admits it needs and no deployment is told to run is a slow leak with
/// a documented name.
///
/// ## Why weekly, and why 04:00 Sunday
///
/// The residue is *rare* — it needs a cleanup that failed, not a blob that was
/// deleted — so a nightly sweep would spend a full-table anti-join six times a
/// week to find nothing. Weekly is the cadence that matches how the rows
/// actually accumulate.
///
/// The hour is the dependency. 03:00 is the retention purge, which destroys
/// items and cascades into their attachments: whatever residue a failed cascade
/// leaves is *created* there, so a sweep before it would collect last week's and
/// leave tonight's for another seven days. 05:00 is the weekly report, which
/// *writes* into the same store — sweeping after that would scan rows that were
/// committed minutes earlier and can never be orphans. Between them is the one
/// window where the sweep has the most to find and the least to read.
///
/// ## Why it is a separate job from the purge
///
/// The same reason the other three are separate: the retry budgets differ. The
/// retention purge is recoverable and should be retried; this is a sweep whose
/// only cost of being skipped is that the rows survive another week, so it takes
/// one attempt and no recovery. Folding it into the purge would give the two one
/// policy, and it would be the purge's.
library;

import 'package:tom_core_server/tom_core_server.dart';

/// What one sweep removed.
class OpsBlobSweepReport {
  /// Creates a report.
  const OpsBlobSweepReport({required this.chunksRemoved});

  /// How many chunk rows no manifest referred to.
  ///
  /// Zero is the expected reading and the one worth seeing in a log: it says
  /// every cleanup since the last sweep completed. A number that is *routinely*
  /// non-zero is not a sweep doing its job, it is a cleanup path failing
  /// somewhere and this being the only thing that notices.
  final int chunksRemoved;

  @override
  String toString() => 'OpsBlobSweepReport(chunksRemoved: $chunksRemoved)';
}

/// Runs the blob store's orphan sweep.
///
/// Takes the store rather than resolving it, for the reason every service here
/// does: the claim is about the sweep being called, and a service that reached
/// into the registry could only be exercised by a process that had one.
class OpsBlobSweepService {
  /// Creates a sweep over [store].
  const OpsBlobSweepService({required this.store});

  /// Resolves the configured store and refuses anything that cannot sweep.
  ///
  /// The refusal is at **wire-up**, not at 04:00 on Sunday. The sweep is a
  /// property of the database backend — a directory store has no chunk rows and
  /// an object store has no manifest — so pointing this deployment's `files`
  /// store at another backend does not make the job harmless, it makes it a
  /// scheduled no-op that reports success. Failing here is the difference
  /// between learning that at boot and never learning it.
  factory OpsBlobSweepService.configured([String? storeName]) {
    final store = storeName == null
        ? TomBlobStoreInfo.defaultStore
        : TomBlobStoreInfo.storeNamed(storeName);
    if (store is! TomDatabaseBlobStore) {
      throw TomStorageException(
        'ops.blob_sweep.unsupported_backend',
        'The configured blob store has no orphan sweep.',
        parameters: {'store': '$store', 'name': storeName ?? '(default)'},
      );
    }
    return OpsBlobSweepService(store: store);
  }

  /// The store whose chunk table is swept.
  final TomDatabaseBlobStore store;

  /// Deletes every chunk row no manifest refers to.
  ///
  /// Unscoped by construction rather than by opt-out: the chunk table carries no
  /// entity and no `@TomDbScope`, so unlike the retention pass this needs no
  /// `runUnscoped` — there is no row scope to escape. Worth saying because the
  /// two jobs otherwise look alike, and a reader who assumed the bypass applied
  /// here would go looking for the one that is not there.
  Future<OpsBlobSweepReport> sweep() async =>
      OpsBlobSweepReport(chunksRemoved: await store.purgeOrphanedChunks());
}
