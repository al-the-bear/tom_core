import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:tom_github_api/tom_github_api.dart';

import 'package:tom_basics/diagnostics.dart';

import '../backoff_policy.dart';
import '../bundle_medium.dart';
import '../commit_progress.dart';
import '../lfs_pointer.dart';
import '../object_ceiling.dart';
import '../storage.dart';
import '../storage_cache.dart';
import '../token_source.dart';
import '../github_locator.dart';
import 'github_rate_limits.dart';

/// Containers committed straight into a GitHub repository.
///
/// The whole backend rests on one identification: **a document's head is the
/// git object sha of its path**. That is a content hash, so it changes exactly
/// when the document changes and never when something else in the repository
/// does — which is what makes a per-document compare-and-swap possible on a
/// repository several documents share.
///
/// A save is therefore **one commit**: blobs, one tree over the branch's tree,
/// one commit, one non-forced ref update. GitHub's own refusal to fast-forward
/// a moved branch is the outer CAS; the object-sha check is the inner one that
/// tells "somebody edited this document" from "somebody committed elsewhere in
/// the repo".
class TomGitHubStorage extends TomStorage {
  /// The host [TomTokenSource] is asked for a credential under.
  static const host = 'github.com';

  /// The largest blob the git-data API accepts, measured rather
  /// than read off documentation — 41,820,160 B was accepted and 41,943,040 B
  /// (exactly 40 MiB) was refused with a 422, so the ceiling is *at* 40 MiB and
  /// the last accepted size is the one worth naming.
  ///
  /// Three things about this number are load-bearing, and none of them is the
  /// number:
  ///
  /// 1. It binds on the **decoded** bytes, not on the request body. 39.53 MiB
  ///    of content is 52.71 MiB of base64 on the wire and still lands, so the
  ///    4/3 inflation buys no smaller a limit than it looks — and GitHub's
  ///    documented 100 MB per-file limit is never reached, because this one is
  ///    two and a half times stricter.
  /// 2. It is **per blob**. Twelve 8 MiB blobs — 96 MiB — in one tree, one
  ///    commit and one ref update land fine, as do 500 entries in one tree, so
  ///    there is no aggregate budget for a save to run out of.
  /// 3. Git-LFS cannot move it. LFS is a client-side clean/smudge filter; this
  ///    backend writes objects through the REST API, which never consults
  ///    `.gitattributes`. A 1 MiB write to an LFS-tracked path stored 1 MiB of
  ///    raw bytes, not a pointer.
  @visibleForTesting
  static const maxBlobBytes = 41820160;

  final TomTokenSource? _tokens;

  /// Builds the authenticated client from a secret. The default reaches
  /// `api.github.com`; a test points it at the testkit's fake server, and a
  /// root that reached GitHub through a proxy would bind one too. Null for a
  /// backend built [TomGitHubStorage.withClient], which never builds one.
  final GitHubApiClient Function(String secret)? _clientFactory;

  GitHubApiClient? _client;

  /// The secret [_client] was built with, so that a replaced token is noticed
  /// at the next request and a client is not rebuilt for an unchanged one.
  String? _clientSecret;

  // ── What this client remembers, and for how long ─────────────────────────
  //
  // Four caches, in **two** key spaces, which is the thing to know before
  // changing any of them: `_snapshots` and `_authorities` are keyed by
  // `owner/repo@branch`, `_defaultBranches` and `_emptyRepos` by `owner/repo`.
  // A branch is not a repository and the two cannot share an eviction
  // decision.
  //
  // Only one of the four can grow large. A snapshot holds a fully expanded
  // recursive tree — thousands of entries in a working repository — while the
  // other three hold a string or two per key. So the bound lives on
  // `_snapshots` and the others are deliberately unbounded; see each.

  /// One snapshot per `owner/repo@branch`, so several open documents on the
  /// same branch cost one tree read between them — requirement (5).
  ///
  /// Bounded by [maxCachedTreeEntries], because this is the only cache here
  /// whose entries are big and the only one a long session can grow without
  /// limit: a workspace that opens documents from several repositories over
  /// several hours would otherwise hold every tree it had ever read.
  late final _SnapshotCache _snapshots = _SnapshotCache(this);

  /// `owner/repo` → default branch, so a locator that names no branch costs
  /// one repository read for the whole session rather than one per operation.
  ///
  /// Deliberately unbounded. An entry is two short strings, the key space is
  /// "repositories this session touched", and the whole point of the cache is
  /// that it lasts the session — evicting one trades a documented request
  /// saving for a few dozen bytes.
  final Map<String, String> _defaultBranches = {};

  /// Repositories observed to have no commits at all, so a write can bootstrap
  /// one without first paying a probe to ask.
  ///
  /// Deliberately unbounded, for the same reason as [_defaultBranches], and
  /// self-limiting besides: an entry leaves the moment the repository is
  /// bootstrapped, so what remains is repositories that were found empty and
  /// never written to.
  final Set<String> _emptyRepos = {};

  /// One record per `owner/repo@branch` of the last ref write **this session**
  /// landed, so a later ref read that answers with the commit we superseded can
  /// be recognised as a replica that has not caught up rather than believed.
  ///
  /// Bounded by *time* rather than by count, and it has to be: evicting a live
  /// authority to save space is exactly the defect the authority exists to
  /// prevent. An entry is dead once [refReplicaWindow] has passed, so the live
  /// population is "branches this client wrote to in the last few seconds" —
  /// which bounds itself, provided the dead ones actually go. A dead entry is
  /// kept for [refLagWatch] more, deciding nothing, so that the first read
  /// after the window can say whether the answer it believed was one this
  /// client had written past. Then it is swept, on every write rather than only
  /// when a read happens to look at that key.
  final Map<String, _WriteAuthority> _authorities = {};

  /// How much tree [_snapshots] may hold, counted in entries across every
  /// cached branch.
  ///
  /// In entries rather than in snapshots, because snapshots differ by orders
  /// of magnitude: a bound of "eight branches" is meaningless for a repository
  /// with sixty thousand files and punishing for a workspace spanning twenty
  /// small ones. Counting the thing that actually consumes memory lets many
  /// small repositories coexist and caps one large one.
  ///
  /// The floor on the number is eviction's cost rather than memory: a snapshot
  /// dropped and wanted again costs a commit read and a tree read, and a sync
  /// tick touches *every* open document's branch — so a budget smaller than the
  /// working set makes every tick pay for the last one's evictions. A hundred
  /// thousand entries holds a workspace of twenty repositories of five thousand
  /// files each without ever evicting a branch that is in use.
  ///
  /// The ceiling is memory: an entry is a path, a sha, a mode and a size, so
  /// with the two strings it is a couple of hundred bytes, and the budget is
  /// something like twenty megabytes. That is a lot to hold and a little to
  /// cap — and capping it is the whole point, because the alternative is not a
  /// smaller cache but every tree the session ever read.
  ///
  /// Neither bound is measured, because the deciding quantity is how large the
  /// user's repositories are. So the cache **reports** instead
  /// ([diagnostics]): every eviction, and separately the case that means the
  /// budget is too small — see [thrashWindow]. The budget does not adapt to
  /// what is reported. A cache sized by recent request history would be a
  /// second control loop inside the sync loop; this one says what happened and
  /// a person decides.
  int maxCachedTreeEntries = 100000;

  /// How soon after its eviction a branch has to be wanted again for that to
  /// count as **thrash** rather than housekeeping.
  ///
  /// An eviction is ordinary: a repository opened this morning and not touched
  /// since is what the budget is for. A branch evicted and read again before
  /// the next poll would have come round is different — it was in use, the
  /// budget is below the working set, and every tick is paying a commit read
  /// and a tree read for the last tick's evictions. That is the signal
  /// [maxCachedTreeEntries] should be set from, so it is logged as a warning
  /// where an eviction is logged at debug.
  ///
  /// The default poll interval, as the stand-in for "one tick". The interval
  /// in force is the scheduler's business and may be shorter; a window that is
  /// too long reports a little thrash that was not, which is the cheaper error
  /// for a signal whose job is to be noticed.
  Duration thrashWindow = defaultThrashWindow;

