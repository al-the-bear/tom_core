import 'dart:typed_data';

import 'package:tom_basics/diagnostics.dart';
import 'bundle_medium.dart';
import 'backoff_policy.dart';
import 'commit_progress.dart';

/// What a path inside a container is.
enum TomEntryKind { file, directory }

/// One entry inside a container, as [TomStorage.list] reports it.
///
/// [revision] is whatever the backend uses to tell one version of this entry
/// from another — a git blob sha, an ETag, a size+mtime token. It is opaque:
/// compare it, never parse it.
class TomStorageEntry {
  /// Last path segment.
  final String name;

  /// Path relative to the container, `/`-separated.
  final String path;

  final TomEntryKind kind;
  final String? revision;

  const TomStorageEntry({
    required this.name,
    required this.path,
    required this.kind,
    this.revision,
  });

  bool get isFile => kind == TomEntryKind.file;
  bool get isDirectory => kind == TomEntryKind.directory;

  @override
  String toString() => 'TomStorageEntry(${kind.name} $path @ $revision)';
}

/// Every change one save makes to one container, as a single unit.
///
/// A *move* — which is what `.history/` snapshotting is — lowers to a write of
/// the new path plus a delete of the old one, so there is no third operation
/// kind to implement in every backend.
///
/// For a single-file container (an encrypted file, a ZIP archive) the whole
/// container is one write at [containerPath].
class TomChangeset {
  /// The path that stands for "the container itself".
  static const containerPath = '';

  final Map<String, Uint8List> writes;
  final Set<String> deletes;

  TomChangeset({
    Map<String, Uint8List> writes = const {},
    Set<String> deletes = const {},
  }) : writes = Map.unmodifiable(writes),
       deletes = Set.unmodifiable(deletes);

  /// The whole container replaced by [bytes].
  factory TomChangeset.singleFile(Uint8List bytes) =>
      TomChangeset(writes: {containerPath: bytes});

  bool get isEmpty => writes.isEmpty && deletes.isEmpty;
  bool get isNotEmpty => !isEmpty;

  /// True when this changeset replaces the container wholesale rather than
  /// touching paths inside it.
  bool get isSingleFile =>
      deletes.isEmpty &&
      writes.length == 1 &&
      writes.containsKey(containerPath);

  /// The replacement bytes for a [isSingleFile] changeset.
  Uint8List get containerBytes => writes[containerPath]!;

  @override
  String toString() =>
      'TomChangeset(${writes.length} writes, ${deletes.length} deletes)';
}

/// A storage operation that could not be carried out.
class TomStorageException implements Exception, TomStructuredFailure {
  final String locator;
  final String message;
  final Object? cause;

  const TomStorageException(this.locator, this.message, {this.cause});

  @override
  Map<String, Object> get diagnosticFields => {
    'locator': locator,
    if (cause != null) 'cause': cause.runtimeType.toString(),
  };

  @override
  String toString() =>
      'TomStorageException($locator): $message${cause == null ? '' : ' ($cause)'}';
}

/// The backend could not be reached at all: no answer, as distinct from an
/// answer that was a refusal.
///
/// Its own type because it is the one failure a cache can stand in for
/// ("reads are served from the cache"). A refusal is the backend's word on
/// the matter and serving a cached copy over it would contradict the backend;
/// silence says nothing, so what the device already holds is the best
/// available answer.
class TomUnreachableException extends TomStorageException {
  const TomUnreachableException(super.locator, super.message, {super.cause});
}

/// Nothing exists at [locator].
class TomContainerNotFoundException extends TomStorageException {
  const TomContainerNotFoundException(String locator)
    : super(locator, 'No container at this locator');
}

/// The container moved between the head we read and the commit we attempted.
///
/// This is not an error to paper over — it is the signal that somebody else
/// saved. The caller re-reads, merges, and retries.
class TomCasConflictException extends TomStorageException {
  /// The head the caller believed was current.
  final String? expectedHead;

  /// The head the backend actually has, when it could be determined.
  final String? actualHead;

  const TomCasConflictException(
    String locator, {
    required this.expectedHead,
    required this.actualHead,
  }) : super(
         locator,
         'Container moved from $expectedHead to $actualHead before the commit',
       );
}

/// The container at [locator] is encrypted and no configured key opens it
///.
///
/// **A storage failure, not a KDBX failure.** It lives here — beside the
/// offline and rate-limit cases — rather than beside the key provider that
/// raises it, for three reasons that all point the same way:
///
///  1. It is exactly a transport outcome: the bytes arrived, the container did
///     not open, and nothing can proceed until a person supplies something.
///     The sync loop has to treat it as such, and a loop that catches
///     `TomStorageException` must not have this one slip past into an
///     unhandled async error on a timer tick.
///  2. `sync_engine.dart` is on the kdbx-free side of the seam
///     and so cannot import the key provider's library at all. A type it
///     cannot name is a type it cannot catch.
///  3. The plaintext path raises it too — the settings container and any
///     future encrypted backend hit the same wall.
///
/// It carries no key material and no `kdbx` type: two strings, which is all a
/// prompt needs.
class TomKeyRequiredException extends TomStorageException {
  const TomKeyRequiredException(super.locator, super.message);

