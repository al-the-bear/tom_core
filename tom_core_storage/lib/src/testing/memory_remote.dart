/// An in-memory compare-and-swap remote, and per-device [TomStorage] views
/// onto it, for the suites of anything that syncs through the storage port.
///
/// The two are split for the two-device tests: convergence is a claim about
/// **one** remote seen by **two** independently-failing clients, so the
/// container state is shared and the reachability switches are not.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../bundle_medium.dart';
import '../commit_progress.dart';
import '../object_ceiling.dart';
import '../storage.dart';

/// The shared container store, head-guarded as [TomStorage.commit] requires.
///
/// Files are held as **bytes**, not text, which is the same primitive a
/// [TomBundleMedium] carries and for the same reason: a container may be an
/// encrypted binary blob and a bundle may hold binary assets, so a store that
/// decoded on the way in would corrupt them before a test could open them.
/// [textSnapshot] decodes on the way out for the callers asserting against a
/// member they already know is YAML.
class TomMemoryRemote {
  final Map<String, Map<String, Uint8List>> _files = {};
  final Map<String, int> _revisions = {};

  /// Every commit that landed, in order — the "one atomic commit per save"
  /// trail a repository history shows.
  final List<String> commits = [];

  /// The changeset each of those commits carried, index-aligned with [commits].
  ///
  /// Recorded because "one save is one atomic commit" and "one save writes only
  /// what changed" are two different claims, and only the second needs to see
  /// *inside* a commit. On the GitHub tier every entry here is a blob upload,
  /// so the length of a changeset is the request cost of a save.
  final List<TomChangeset> changesets = [];

  bool exists(String locator) => _files.containsKey(locator);

  String? headOf(String locator) {
    final revision = _revisions[locator];
    return revision == null ? null : 'h$revision';
  }

  /// Forgets [locator] entirely — its files and its revision.
  void delete(String locator) {
    _files.remove(locator);
    _revisions.remove(locator);
  }

  Map<String, Uint8List> snapshot(String locator) =>
      Map.of(_files[locator] ?? const {});

  /// The same snapshot with every member decoded as UTF-8 — valid for a
  /// plaintext bundle, and meaningless for an encrypted container.
  Map<String, String> textSnapshot(String locator) => {
    for (final entry in snapshot(locator).entries)
      entry.key: utf8.decode(entry.value),
  };

  String apply(String locator, TomChangeset changeset, String? message) {
    final files = _files.putIfAbsent(locator, () => {});
    for (final entry in changeset.writes.entries) {
      files[entry.key] = entry.value;
    }
    files.removeWhere((path, _) => changeset.deletes.contains(path));
    final revision = (_revisions[locator] ?? 0) + 1;
    _revisions[locator] = revision;
    commits.add(message ?? '<no message>');
    changesets.add(changeset);
    return 'h$revision';
  }
}

/// One device's view of [remote].
///
/// Reachability is modelled in two switches rather than one because offline is
/// not symmetric: a device cache serves **reads** while offline, so the
/// ordinary offline document is one whose *writes* fail — which is precisely
/// the case that produces a commit-journal entry, since the changeset can
/// still be built. A full blackout ([readsFail]) is the weaker
/// case where there is nothing to journal.
class TomMemoryStorage extends TomStorage {
  final TomMemoryRemote remote;

  bool writesFail = false;
  bool readsFail = false;

  /// When set, every request is refused for quota — the *reachable but
  /// throttled* case, which is not the same failure as [readsFail].
  DateTime? rateLimitedUntil;

  /// Which limit [rateLimitedUntil] stands for.
  ///
  /// Quota by default because that is the shape this fixture was written for:
  /// a refusal carrying the backend's own stated reset. A case about how a
  /// refusal is shown sets it to say which of the three it is driving.
  TomRateLimitKind rateLimitKind = TomRateLimitKind.quota;

  /// When set, the container's bytes arrive but do not open.
  ///
  /// Injected at the read rather than inside a codec because that is the shape
  /// a sync cycle sees: [TomKeyRequiredException] is a
  /// [TomStorageException] precisely so a loop that cannot name the codec
  /// can still catch it, and a harness that raised it from somewhere the
  /// engine reaches only through a codec would be testing a narrower path than
  /// production has. Writes are unaffected: a locked container is one we cannot
  /// *read*, and the cycle must stop before the merge that needs plaintext.
  String? keyRequiredReason;

  /// When set, every head read answers with this value instead of the truth —
  /// the shape a replica takes under eventual consistency.
  ///
  /// Set to `const TomStaleHead(null)` for the 404-shaped answer (a replica that
  /// has not seen a ref *create*), or `TomStaleHead(sha)` for a ref that has not
  /// caught up with a later commit. A wrapper rather than a bare `String?`
  /// because the interesting case *is* null, and a nullable field cannot
  /// distinguish "answer null" from "answer truthfully".
  ///
  /// This is a fact about the **remote**, not about our own writes: the GitHub
  /// backend already refuses a ref answer it can prove is historical, but only
  /// for commits it made itself. A stale read of *another*
  /// device's commit is unprovable and must be believed — which is the state
  /// this reproduces.
  TomStaleHead? staleHead;