  /// Five minutes: a sync loop's default poll interval, as the stand-in for
  /// one tick.
  static const defaultThrashWindow = Duration(seconds: 300);

  /// Where cache evictions are reported. A discard unless a
  /// composition root binds one.
  final TomDiagnostics diagnostics;

  /// How long a landed write out-ranks a ref read that contradicts it.
  ///
  /// GitHub serves ref reads from replicas and promises no read-after-write
  /// consistency, so for a short time after a save the ref can still name the
  /// commit the save replaced. Inside this window that answer is treated as
  /// stale; outside it, the ref is believed again — which is what keeps a
  /// genuine force-push rewind from being pinned out of sight forever.
  ///
  /// **Measured, 2026-09-17**, against a live repository over 85 write cycles
  /// (`wonecodeprpc13_replica_lag_live_test.dart`, which re-measures this on
  /// every live run). Each figure is the elapsed time at which a read was
  /// *issued* that came back truthful, so a round trip to api.github.com is
  /// excluded rather than counted as lag:
  ///
  /// * p50, p90, p99 — **0 ms**. A read issued the instant the write was
  ///   accepted was almost always already truthful.
  /// * **2 of 85** writes were answered stale at all.
  /// * The whole observed tail was **under one second** (293 ms and 902 ms).
  /// * A *second* client, on its own connection, saw the same rates and the
  ///   same tail — so the lag is a property of the service at that moment and
  ///   not of which replica a connection is pinned to.
  ///
  /// **Measured again under load, 2026-09-29**, because those 85 cycles were
  /// all taken in a repository nothing else was writing to, and the defect the
  /// window exists for was met while several writers were. Four runs of 85
  /// cycles each, the same day, in one repository — three in a row, and a
  /// fourth quiet one some hours later:
  ///
  /// | concurrent writers | their commits | stale at all | max |
  /// |---|---|---|---|
  /// | 0 | — | 0 of 85 | 0 ms |
  /// | 2 | 102 | 0 of 85 | 0 ms |
  /// | 4 | 154 | 0 of 85 | 0 ms |
  /// | 0 | — | 0 of 85 | 0 ms |
  ///
  /// The second client's arm matched in all four (one read at 1 ms in the
  /// first three, and one in the fourth). No
  /// writer was refused, so the load ran for the whole of each measurement.
  /// The writers committed to branches of their own; the timed branch has one
  /// writer by construction, since the authority covers our *own* write.
  ///
  /// What that settles and what it does not. Load in the repository did not
  /// produce a tail: 256 concurrent commits moved nothing. It does not show
  /// that load cannot *lengthen* a tail, because on that day there was no tail
  /// to lengthen — the quiet arms saw none either. Across all 425 measured
  /// cycles the longest read-back remains the 902 ms of the first run, so the
  /// floor stands where it was and the window stays at ten seconds.
  ///
  /// The distribution does not, by itself, set the number, and that is the
  /// substantive finding: it gives a floor, and the rest is the shape of the
  /// costs. Too short and an earlier defect returns — a head silently
  /// retracted, which is a correctness bug — and 425 writes are a sample,
  /// not a bound on what the service does. Too long costs remarkably
  /// little, because [_authoritative] refuses exactly two answers: the commit
  /// our own write superseded, and "no branch" after our own create. A rewind
  /// is therefore hidden only when the force-push lands *precisely* back on the
  /// commit we just replaced, and only from the client that made that write.
  ///
  /// So the band is [comfortably past a sub-second tail, comfortably inside the
  /// shortest poll interval a sync loop uses, one minute] — the upper bound
  /// being what makes "a rewind is noticed on the next poll" true. Ten seconds
  /// is eleven times the measured tail and a sixth of that interval. Both
  /// bounds are asserted: the floor by a live measurement, the ceiling by a
  /// test that needs no network.
  @visibleForTesting
  Duration refReplicaWindow = const Duration(seconds: 10);

  /// How long after [refReplicaWindow] has passed a write is still remembered,
  /// for reporting only.
  ///
  /// Past the window an answer naming a commit this client wrote past is
  /// believed — that is the window's trade-off. It is also the only evidence
  /// there is that a replica lagged longer than the window, and with the
  /// record gone nothing could say so: the read looks exactly like a peer
  /// having reverted the branch. So the record outlives its authority by this
  /// long, and the first read to meet it reports `github.ref.behind-believed`
  /// and retires it.
  ///
  /// Two minutes, because the read that would observe it is the next poll and
  /// the shortest interval the loop polls at is one minute.
  @visibleForTesting
  Duration refLagWatch = const Duration(minutes: 2);

  /// How long to hold off after a rate limit GitHub stated no instant for.
  ///
  /// From the `sync` group, delivered by the scheduler through
  /// [adoptBackoff]; [TomBackoffPolicy.defaults] until it is.
  TomBackoffPolicy get backoff => _backoff;
  TomBackoffPolicy _backoff = TomBackoffPolicy.defaults;

  @override
  void adoptBackoff(TomBackoffPolicy policy) => _backoff = policy;

  /// Samples the [backoff] jitter, in `[0, 1)`. Injectable for tests.
  double Function() jitterSource = _defaultJitter;

  static final _random = math.Random();

  static double _defaultJitter() => _random.nextDouble();

  /// The instant everything time-dependent in this backend is measured from.
  ///
  /// Injectable for the reason a sync scheduler's clock is: this layer
  /// *chooses* a wait ([backoff])
  /// and holds a write authority for [refReplicaWindow], so "wait until a
  /// stated time" is a behaviour here rather than a passthrough — and a
  /// behaviour measured against the real clock is either a sleep or a
  /// tolerance window, which hides the off-by-a-few-seconds regression it is
  /// wide enough to survive.
  final DateTime Function() _clock;

  /// The on-disk cache, or null for a backend that remembers only for
  /// the session.
  ///
  /// A **floor** under the in-memory caches rather than a replacement for
  /// them: everything above still decides what may be served, and this is
  /// where a snapshot is found when the process has never read the branch and
  /// where a blob is found when nobody has fetched it since launch.
  ///
  /// * A **blob** is served from here without asking, because its key is its
  ///   content.
  /// * A **snapshot** is never served from here on its own word. It supplies
  ///   the ETag for a conditional ref read and the tree for a ref that turns
  ///   out to name the commit it was taken at, so it saves the tree read and
  ///   not the question — except when the backend cannot be reached at all,
  ///   which is the offline read.
  /// * A **default branch** is asked for once per session, and read from here
  ///   only when that cannot be answered.
  final TomStorageCache? cache;

  /// Put before the commit messages this backend writes itself — `save <name>`,
  /// `delete <name>`, `initialize repository` — so an application can name
  /// itself in the repository's history (`myapp: save notes.yaml`). A message
  /// the caller passes to [commit] is used as it is.
  final String commitMessagePrefix;

  /// Branches whose durable snapshot has been looked for this session.
  ///
  /// Once per branch, so that a caller which *drops* the in-memory snapshot to
  /// force a read — a save does — gets a read, and not the dropped snapshot
  /// handed back from disk.
  final Set<String> _hydrated = {};

  /// A backend that authenticates from [tokens] on first use (and re-reads
  /// them on every request — see [authenticate]). [clientFactory] builds the
  /// client from the secret; the default reaches `api.github.com`.
  TomGitHubStorage({
    required TomTokenSource tokens,
    GitHubApiClient Function(String secret)? clientFactory,
    DateTime Function()? clock,
    this.diagnostics = const TomNullDiagnostics(),
    this.cache,
    this.commitMessagePrefix = '',
  }) : _tokens = tokens,
       _clientFactory = clientFactory ?? _defaultClient,
       _clock = clock ?? _utcNow;