  /// Why the container did not open, phrased for a person: whether there was
  /// no key at all, or the one we had was rejected.
  ///
  /// An alias for [message], because at this call site the string is not a
  /// diagnostic — it is the sentence the W11 prompt shows above the passphrase
  /// field, and reading it as `e.reason` is what says so.
  String get reason => message;

  @override
  String toString() =>
      'TomKeyRequiredException($locator): $reason — prompt the user for '
      "this file's key (P8)";
}

/// The backend refused the request because the caller is over its request
/// quota, not because anything is wrong with the request.
///
/// This is deliberately **not** the same as "offline". A rate-limited backend
/// is reachable and healthy; polling it again immediately is what keeps it
/// refusing. The sync loop therefore treats this as "come back at
/// [retryAfter]" rather than as a lost connection — which is only possible if
/// the wait is carried on the exception instead of being flattened into a
/// generic failure. Transport-level retry (`GitHubRetryPolicy`) already absorbs
/// waits it can sit out; what reaches here is the one that is too long to
/// sleep through inside a single request.
/// Which kind of limit a [TomRateLimitException] reports.
///
/// The three differ in **how long they last and how much the stated time is
/// worth**, and a consumer that cannot tell them apart has to pick one
/// rendering for all of them. picked "Paused until T", which is right
/// for exactly one of the three: a quota reset is a fact the backend stated,
/// while a secondary limit's time is chosen by the storage layer
/// and is a conservative estimate. Showing a clock time to the second for an
/// estimate is false precision, and showing the same words for a one-minute
/// throttle and a quarter-hour block tells a user nothing about whether to
/// wait or go and do something else.
///
/// Required rather than defaulted, deliberately. A default would be a claim
/// about a backend the author of this type has not seen, made silently, in
/// the one place the distinction exists to be explicit.
enum TomRateLimitKind {
  /// The backend's own request quota is exhausted, and [
  /// TomRateLimitException.resetAt] is **the backend's own answer** for
  /// when it returns.
  quota,

  /// A short, self-clearing limit on burst *rate* rather than volume — the one
  /// a polling loop earns, since it is a judgement about bursts and a save is
  /// a burst. Clears on the scale of a minute.
  throttle,

  /// A content-creation block, earned by a burst of writes.
  ///
  /// How long it lasts depends on what the client does next: one that kept
  /// sending after the refusal saw it hold for fifteen to twenty-four minutes
  ///; one that stopped at the first refusal saw it clear in 70 to
  /// 113 seconds, three times out of three. Worth keeping
  /// distinct from [throttle] because the user's answer to it differs.
  ///
  /// It is issue and comment writes that meet it; git-data writes were
  /// measured to go through while one was in force.
  blocked,
}

class TomRateLimitException extends TomStorageException {
  /// When the quota is expected to be available again, when the backend said.
  final DateTime? resetAt;

  /// Which limit this is.
  ///
  /// Carried to the indicator, which renders the three differently —
  /// and *only* here, because the loop's behaviour is the same for all three:
  /// defer until [resetAt] and come back. A kind that changed the cadence
  /// would be a second place the backoff is decided, and that decision belongs
  /// to the storage layer.
  final TomRateLimitKind kind;

  TomRateLimitException(
    String locator, {
    required this.kind,
    this.resetAt,
    Object? cause,
  }) : super(
         locator,
         resetAt == null
             ? 'Rate limited by the storage backend'
             : 'Rate limited by the storage backend until '
                   '${resetAt.toUtc().toIso8601String()}',
         cause: cause,
       );