  /// One-locator head reads, so a test can show what an unbatched loop costs.
  int headOfCalls = 0;

  /// Batched head reads — the number of *requests* a tick actually spends.
  int headsOfCalls = 0;

  /// Fired just before a commit is applied — the hook the edit-during-sync
  /// test uses to land an edit inside a cycle.
  void Function()? onCommit;

  TomMemoryStorage(this.remote);

  /// Puts the device offline in the ordinary sense: reads still come from the
  /// cache, writes do not reach the remote.
  void goOffline() => writesFail = true;

  void goOnline() {
    writesFail = false;
    readsFail = false;
  }

  @override
  bool handles(String locator) => locator.startsWith('mem:');

  @override
  Future<List<TomStorageEntry>> list(String locator) async {
    _guardRead(locator);
    return [
      for (final path in remote.snapshot(locator).keys)
        TomStorageEntry(
          name: path.split('/').last,
          path: path,
          kind: TomEntryKind.file,
        ),
    ];
  }

  /// The whole container, for the single-file kind.
  ///
  /// A single-file container is stored under [TomChangeset.containerPath] —
  /// the same key [TomChangeset.singleFile] writes — so the sidecar's
  /// read and its commit address one thing, and a bundle locator asked for its
  /// bytes fails loudly rather than answering with one arbitrary member file.
  @override
  Future<Uint8List> readBytes(String locator) async {
    _guardRead(locator);
    final bytes = remote.snapshot(locator)[TomChangeset.containerPath];
    if (bytes == null) {
      throw TomStorageException(
        locator,
        'not a single-file container — it holds '
        '${remote.snapshot(locator).length} member files',
      );
    }
    return bytes;
  }

  @override
  Future<TomBundleMedium> readBundle(String locator) async {
    _guardRead(locator);
    return TomMemoryBundleMedium(remote.snapshot(locator));
  }

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async {
    // Guarded as every backend's commit is, so a double that is given a
    // ceiling refuses an oversized object the way a real backend does.
    tomGuardChangeset(locator, changeset, this);
    final until = rateLimitedUntil;
    if (until != null) {
      throw TomRateLimitException(locator, kind: rateLimitKind, resetAt: until);
    }
    if (writesFail) {
      throw TomUnreachableException(locator, 'device is offline');
    }
    final actual = remote.headOf(locator);
    if (actual != expectedHead) {
      throw TomCasConflictException(
        locator,
        expectedHead: expectedHead,
        actualHead: actual,
      );
    }
    onCommit?.call();
    if (changeset.isEmpty) return actual ?? TomStorage.emptyHead;
    return remote.apply(locator, changeset, message);
  }

  /// Locators whose deletion is refused — the storage layer's "removal
  /// failed" shape, injected per locator.
  final Set<String> deleteFails = {};

  @override
  Future<void> delete(String locator) async {
    if (deleteFails.contains(locator)) {
      throw TomStorageException(locator, 'could not remove $locator');
    }
    remote.delete(locator);
  }

  @override
  Future<String?> headOf(String locator) async {
    headOfCalls++;
    _guardRequest(locator);
    // Not `staleHead?.sha ?? remote.headOf(...)`: that collapses
    // `TomStaleHead(null)` back to the truth, which is the one case the
    // wrapper exists for.
    final stale = staleHead;
    return stale != null ? stale.sha : remote.headOf(locator);
  }

  /// Answers every locator in one request, as the GitHub backend does for the
  /// documents sharing a repository and branch.
  @override
  Future<Map<String, String?>> headsOf(Iterable<String> locators) async {
    headsOfCalls++;
    final all = locators.toList();
    _guardRequest(all.isEmpty ? '' : all.first);
    final stale = staleHead;
    return {
      for (final locator in all)
        locator: stale == null ? remote.headOf(locator) : stale.sha,
    };
  }

  void _guardRead(String locator) {
    _guardRequest(locator);
    if (!remote.exists(locator)) {
      throw TomContainerNotFoundException(locator);
    }
    // After existence, before content: the bytes are there, they just will not
    // open.
    final reason = keyRequiredReason;
    if (reason != null) throw TomKeyRequiredException(locator, reason);
  }

  void _guardRequest(String locator) {
    final until = rateLimitedUntil;
    if (until != null) {
      throw TomRateLimitException(locator, kind: rateLimitKind, resetAt: until);
    }
    if (readsFail) throw TomUnreachableException(locator, 'device is offline');
  }
}

/// A head value a replica would answer with instead of the truth.
///
/// Exists so a test can say "answer null" — which a nullable field cannot
/// express, because null there already means "answer truthfully".
class TomStaleHead {
  final String? sha;

  const TomStaleHead(this.sha);
}