  /// A backend over an already-authenticated client. For tests and for a
  /// caller that obtained a token some other way.
  TomGitHubStorage.withClient(
    GitHubApiClient client, {
    DateTime Function()? clock,
    this.diagnostics = const TomNullDiagnostics(),
    this.cache,
    this.commitMessagePrefix = '',
  }) : _tokens = null,
       _clientFactory = null,
       _client = client,
       _clock = clock ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  static GitHubApiClient _defaultClient(String secret) =>
      GitHubApiClient(token: secret);

  @override
  bool handles(String locator) => TomGitHubLocator.matches(locator);

  /// `github/<owner>/<repo>`: tree listings and the default branch are kept
  /// per repository, so a location naming a folder answers its repository.
  /// Parsed leniently, because a location may name the repository root
  /// (`github:owner/repo`), which is no document locator.
  @override
  List<String>? cacheMetaScope(String location) {
    if (!handles(location)) return null;
    final segments = location
        .substring(TomGitHubLocator.scheme.length)
        .split('/');
    if (segments.length < 2 || segments[0].isEmpty) return null;
    final repo = segments[1].split('@').first;
    if (repo.isEmpty) return null;
    return [_metaRoot, segments[0], repo];
  }

  @override
  int? get maxObjectBytes => maxBlobBytes;

  @override
  Future<List<TomStorageEntry>> list(String locator) async {
    final loc = await _locate(locator);
    final snapshot = await _snapshot(loc);
    // A blob at the path is a single-file container; anything else — a
    // subtree, or nothing — is read as a directory, whose files are the blobs
    // under it. For a path that holds nothing both readings are "not found".
    final entry = snapshot?.entryAt(loc.path);
    if (entry != null && entry.type == 'blob') {
      return [
        TomStorageEntry(
          name: _basename(loc.path),
          path: TomChangeset.containerPath,
          kind: TomEntryKind.file,
          revision: entry.sha,
        ),
      ];
    }

    final blobs = snapshot?.tree.blobsUnder(loc.path) ?? const {};
    if (blobs.isEmpty) throw TomContainerNotFoundException(locator);
    final entries = [
      for (final blob in blobs.entries)
        TomStorageEntry(
          name: _basename(blob.key),
          path: blob.key,
          kind: TomEntryKind.file,
          revision: blob.value.sha,
        ),
    ]..sort((a, b) => a.path.compareTo(b.path));
    return entries;
  }

  @override
  Future<Uint8List> readBytes(String locator) async {
    final loc = await _locate(locator);
    final snapshot = await _snapshot(loc);
    final sha = snapshot?.entryAt(loc.path)?.sha;
    if (sha == null) throw TomContainerNotFoundException(locator);
    return _readBlob(loc, locator, loc.path, sha);
  }

  /// One blob, refused when what the tree holds is a Git-LFS pointer.
  ///
  /// Both read paths go through here so the check cannot be present on one and
  /// absent on the other — which is how a defect of exactly this shape returns.
  /// [_readBlob] for the lazy medium, which is a separate object and so
  /// cannot reach a private member.
  Future<Uint8List> readBlobAt(
    TomGitHubLocator loc,
    String locator,
    String path,
    String sha,
  ) => _readBlob(loc, locator, path, sha);

  Future<Uint8List> _readBlob(
    TomGitHubLocator loc,
    String locator,
    String path,
    String sha,
  ) async {
    // Content-addressed, so a hit needs no revalidation — and no
    // LFS check either, since only bytes that passed it are stored.
    final held = await cache?.readBlob(sha, owner: locator);
    if (held != null) return held;
    await authenticate();
    final bytes = await _wrap(
      locator,
      'read $path',
      () => _api.git.getBlob(owner: loc.owner, repo: loc.repo, sha: sha),
    );
    tomRefuseLfsPointer(locator, path, bytes, remedy: _lfsRemedy);
    await cache?.writeBlob(sha, bytes, opaque: _isOpaque(path), owner: locator);
    return bytes;
  }

  /// Whether the file at [path] is already encrypted, and so is cached as the
  /// bytes it is.
  ///
  /// By suffix rather than by format detection: most paths read here are
  /// members of a bundle, which are not documents and have no format.
  static bool _isOpaque(String path) => path.toLowerCase().endsWith('.kdbx');

  static const _metaRoot = 'github';

  static List<String> _snapshotKey(TomGitHubLocator loc) => [
    _metaRoot,
    loc.owner,
    loc.repo,
    'branches',
    loc.branch!,
  ];

  static List<String> _defaultBranchKey(TomGitHubLocator loc) => [
    _metaRoot,
    loc.owner,
    loc.repo,
    'default-branch',
  ];

  /// Gives [snapshot] its durable floor.
  Future<void> _remember(TomGitHubLocator loc, _TreeSnapshot snapshot) async {
    await cache?.writeMeta(_snapshotKey(loc), snapshot.toRecord());
  }

  /// The durable snapshot for [loc], read at most once per session.
  Future<_TreeSnapshot?> _hydrate(TomGitHubLocator loc) async {
    final held = cache;
    if (held == null || !_hydrated.add(loc.repoKey)) return null;
    final record = await held.readMeta(_snapshotKey(loc));
    return record == null ? null : _TreeSnapshot.fromRecord(record);
  }

  /// What a reader can actually do about it here — which is not "fetch it
  /// anyway". LFS is a separate protocol with its own endpoint and its own
  /// authorization, and the honest answer for this backend is a clear refusal
  /// rather than a second client nobody asked for.
  static const _lfsRemedy =
      'Files are read through the GitHub REST API, which does not resolve '
      'LFS pointers; store this path outside LFS to open it here.';

  /// A medium that fetches a member **when it is asked for**.
  ///
  /// It used to fetch every blob under the container path before returning,
  /// which made a save cost the document's whole edit history: `.history/`
  /// lives under that path, so a one-word change to a 200-section document
  /// with a year of snapshots pulled thousands of blobs to decide it needed to
  /// write one. The listing is one request and answers `listFiles` and
  /// `exists`; only the files a caller actually reads cost a `getBlob`, so a
  /// save is proportional to the sections it compares and never touches
  /// `.history/` at all.
  ///
  /// Not detached any more, and it cannot be — a lazy medium is a live view by
  /// definition. The guarantee that nothing reaches the repository until
  /// `commit` moved to `TomRecordingBundleMedium`, which buffers writes and is
  /// what every save goes through.
  @override
  Future<TomBundleMedium> readBundle(String locator) async {
    final loc = await _locate(locator);
    final snapshot = await _snapshot(loc);
    final blobs = snapshot?.tree.blobsUnder(loc.path) ?? const {};
    if (blobs.isEmpty) throw TomContainerNotFoundException(locator);
    return TomReadOnlyBundleMedium(
      _LazyBlobMedium(
        storage: this,
        loc: loc,
        locator: locator,
        shas: {for (final blob in blobs.entries) blob.key: blob.value.sha!},
      ),
    );
  }