  /// How long to wait before trying again, or null when the backend did not
  /// say. Never negative: a reset already in the past means "try now".
  Duration? retryAfter({DateTime? now}) {
    final reset = resetAt;
    if (reset == null) return null;
    final remaining = reset.difference(now ?? DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Where documents live: a local filesystem, a git repository, a relay.
///
/// The invariant that keeps backends interchangeable is that **every write goes through
/// [commit]**: one changeset, applied all-or-nothing, guarded by a
/// compare-and-swap on [headOf]. There is no partial save any reader can
/// observe, and there is no code path that mutates a container in place.
///
/// [readBundle] therefore returns a **detached** medium: mutating it changes
/// nothing in storage. That is deliberate — it is what lets the same
/// [TomChangeset] recording work identically over a directory on disk and
/// a tree in a git repository.
abstract class TomStorage {
  /// Adopts how long to hold off after a rate limit that stated no instant.
  ///
  /// A no-op for a backend that never chooses a wait — a local filesystem
  /// cannot be rate-limited. Delivered by the sync scheduler whenever the
  /// `sync` settings change and whenever a backend joins it, so a settings
  /// change reaches a backend that already exists without the composition
  /// root having to remember to forward it.
  void adoptBackoff(TomBackoffPolicy policy) {}

  /// The revision of a container that exists but holds nothing.
  ///
  /// Committing an empty changeset has to return *some* revision, and a
  /// backend cannot invent one for a container it never created.
  static const emptyHead = '0000000000000000';

  const TomStorage();

  /// Whether this backend owns [locator]'s scheme.
  bool handles(String locator);

  /// The `meta/` key prefix this backend keeps the records for the
  /// storage location [location] under, or null when it keeps none.
  ///
  /// What the "Forget this repo/location" scrubs. A backend whose records
  /// are coarser than a location — GitHub keeps one tree listing per
  /// repository, whatever folder of it a location names — answers the coarser
  /// scope, and the caller keeps it when another registered location shares
  /// it. The default is null: a backend that caches nothing has nothing here.
  List<String>? cacheMetaScope(String location) => null;

  /// The largest a **single** path in a [TomChangeset] may be, or null when
  /// the backend imposes no limit of its own.
  ///
  /// This exists because of the ordering it fixes, not because a number is
  /// interesting. An application that lets a user embed image bytes needs to
  /// know this before the bytes are in a document: a backend that refuses those bytes refuses them **at save time** — after the
  /// paste was accepted, the block inserted and the editing done. Asking the
  /// backend first turns that into a refusal at ingest, which is the only point
  /// at which the user has lost nothing.
  ///
  /// It is deliberately a limit on **one object, not on a save**: measurement
  /// against real GitHub found the ceiling is per blob and that a
  /// single commit carrying 96 MiB across twelve blobs lands fine, so "one save
  /// = one atomic commit" survives an asset-bearing document
  /// unchanged. A backend that ever needed a *whole-save* budget would be
  /// giving up that invariant, and that is a spec decision, not a field.
  int? get maxObjectBytes => null;

  /// Entries directly inside the container at [locator].
  ///
  /// For a single-file artifact this is the artifact itself, as one entry.
  Future<List<TomStorageEntry>> list(String locator);

  /// The bytes of the single-file artifact at [locator].
  Future<Uint8List> readBytes(String locator);

  /// The directory-shaped bundle at [locator], as a detached medium.
  Future<TomBundleMedium> readBundle(String locator);

  /// Applies [changeset] atomically, refusing the write if the container has
  /// moved away from [expectedHead].
  ///
  /// Pass a null [expectedHead] to create a container that does not exist yet;
  /// a backend MUST fail with [TomCasConflictException] if one does.
  /// Returns the new head.
  ///
  /// [onProgress], when given, receives [TomCommitProgress] as the
  /// changeset's objects go up — before each and after the last. It is
  /// **optional on both sides**: a caller need not ask, and a backend whose
  /// save is effectively instantaneous need not report. Silence from a backend
  /// is therefore not a failure to implement it; it is the honest answer for a
  /// local filesystem write.
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  });

  /// Removes the whole container.
  Future<void> delete(String locator);

  /// The current revision of the container, or null when it does not exist.
  Future<String?> headOf(String locator);

  /// [headOf] for several containers at once.
  ///
  /// The default is one call per locator. A backend that can answer many
  /// locators in one request — as GitHub can for every document in the same
  /// repository and branch — SHOULD override this, because polling open
  /// documents one at a time is what exhausts a rate limit.
  Future<Map<String, String?>> headsOf(Iterable<String> locators) async {
    final heads = <String, String?>{};
    for (final locator in locators) {
      heads[locator] = await headOf(locator);
    }
    return heads;
  }

  /// Runs [body] as one **pass**: a stretch of work whose reads may share
  /// what the pass has already established about the remote.
  ///
  /// The sync scheduler opens one per tick. It asks every backend for its
  /// heads and then cycles the documents that moved, and a backend that
  /// validates its view of the remote on every call would otherwise validate
  /// it once for the batch and once more per document, moments apart.
  ///
  /// The contract is narrow on purpose. Inside a pass a **read** may be
  /// answered from what the same pass already validated, so it may be as old
  /// as the pass. A **write** may not: [commit] and [delete] compare against
  /// the remote as it is, pass or no pass. Nothing outlives the pass, and a
  /// call made outside one behaves as if passes did not exist.
  ///
  /// The default runs [body] and nothing else, which is the whole of it for a
  /// backend whose reads are already authoritative.
  Future<T> withinPass<T>(Future<T> Function() body) => body();

  void close() {}
}