  @override
  Future<String> commit(
    String locator,
    TomChangeset changeset, {
    String? expectedHead,
    String? message,
    TomCommitProgressSink? onProgress,
  }) async {
    tomGuardChangeset(locator, changeset, this);
    final loc = await _locate(locator);
    // Force a refresh: a stale snapshot would let a lost race through.
    _snapshots.remove(loc.repoKey);
    var snapshot = await _snapshot(loc);

    if (snapshot == null && _emptyRepos.contains(loc.repoSlug)) {
      // Give the repository its first commit *before* uploading anything: in a
      // repository with no commits, every git-data write is refused, so the
      // save would otherwise fail on its first blob.
      await _bootstrapRepository(loc);
      _snapshots.remove(loc.repoKey);
      snapshot = await _snapshot(loc);
    }

    final actualHead = snapshot?.objectShaFor(loc.path);
    if (actualHead != expectedHead) {
      throw TomCasConflictException(
        locator,
        expectedHead: expectedHead,
        actualHead: actualHead,
      );
    }
    if (changeset.isEmpty) return actualHead ?? TomStorage.emptyHead;

    // Reported before each object and once more after the last, so a reader
    // learns *what* is in flight and how large it is, not only how much has
    // landed. The two matter separately: a twelve-object changeset moves the
    // bar twelve times, and a one-object changeset near the blob ceiling moves
    // it not at all — and for that one, naming the object is the whole of the
    // difference between "hung" and "sending 41.8 MB".
    var bytesDone = 0;
    var objectsDone = 0;
    final bytesTotal = changeset.writes.values.fold<int>(
      0,
      (sum, bytes) => sum + bytes.length,
    );
    final objectsTotal = changeset.writes.length;

    final entries = <GitHubTreeEntry>[];
    // What this save uploaded, by the sha GitHub gave it — stored once the
    // commit has landed, so the next read of what was just written round-trips
    // nothing.
    final written = <String, ({String path, Uint8List bytes})>{};
    for (final write in changeset.writes.entries) {
      final path = write.key == TomChangeset.containerPath
          ? loc.path
          : '${loc.path}/${write.key}';
      onProgress?.call(
        TomCommitProgress(
          bytesCompleted: bytesDone,
          bytesTotal: bytesTotal,
          objectsCompleted: objectsDone,
          objectsTotal: objectsTotal,
          currentPath: write.key,
          currentBytes: write.value.length,
        ),
      );
      final sha = await _wrap(
        locator,
        'upload $path',
        () => _api.git.createBlob(
          owner: loc.owner,
          repo: loc.repo,
          bytes: write.value,
        ),
      );
      bytesDone += write.value.length;
      objectsDone++;
      entries.add(GitHubTreeEntry(path: path, sha: sha));
      written[sha] = (path: path, bytes: write.value);
    }
    // `currentPath` drops to null while the tree, commit and ref steps run.
    // That is not "done" — the ref has not moved — and a reader that renders
    // it as "finishing" is telling the truth.
    onProgress?.call(
      TomCommitProgress(
        bytesCompleted: bytesDone,
        bytesTotal: bytesTotal,
        objectsCompleted: objectsDone,
        objectsTotal: objectsTotal,
      ),
    );
    for (final delete in changeset.deletes) {
      entries.add(GitHubTreeEntry.deletion('${loc.path}/$delete'));
    }

    return _wrap(locator, 'commit', () async {
      final tree = await _api.git.createTree(
        owner: loc.owner,
        repo: loc.repo,
        entries: entries,
        baseTreeSha: snapshot?.treeSha,
      );
      final commit = await _api.git.createCommit(
        owner: loc.owner,
        repo: loc.repo,
        message: message ?? '${commitMessagePrefix}save ${_basename(loc.path)}',
        treeSha: tree.sha,
        parentShas: [if (snapshot != null) snapshot.commitSha],
      );
      try {
        if (snapshot == null) {
          await _api.git.createRef(
            owner: loc.owner,
            repo: loc.repo,
            ref: loc.refName,
            sha: commit.sha,
          );
        } else {
          await _api.git.updateRef(
            owner: loc.owner,
            repo: loc.repo,
            ref: loc.refName,
            sha: commit.sha,
          );
        }
        _recordAuthority(loc, commit.sha, tree.sha, snapshot?.commitSha);
      } on GitHubValidationException {
        // The branch moved between our read and this update — GitHub refused
        // the non-fast-forward. Not necessarily *our* document (the object-sha
        // check passed), but our commit is now unreachable, so the caller
        // re-reads, merges and retries, exactly as for any other lost race.
        _snapshots.remove(loc.repoKey);
        final head = (await _snapshot(loc))?.objectShaFor(loc.path);
        throw TomCasConflictException(
          locator,
          expectedHead: expectedHead,
          actualHead: head,
        );
      }
      // The branch now points at `commit`, and we know both it and the tree
      // beneath it — so the new head is a fact we hold, not one to go and
      // fetch. Re-reading the ref would cost three requests *and* make the
      // answer depend on GitHub serving our own write straight back to us,
      // which it does not promise: under concurrent traffic on a repository
      // the ref read can still answer with the commit we just replaced, and a
      // head that has not moved is indistinguishable from a save that did
      // nothing. The tree is fetched by sha instead, and a sha is content —
      // that read cannot be stale.
      final full = await _api.git.getTree(
        owner: loc.owner,
        repo: loc.repo,
        sha: tree.sha,
        recursive: true,
      );
      if (full.truncated) {
        throw TomStorageException(
          locator,
          'The repository tree is too large for a single listing; this backend '
          'cannot resolve document paths in it',
        );
      }
      // No ETag, because we never read the ref: the next poll of this branch
      // pays one full read. That is once per write, against a write that has
      // just cost several requests anyway — and that read is exactly the one
      // a replica can answer with the commit we just replaced, which is why
      // the write is also recorded as an authority above.
      final landed = _TreeSnapshot(
        commitSha: commit.sha,
        treeSha: tree.sha,
        tree: full,
      );
      _snapshots[loc.repoKey] = landed;
      await _remember(loc, landed);
      for (final blob in written.entries) {
        await cache?.writeBlob(
          blob.key,
          blob.value.bytes,
          opaque: _isOpaque(blob.value.path),
          owner: locator,
        );
      }
      final head = landed.objectShaFor(loc.path);
      if (head == null) {
        throw TomStorageException(
          locator,
          'The commit landed but left nothing at ${loc.path}',
        );
      }
      return head;
    });
  }

  @override
  Future<void> delete(String locator) async {
    final loc = await _locate(locator);
    _snapshots.remove(loc.repoKey);
    final snapshot = await _snapshot(loc);
    if (snapshot == null) return;

    final entry = snapshot.entryAt(loc.path);
    final paths = entry != null && entry.type == 'blob'
        ? [loc.path]
        : [
            for (final blob in snapshot.tree.blobsUnder(loc.path).keys)
              '${loc.path}/$blob',
          ];
    if (paths.isEmpty) return;

    await _wrap(locator, 'delete', () async {
      final tree = await _api.git.createTree(
        owner: loc.owner,
        repo: loc.repo,
        entries: [for (final path in paths) GitHubTreeEntry.deletion(path)],
        baseTreeSha: snapshot.treeSha,
      );
      final commit = await _api.git.createCommit(
        owner: loc.owner,
        repo: loc.repo,
        message: '${commitMessagePrefix}delete ${_basename(loc.path)}',
        treeSha: tree.sha,
        parentShas: [snapshot.commitSha],
      );
      await _api.git.updateRef(
        owner: loc.owner,
        repo: loc.repo,
        ref: loc.refName,
        sha: commit.sha,
      );
      // Same reason as on a save: without this, a replica still serving the
      // pre-delete commit would report the document as present again.
      _recordAuthority(loc, commit.sha, tree.sha, snapshot.commitSha);
      _snapshots.remove(loc.repoKey);
      // The listing on disk still names what was just deleted, and offline it
      // would be served.
      await cache?.removeMeta(_snapshotKey(loc));
    });
  }

  @override
  Future<String?> headOf(String locator) async {
    final loc = await _locate(locator);
    return (await _snapshot(loc))?.objectShaFor(loc.path);
  }

  /// Groups locators by repository and branch so every open document on one
  /// branch is answered from a single snapshot — and, when nothing has moved,
  /// from a single conditional request that costs no rate-limit quota.
  @override
  Future<Map<String, String?>> headsOf(Iterable<String> locators) async {
    final byRepo = <String, List<_Request>>{};
    final heads = <String, String?>{};
    for (final locator in locators) {
      final loc = await _locate(locator);
      byRepo.putIfAbsent(loc.repoKey, () => []).add(_Request(locator, loc));
    }
    for (final group in byRepo.values) {
      final snapshot = await _snapshot(group.first.locator);
      for (final request in group) {
        // Keyed by the caller's own string, not by the parsed locator's:
        // resolving the branch rewrites it, and a caller looking its own
        // locator up in the result must find it.
        heads[request.raw] = snapshot?.objectShaFor(request.locator.path);
      }
    }
    return heads;
  }

  @override
  void close() {
    _dropClient();
    _snapshots.clear();
    _defaultBranches.clear();
    _authorities.clear();
    // `_emptyRepos` was missing here, which is the shape a fourth cache added
    // to a list of three takes: every other site that touches the group was
    // updated and this one was not.
    _emptyRepos.clear();
    _hydrated.clear();
  }

  /// What this backend's own HTTP client has spent, and how much of it was
  /// free.
  ///
  /// Exposed because the cheapness claim could not otherwise be asserted. The
  /// quota GitHub publishes is counted per **token**, and the live suites
  /// share one while `dart test` runs their files concurrently — so an
  /// assertion against that counter reads every other suite's traffic too,
  /// which is exactly the cross-suite entanglement the per-run scratch branch
  /// was introduced to remove. Per instance, the question has an answer.
  ///
  /// `requests == notModified` over a stretch of polling is the cheapness
  /// claim stated in observable terms: GitHub does not charge a conditional
  /// request it answers `304`, so a poll that issues nothing but 304s costs no
  /// quota without anyone reading a quota counter.
  ///
  /// A test seam: no surface shows it, so it is the suites' instrument — the
  /// live budget measurements and the poll-cheapness checks read it. A
  /// diagnostics surface that wanted to say "this session has issued N
  /// requests, M of them free" would make it product surface, and the
  /// annotation would go.
  @visibleForTesting
  ({int requests, int notModified}) get requestCounts =>
      _client?.requestCounts ?? (requests: 0, notModified: 0);

  /// Zero the tally, to measure one stretch of traffic.
  @visibleForTesting
  void resetRequestCounts() => _client?.resetRequestCounts();

  /// What this client is currently holding, for the tests that assert it is
  /// bounded.
  ///
  /// A seam rather than an assertion through behaviour, because the property
  /// is about memory and memory is not observable through the API: a cache
  /// that never evicted would answer every request exactly as one that did.
  /// Kept as narrow as that argument justifies — sizes, nothing else.
  @visibleForTesting
  ({
    int snapshots,
    int treeEntries,
    int defaultBranches,
    int emptyRepos,
    int authorities,
    int evictionsRemembered,
  })
  get cacheSizes => (
    evictionsRemembered: _snapshots.evictionsRemembered,
    snapshots: _snapshots.length,
    treeEntries: _snapshots.heldEntries,
    defaultBranches: _defaultBranches.length,
    emptyRepos: _emptyRepos.length,
    authorities: _authorities.length,
  );

  // ── Internals ───────────────────────────────────────────────────────────

  GitHubApiClient get _api {
    final client = _client;
    if (client == null) {
      throw StateError(
        'The GitHub client has not been authenticated yet; call '
        'authenticate() (or any storage operation, which awaits it) first.',
      );
    }
    return client;
  }

  /// Resolves the credential, lazily and on every request.
  ///
  /// Lazily, because constructing a backend must not require a network call or
  /// an unlocked settings container — the app wires storage up long before the
  /// user opens anything from GitHub.
  ///
  /// On every request rather than once, because the credential is the user's
  /// to change while the backend lives: a token replaced in the Settings area
  /// or by a sign-in must be the one the next request carries, and a revoked
  /// one — a sign-out — must stop being carried then, not when the service
  /// gets round to refusing it. The source is asked each time (an in-memory
  /// lookup on every root); the client is rebuilt only when the secret
  /// differs, so its own conditional-request state survives an unchanged
  /// answer. A backend built [TomGitHubStorage.withClient] has no source
  /// and keeps the client it was given.
  @visibleForTesting
  Future<void> authenticate() async {
    final tokens = _tokens;
    if (tokens == null) return;
    final token = await tokens.tokenFor(host);
    if (token == null) {
      _dropClient();
      throw const TomTokenRequiredException(host);
    }
    if (_client != null && _clientSecret == token.secret) return;
    _dropClient();
    _client = _clientFactory!(token.secret);
    _clientSecret = token.secret;
  }

  void _dropClient() {
    _client?.close();
    _client = null;
    _clientSecret = null;
  }

  /// Parses [locator] and gives it a concrete branch.
  ///
  /// A locator that names no branch means "the repository's default branch",
  /// which is not necessarily `main` — a repository may be on `master`, or on
  /// anything its owner chose. Guessing would address the wrong ref and, on a
  /// save, create the guessed branch. So the default is read from the API, once
  /// per repository per session.
  Future<TomGitHubLocator> _locate(String locator) async {
    final parsed = TomGitHubLocator.parse(locator);
    if (parsed.isResolved) return parsed;
    await authenticate();
    final cached = _defaultBranches[parsed.repoSlug];
    if (cached != null) return parsed.withBranch(cached);
    final String branch;
    try {
      branch = await _wrap(
        locator,
        'read the default branch of ${parsed.repoSlug}',
        () => _api.getDefaultBranch(owner: parsed.owner, repo: parsed.repo),
      );
    } on TomUnreachableException {
      // Asked first and read from disk only when nobody answers: a default
      // branch can be changed, and there is no conditional form of the
      // question that would let the stored answer be confirmed for free.
      final record = await cache?.readMeta(_defaultBranchKey(parsed));
      final remembered = record?['branch'];
      if (remembered is! String) rethrow;
      return parsed.withBranch(remembered);
    }
    _defaultBranches[parsed.repoSlug] = branch;
    await cache?.writeMeta(_defaultBranchKey(parsed), {'branch': branch});
    return parsed.withBranch(branch);
  }

  /// Gives a repository with no commits its first one.
  ///
  /// A repository created and never pushed to has no refs, and GitHub refuses
  /// **every** git-data write against it — not just the ref update at the end,
  /// but the very first blob. The contents API is the one endpoint that can
  /// author an initial commit, so it is used for exactly that and for nothing
  /// else: documents are still saved through the git data API, so there is
  /// still one compare-and-swap mechanism.
  ///
  /// The commit always lands on the repository's **default** branch, whatever
  /// branch the document is addressed on. An empty repository's HEAD names a
  /// branch that does not exist yet, and that is the only branch the contents
  /// API will create; a document on some other branch then gets its own ref
  /// from the ordinary create path once blobs are writable.
  Future<void> _bootstrapRepository(TomGitHubLocator loc) async {
    final locator = loc.toString();
    final branch =
        _defaultBranches[loc.repoSlug] ??
        await _wrap<String>(
          locator,
          'read the default branch of ${loc.repoSlug}',
          () => _api.getDefaultBranch(owner: loc.owner, repo: loc.repo),
        );
    _defaultBranches[loc.repoSlug] = branch;

    final created = await _wrap(
      locator,
      'initialize ${loc.repoSlug}',
      () => _api.contents.writeFile(
        owner: loc.owner,
        repo: loc.repo,
        path: 'README.md',
        message: '${commitMessagePrefix}initialize repository',
        bytes: Uint8List.fromList(utf8.encode('# ${loc.repo}\n')),
        branch: branch,
      ),
    );
    _emptyRepos.remove(loc.repoSlug);

    // A bootstrap is a ref write like any other, so it is knowledge like any
    // other. Without this the next read — which a replica may answer "no
    // branch", exactly as it does after a `createRef` — is believed, and the
    // save that follows builds a **parentless** commit and tries to create a
    // ref that already exists. GitHub refuses that with 422, the store reads a
    // container that is not there yet, and a user's first save into a fresh
    // repository fails outright rather than merely costing a round trip.
    //
    // Recorded only when the bootstrap landed on the branch being addressed.
    // The contents API can only author onto the repository's default branch,
    // so a document addressed at some other branch genuinely has no ref yet and
    // the create path below is right for it — an authority recorded here would
    // be a claim about a branch this write never touched.
    if (branch == loc.branch) {
      _recordAuthority(loc, created.commitSha, created.treeSha, null);
    }
  }

  /// The branch's tree, from cache when the ref has not moved.
  ///
  /// Null means the branch does not exist yet, which is how a document is
  /// created in an empty repository.
  Future<_TreeSnapshot?> _snapshot(TomGitHubLocator loc) async {
    final pass = Zone.current[_passKey] as _Pass?;
    if (pass == null) return _validatedSnapshot(loc);

    // Identity, not equality: the pass vouches for the very object it
    // validated. A save drops the cache before it reads, and a landed commit
    // installs a snapshot of its own, so in both cases what is cached is no
    // longer what the pass saw and the ref is asked again.
    final cached = _snapshots[loc.repoKey];
    if (cached != null && identical(pass.validated[loc.repoKey], cached)) {
      return cached;
    }
    final snapshot = await _validatedSnapshot(loc);
    if (snapshot == null) {
      pass.validated.remove(loc.repoKey);
    } else {
      pass.validated[loc.repoKey] = snapshot;
    }
    return snapshot;
  }

  /// Distinguishes this instance's passes from another's: the key is the
  /// zone value's name, and two backends over one repository are two clients.
  final Object _passKey = Object();

  @override
  Future<T> withinPass<T>(Future<T> Function() body) {
    // A pass inside a pass is the same pass. The scheduler opens one per
    // backend around the whole tick; anything nested adds no knowledge.
    if (Zone.current[_passKey] != null) return body();
    return runZoned(body, zoneValues: {_passKey: _Pass()});
  }

  /// [_snapshot] as it is outside a pass: one conditional ref read, always.
  Future<_TreeSnapshot?> _validatedSnapshot(TomGitHubLocator loc) async {
    await authenticate();
    final cached = _snapshots[loc.repoKey] ?? await _hydrate(loc);
    final locator = loc.toString();

    return _wrap(locator, 'read ${loc.repoKey}', () async {
      final GitHubConditional<GitHubGitRef> ref;
      try {
        ref = await _api.git.getRefConditional(
          owner: loc.owner,
          repo: loc.repo,
          ref: loc.refName,
          ifNoneMatch: cached?.refEtag,
        );
      } on GitHubNotFoundException {
        // "No such branch" is the same answer a replica gives when it has not
        // seen the ref we ourselves created moments ago — and believing it
        // would retract a document that demonstrably exists.
        return _authoritative(loc, null);
      } on GitHubException catch (error) {
        // 409 "Git Repository is empty." A repository with no commits has no
        // refs at all, so the ref read fails differently than it does for a
        // branch that merely has not been created — but to a *reader* the
        // situation is the same one, and it is the situation a user is in the
        // moment they make a repository for their documents. Anything other
        // than null here makes "point the app at a fresh repo" fail on the
        // first read.
        //
        // To a *writer* the two are not the same, which is why the fact is
        // remembered rather than merely absorbed: an empty repository refuses
        // every git-data write, not just the ref update (see
        // [_bootstrapRepository]).
        if (error.statusCode == 409) {
          _emptyRepos.add(loc.repoSlug);
          return null;
        }
        rethrow;
      } on FormatException {
        rethrow;
      } on Exception catch (error) {
        // No answer at all, as distinct from a refusal — and the one case in
        // which what the device holds is served unvalidated. A save
        // that reaches here with a snapshot still fails: its first upload
        // meets the same silence, and the store journals it.
        if (cached == null) rethrow;
        diagnostics.log(
          TomDiagnosticEvent(
            operation: 'github.snapshot.served-offline',
            level: TomDiagnosticLevel.info,
            at: _clock(),
            fields: {
              'branch': loc.repoKey,
              'error': error.runtimeType.toString(),
            },
          ),
        );
        return _snapshots[loc.repoKey] = cached;
      }
      if (ref.notModified && cached != null) {
        // A snapshot that came from disk is in memory from here on.
        _snapshots[loc.repoKey] = cached;
        // A 304 says the *replica* has not moved since that snapshot — not
        // that the branch has not. If this client has since written past the
        // cached commit, the cache is history. That happens: a read that began
        // before our commit and finished after it installs the older snapshot
        // over the one the commit landed. Checked here rather than at install
        // time because every use of the cache sits behind a ref read, so this
        // is the one place a stale cache could be served, whatever put it
        // there.
        return await _authoritative(loc, cached.commitSha) ?? cached;
      }

      final overridden = await _authoritative(loc, ref.value!.sha);
      if (overridden != null) return overridden;

      if (cached != null && cached.commitSha == ref.value!.sha) {
        // The ref names the commit the tree was listed at, and a commit's
        // tree does not change: the listing is current, and all that was
        // missing is the ETag that lets the next read ask for free.
        final confirmed = cached.withEtag(ref.etag);
        _snapshots[loc.repoKey] = confirmed;
        await _remember(loc, confirmed);
        return confirmed;
      }

      final commit = await _api.git.getCommit(
        owner: loc.owner,
        repo: loc.repo,
        sha: ref.value!.sha,
      );
      final tree = await _api.git.getTree(
        owner: loc.owner,
        repo: loc.repo,
        sha: commit.treeSha,
        recursive: true,
      );
      if (tree.truncated) {
        throw TomStorageException(
          locator,
          'The repository tree is too large for a single listing; this backend '
          'cannot resolve document paths in it',
        );
      }
      final snapshot = _TreeSnapshot(
        commitSha: commit.sha,
        treeSha: commit.treeSha,
        tree: tree,
        refEtag: ref.etag,
      );
      _snapshots[loc.repoKey] = snapshot;
      await _remember(loc, snapshot);
      return snapshot;
    });
  }

  /// Remembers that we moved this branch from [superseded] to [commitSha].
  ///
  /// A ref write is compare-and-swapped against the primary, so once it is
  /// accepted the branch is at [commitSha] and [superseded] is history. That is
  /// knowledge a subsequent *read* cannot improve on and can only contradict.
  void _recordAuthority(
    TomGitHubLocator loc,
    String commitSha,
    String treeSha,
    String? superseded,
  ) {
    // Sweep first. A record is finished once `refReplicaWindow` and
    // `refLagWatch` have both passed, but `_authoritative` only ever retires
    // the key it was asked about — so a branch written once and never read
    // again kept its record for the life of the process. Doing it here costs a
    // walk of a map whose population is "branches written in the last few
    // minutes".
    final now = _clock();
    final kept = refReplicaWindow + refLagWatch;
    _authorities.removeWhere(
      (_, held) => now.difference(held.landedAt) >= kept,
    );
    // Extend the chain when this write continues from our own previous head;
    // start afresh when someone else moved the branch in between, since their
    // commits are not ours to call history. A record that is only being
    // watched has no chain to extend: its commits are past the window.
    final held = _authorities[loc.repoKey];
    final previous =
        held != null && now.difference(held.landedAt) < refReplicaWindow
        ? held
        : null;
    _authorities[loc.repoKey] = _WriteAuthority(
      commitSha: commitSha,
      treeSha: treeSha,
      superseded: {
        if (previous != null && previous.commitSha == superseded)
          ...previous.superseded,
        superseded,
      },
      landedAt: now,
    );
  }

  /// The snapshot to serve instead of a ref answer we can prove is historical,
  /// or null when [refSha] should simply be believed.
  ///
  /// [refSha] is null for a 404 — the shape a replica takes when it has not
  /// seen a ref *create* yet.
  ///
  /// **What is guaranteed.** Within [refReplicaWindow] of this client's last
  /// accepted write to the branch, no answer naming a commit this client wrote
  /// past is believed — any of them, not only the last one, so two quick
  /// writes do not leave the commit two behind trusted — and neither is "no
  /// branch" after our write created it. Git moves a ref forward and the
  /// primary accepted each update from its parent, so none of those answers can
  /// describe the current branch. The same rule applies to a cached snapshot a
  /// `304` would otherwise serve.
  ///
  /// **What is not.** Anything else — including a third party's commit on top
  /// of ours — is believed immediately, so this narrows what we trust rather
  /// than widening it. And after the window, a replica still serving history
  /// *is* believed: the window is what lets a genuine force-push rewind be
  /// honoured rather than pinned out of sight. A replica lagging longer than
  /// the window therefore can answer with the branch as it was before our
  /// write; the window's floor is the measured replica tail, and a test
  /// reproduces the boundary.
  ///
  /// **What is said.** Both decisions are reported to [diagnostics], because
  /// the knowledge exists only here and only at this moment: a refused answer
  /// as `github.ref.behind-refused` (info — the guard working is not a fault),
  /// and an answer believed although this client had written past it as
  /// `github.ref.behind-believed` (warn). The second is either a replica that
  /// lagged longer than the window or a force-push back onto that commit; the
  /// storage cannot tell which, and says what it saw. Commit ids and an age,
  /// never content.
  Future<_TreeSnapshot?> _authoritative(
    TomGitHubLocator loc,
    String? refSha,
  ) async {
    final authority = _authorities[loc.repoKey];
    if (authority == null) return null;
    final now = _clock();
    final age = now.difference(authority.landedAt);
    final behind = authority.superseded.contains(refSha);
    Map<String, Object?> fields() => {
      'branch': loc.repoKey,
      'ref': refSha ?? 'absent',
      'head': authority.commitSha,
      'ageMs': age.inMilliseconds,
      'windowMs': refReplicaWindow.inMilliseconds,
    };
    if (age >= refReplicaWindow) {
      // Its authority is over, and so is the watch: one report per write.
      _authorities.remove(loc.repoKey);
      if (behind) {
        diagnostics.log(
          TomDiagnosticEvent(
            operation: 'github.ref.behind-believed',
            level: TomDiagnosticLevel.warn,
            at: now,
            fields: fields(),
          ),
        );
      }
      return null;
    }
    if (!behind) return null;
    diagnostics.log(
      TomDiagnosticEvent(
        operation: 'github.ref.behind-refused',
        level: TomDiagnosticLevel.info,
        at: now,
        fields: fields(),
      ),
    );

    final cached = _snapshots[loc.repoKey];
    if (cached != null && cached.commitSha == authority.commitSha)
      return cached;

    // The cache was dropped (a save clears it before re-reading), so the tree
    // is fetched again — but *by sha*, and a sha is content, so this read
    // cannot be stale in the way the ref read just was.
    final tree = await _api.git.getTree(
      owner: loc.owner,
      repo: loc.repo,
      sha: authority.treeSha,
      recursive: true,
    );
    if (tree.truncated) {
      throw TomStorageException(
        loc.toString(),
        'The repository tree is too large for a single listing; this backend '
        'cannot resolve document paths in it',
      );
    }
    // No ETag: we never validated the ref, so the next call must ask again.
    final snapshot = _TreeSnapshot(
      commitSha: authority.commitSha,
      treeSha: authority.treeSha,
      tree: tree,
    );
    _snapshots[loc.repoKey] = snapshot;
    return snapshot;
  }

  /// Turns a GitHub-shaped failure into a storage-shaped one, so callers
  /// handle one exception family regardless of which backend they are on.
  Future<T> _wrap<T>(
    String locator,
    String operation,
    Future<T> Function() body,
  ) async {
    try {
      return await body();
    } on TomStorageException {
      rethrow;
    } on GitHubAuthException catch (error) {
      // The client holds the refused token; dropping it is what lets a token
      // the user enters next take effect instead of being shadowed by this one.
      _dropClient();
      throw TomTokenRejectedException(
        locator,
        host,
        'GitHub refused the credential on $operation',
        cause: error,
      );
    } on GitHubSecondaryRateLimitException catch (error) {
      // A secondary limit is rate limiting even though its headers say
      // otherwise — the primary quota is untouched, so the response is
      // byte-for-byte an authorization failure and only the body disagrees.
      // Reported as rate limiting because that is what the sync loop must do
      // about it: back off and retry, not go and check the token.
      throw _rateLimited(locator, error);
    } on GitHubRateLimitException catch (error) {
      // Ahead of the generic arm on purpose: a quota refusal carries a *when*,
      // and flattening it into a plain storage failure is what made the sync
      // loop report a healthy-but-throttled remote as offline.
      throw _rateLimited(locator, error);
    } on GitHubException catch (error) {
      throw TomStorageException(
        locator,
        'GitHub could not $operation',
        cause: error,
      );
    } on FormatException catch (error) {
      // An answer, and an unreadable one — which is not silence, so it is not
      // something a cached copy may stand in for.
      throw TomStorageException(
        locator,
        'GitHub answered $operation with something that could not be read',
        cause: error,
      );
    } on Exception catch (error) {
      // Not GitHub's answer but the absence of one: the transport failed
      // before a response existed. Named, because it is the one failure a
      // cached copy may stand in for, and because a raw socket error would
      // pass every `on TomStorageException` between here and the shell.
      throw TomUnreachableException(
        locator,
        'GitHub could not be reached to $operation',
        cause: error,
      );
    }
  }

  /// [error] as the wait it calls for ([tomGitHubWaitOf]).
  TomRateLimitException _rateLimited(String locator, GitHubException error) {
    final wait = tomGitHubWaitOf(
      error,
      backoff: _backoff,
      now: _clock(),
      jitterSample: jitterSource(),
    )!;
    return TomRateLimitException(
      locator,
      kind: wait.kind,
      resetAt: wait.until,
      cause: error,
    );
  }

  static String _basename(String path) {
    final slash = path.lastIndexOf('/');
    return slash < 0 ? path : path.substring(slash + 1);
  }
}

/// A caller's locator string paired with its resolved form, so a batched
/// answer can be keyed by what the caller actually asked with.
class _Request {
  final String raw;
  final TomGitHubLocator locator;

  const _Request(this.raw, this.locator);
}

/// What one accepted ref write established about a branch.
///
/// Not a cache — a fact. The primary refused to move the ref unless our commit
/// descended from the head it replaced, so afterwards the branch *is* at
/// [commitSha] and everything in [superseded] is behind it; a read that
/// answers with one of those is behind, not newer.
class _WriteAuthority {
  final String commitSha;
  final String treeSha;

  /// Every commit this client has moved the branch past while the window was
  /// open — the whole chain, not only the last step. `null` stands for "the
  /// branch did not exist", which is what a replica that has not seen our
  /// create answers with a 404.
  ///
  /// A set rather than a single sha because two writes inside the window make
  /// the commit *two* behind just as historical as the one behind it, and a
  /// replica serving it is equally behind.
  final Set<String?> superseded;

  final DateTime landedAt;

  const _WriteAuthority({
    required this.commitSha,
    required this.treeSha,
    required this.superseded,
    required this.landedAt,
  });
}

/// One branch's commit and fully-expanded tree, plus the ETag that lets the
/// next poll ask "has this moved?" for free.
/// The per-branch tree snapshots, bounded by how much tree they hold.
///
/// A drop-in for the map it replaced — `[]`, `[]=`, `remove` and `clear` are
/// the whole surface the backend used — so bounding the cache changed no call
/// site. Least-recently-used order is the insertion order of a Dart map, kept
/// current by removing and re-inserting on every read.
/// What one pass has validated: per branch, the snapshot a ref read confirmed.
///
/// It holds references and decides nothing. Whether a snapshot may be served
/// is decided in `_snapshot`, against the cache as it is at that moment.
class _Pass {
  final Map<String, _TreeSnapshot> validated = {};
}

class _SnapshotCache {
  /// Read for [TomGitHubStorage.maxCachedTreeEntries] at eviction time, so
  /// a test (or a composition root) can set the budget after construction and
  /// have it apply.
  final TomGitHubStorage _owner;

  final Map<String, _TreeSnapshot> _held = {};
  int _entries = 0;

  /// Branch → when the budget evicted it, kept only to recognise thrash.
  ///
  /// Bounded by [TomGitHubStorage.thrashWindow]: an entry leaves when the
  /// branch is read again, and the rest are swept on every eviction, so what
  /// is held is "branches evicted within the last window".
  final Map<String, DateTime> _evictedAt = {};

  _SnapshotCache(this._owner);

  int get length => _held.length;

  int get evictionsRemembered => _evictedAt.length;

  /// Tree entries across every cached branch — the quantity the budget is in.
  int get heldEntries => _entries;

  _TreeSnapshot? operator [](String key) {
    final found = _held.remove(key);
    if (found == null) return null;
    return _held[key] = found; // Re-inserted, so it is now the newest.
  }

  void operator []=(String key, _TreeSnapshot value) {
    _drop(key);
    _held[key] = value;
    _entries += value.tree.entries.length;
    final now = _owner._clock();
    final evictedAt = _evictedAt.remove(key);

    while (_entries > _owner.maxCachedTreeEntries && _held.length > 1) {
      // Never the last one: a repository whose tree exceeds the whole budget
      // would otherwise evict itself the instant it was cached, and the client
      // would re-read it on every single operation. Holding one oversized
      // snapshot is the lesser failure, and it is still a bound.
      _evict(_held.keys.first, now);
    }

    // After the evictions this install caused, so the totals are the ones the
    // cache is left with.
    if (evictedAt != null) {
      final goneFor = now.difference(evictedAt);
      if (goneFor < _owner.thrashWindow) {
        _owner.diagnostics.log(
          TomDiagnosticEvent(
            operation: 'github.snapshot.thrash',
            level: TomDiagnosticLevel.warn,
            at: now,
            fields: {
              'branch': key,
              'entries': value.tree.entries.length,
              'goneForMs': goneFor.inMilliseconds,
              ..._totals,
            },
          ),
        );
      }
    }
  }

  /// Drops [key] because the budget requires it, and says so.
  ///
  /// Distinct from [remove] and [_drop], which are a caller discarding a
  /// snapshot it no longer trusts — a save does that before it reads — and
  /// are not evictions: nothing about the budget caused them.
  void _evict(String key, DateTime now) {
    final gone = _held[key]!;
    _drop(key);
    _evictedAt.removeWhere(
      (_, at) => now.difference(at) >= _owner.thrashWindow,
    );
    _evictedAt[key] = now;
    _owner.diagnostics.log(
      TomDiagnosticEvent(
        operation: 'github.snapshot.evicted',
        level: TomDiagnosticLevel.debug,
        at: now,
        fields: {
          'branch': key,
          'entries': gone.tree.entries.length,
          ..._totals,
        },
      ),
    );
  }

  Map<String, Object?> get _totals => {
    'heldEntries': _entries,
    'heldSnapshots': _held.length,
    'budget': _owner.maxCachedTreeEntries,
  };

  _TreeSnapshot? remove(String key) {
    final gone = _held[key];
    _drop(key);
    return gone;
  }

  void clear() {
    _held.clear();
    _evictedAt.clear();
    _entries = 0;
  }

  void _drop(String key) {
    final gone = _held.remove(key);
    if (gone != null) _entries -= gone.tree.entries.length;
  }
}

class _TreeSnapshot {
  final String commitSha;
  final String treeSha;
  final GitHubTree tree;
  final String? refEtag;

  const _TreeSnapshot({
    required this.commitSha,
    required this.treeSha,
    required this.tree,
    this.refEtag,
  });

  _TreeSnapshot withEtag(String? etag) => _TreeSnapshot(
    commitSha: commitSha,
    treeSha: treeSha,
    tree: tree,
    refEtag: etag,
  );

  /// The `meta/` record: the listing, the head it was taken at, and
  /// the ETag that revalidates it.
  Map<String, Object?> toRecord() => {
    'commit': commitSha,
    'tree': treeSha,
    if (refEtag != null) 'etag': refEtag,
    'entries': [
      for (final entry in tree.entries)
        {
          'path': entry.path,
          'mode': entry.mode.code,
          'type': entry.type,
          'sha': entry.sha,
          if (entry.size != null) 'size': entry.size,
        },
    ],
  };

  /// Null for a record that is not one — the cache is disposable, so a record
  /// this build cannot read is a record that is not there.
  static _TreeSnapshot? fromRecord(Map<String, Object?> record) {
    final commit = record['commit'];
    final tree = record['tree'];
    final entries = record['entries'];
    if (commit is! String || tree is! String || entries is! List) return null;
    try {
      return _TreeSnapshot(
        commitSha: commit,
        treeSha: tree,
        refEtag: record['etag'] as String?,
        tree: GitHubTree(
          sha: tree,
          truncated: false,
          entries: [
            for (final entry in entries)
              GitHubTreeEntry.fromJson((entry as Map).cast<String, dynamic>()),
          ],
        ),
      );
    } on Object {
      return null;
    }
  }

  GitHubTreeEntry? entryAt(String path) {
    for (final entry in tree.entries) {
      if (entry.path == path) return entry;
    }
    return null;
  }

  /// The git object sha that stands for the document at [path] — the blob sha
  /// for a single-file serialization, the subtree sha for a bundle directory.
  ///
  /// A subtree sha is a hash of everything below it, so a bundle's head moves
  /// when any one of its section files does, and only then.
  String? objectShaFor(String path) => entryAt(path)?.sha;
}

/// The [TomBundleMedium] `TomGitHubStorage.readBundle` hands back.
///
/// Reads are resolved against the tree listing the snapshot already carried —
/// so `listFiles` and `exists` cost nothing — and a `getBlob` is issued only
/// for a path somebody actually reads. Each is cached, because the bundle
/// store reads a manifest once and a section file once, and a second fetch for
/// the same bytes would be pure waste.
///
class _LazyBlobMedium extends TomBundleMedium {
  final TomGitHubStorage storage;
  final TomGitHubLocator loc;
  final String locator;

  /// Path → blob sha, from the tree the snapshot already held.
  final Map<String, String> shas;

  final Map<String, Uint8List> _cache = {};

  _LazyBlobMedium({
    required this.storage,
    required this.loc,
    required this.locator,
    required this.shas,
  });

  @override
  Future<bool> exists(String path) async => shas.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async {
    final cached = _cache[path];
    if (cached != null) return cached;
    final sha = shas[path];
    if (sha == null) {
      throw TomContainerNotFoundException('$locator/$path');
    }
    return _cache[path] = await storage.readBlobAt(loc, locator, path, sha);
  }

  @override
  Future<List<String>> listFiles() async => shas.keys.toList()..sort();

  // No write members: `readBundle` wraps this in a `TomReadOnlyBundleMedium`,
  // so the refusal is stated once for both storage tiers rather than per
  // backend.
  @override
  Future<void> writeBytes(String path, Uint8List bytes) async =>
      throw UnsupportedError('unreachable: wrapped read-only');

  @override
  Future<void> delete(String path) async =>
      throw UnsupportedError('unreachable: wrapped read-only');
}
