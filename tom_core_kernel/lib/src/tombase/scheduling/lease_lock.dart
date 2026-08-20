/// Cluster coordination — the lease-based lock that makes one scheduled run
/// execute once across a server cluster.
///
/// The single-node scheduler serialises a job's runs with an in-process set;
/// that set is invisible to the machine next to it. Point two schedulers at one
/// shared queue and both will claim the same due run, because nothing arbitrates
/// between them. This library is that arbiter.
///
/// ## What a lease is, and why not a plain lock
///
/// A plain mutual-exclusion lock has one fatal property in a distributed system:
/// if the holder dies, the lock is held forever. Every distributed lock is
/// therefore a **lease** — an acquisition with an expiry, so a holder that
/// vanishes stops being a holder without having to do anything. That trade is
/// not free: it converts "held forever" into "may be released while the holder
/// still thinks it holds it", which is the failure this library is careful about
/// rather than one it pretends away.
///
/// Three mechanisms manage that trade:
///
/// * **TTL** — a lease expires at [TomLease.expiresAt] whether or not the holder
///   is alive. This is what makes holder death self-healing.
/// * **Renewal** — a live holder pushes its expiry forward while it works, so a
///   job legitimately running longer than the TTL is not double-fired. Without
///   renewal the TTL would have to exceed the slowest possible run, which means
///   a dead holder blocks the resource for that long too. Renewal is what lets
///   the TTL be short *and* long jobs be safe.
/// * **Fencing tokens** — see below.
///
/// ## Fencing tokens: why the guarantee is what it is
///
/// A lease cannot, by itself, guarantee that two holders never overlap. The
/// holder might be paused — a stop-the-world GC, a hypervisor suspend, a stalled
/// disk — for longer than its TTL, wake up believing it still holds the lease,
/// and write. Meanwhile the lease expired and somebody else acquired it. No
/// amount of clock care fixes this, because the pause happens *between* the
/// holder's check and its write.
///
/// The standard answer is a **fencing token**: every acquisition carries a
/// number ([TomLease.token]) that strictly increases per resource. A protected
/// resource that records the highest token it has seen and rejects anything
/// lower will reject the stale holder's late write. That turns "probably one
/// holder" into a real guarantee — but only for resources that check the token.
///
/// This library therefore issues tokens and states plainly what they buy:
///
/// * Against **any** resource: a lease gives single-active-holder under normal
///   operation (no pause exceeding the TTL). Duplicate execution is possible in
///   the pause case.
/// * Against a **token-checking** resource: the stale holder's writes are
///   rejected, so the effect is single-fire even under pause.
///
/// See `doc/scheduling/scheduling.md` for the execution guarantee CE-JB job
/// bodies must be written against. The short version is that job bodies must be
/// **idempotent**; the lock reduces duplicate work, it does not abolish it.
///
/// ## The substrate
///
/// [TomLeaseLock] is a port, not a single implementation, and the substrate is a
/// deployment choice — with one rule: **the lock must live in the same failure
/// domain as the job queue it guards.** A lock in a different store than the
/// queue can be healthy while the queue is unreachable, at which point a node
/// holds a valid lease over work it cannot see, and no reconciliation exists.
/// So a file-backed queue pairs with a file-backed lock and a database-backed
/// queue pairs with a database-backed lock.
///
/// Two implementations ship here, matching the two [TomJobStore]s:
///
/// * [TomMemoryLeaseLock] — one process. Correct for tests and for single-node
///   deployments, which are the majority and are fully served by it.
/// * [TomFileLeaseLock] — many processes over a shared filesystem, built on
///   atomic exclusive-create and atomic rename.
///
/// A relational implementation belongs in `tom_core_server` alongside the
/// relational queue, over this same contract.
library;

import 'dart:convert';
import 'dart:io';

import 'schedule.dart';

// =============================================================================
// LEASE
// =============================================================================

/// A granted, time-bounded claim on a named resource.
///
/// Immutable: renewing produces a new lease rather than mutating this one, so a
/// holder can never be confused about which expiry it is working against, and a
/// stale reference stays honestly stale.
class TomLease {
  /// The resource this lease covers — for the scheduler, a job or a run.
  final String resource;

  /// Who holds it. Distinct per scheduler instance.
  final String owner;

  /// The fencing token: strictly increasing per [resource] across acquisitions.
  ///
  /// Hand this to any resource that supports fencing so it can reject a write
  /// from a holder whose lease has since been taken over. A resource that
  /// ignores it still benefits from the lease; it just does not get the
  /// pause-safety guarantee.
  final int token;

  /// When this acquisition happened, by the acquiring node's clock.
  final DateTime acquiredAt;

  /// When it lapses unless renewed, by the acquiring node's clock.
  ///
  /// Both timestamps are the *holder's* view. Across nodes with skewed clocks
  /// these are not directly comparable, which is why [TomFileLeaseLock] compares
  /// against the reading node's own clock and why the TTL should comfortably
  /// exceed the worst expected skew.
  final DateTime expiresAt;

  /// Creates a lease.
  const TomLease({
    required this.resource,
    required this.owner,
    required this.token,
    required this.acquiredAt,
    required this.expiresAt,
  });

  /// Whether this lease has lapsed at [now].
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// How long remains before expiry at [now]; [Duration.zero] once lapsed.
  Duration remainingAt(DateTime now) =>
      isExpiredAt(now) ? Duration.zero : expiresAt.difference(now);

  /// Encodes this lease as a JSON-native map.
  Map<String, Object?> toJson() => {
    'resource': resource,
    'owner': owner,
    'token': token,
    'acquiredAt': acquiredAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  /// Decodes a map produced by [toJson].
  factory TomLease.fromJson(Map<String, Object?> map) => TomLease(
    resource: map['resource'] as String,
    owner: map['owner'] as String,
    token: map['token'] as int,
    acquiredAt: DateTime.parse(map['acquiredAt'] as String),
    expiresAt: DateTime.parse(map['expiresAt'] as String),
  );

  @override
  String toString() =>
      'TomLease($resource by $owner, token $token, '
      'expires ${expiresAt.toIso8601String()})';
}

// =============================================================================
// OBSERVABILITY
// =============================================================================

/// What a lock currently knows about a resource — the answer to "who holds it,
/// when does it expire, and is that still true?".
///
/// Returned by [TomLeaseLock.inspect] and deliberately readable without
/// acquiring anything, because the first thing an operator does when a job stops
/// running is ask who is sitting on it.
class TomLeaseInfo {
  /// The resource inspected.
  final String resource;

  /// The most recent lease on record, or `null` if the resource was never held.
  ///
  /// Present even when [isHeld] is false: a released or expired lease still
  /// answers "who had it last", which is the question worth asking after a node
  /// vanished.
  final TomLease? lease;

  /// Whether [lease] is currently live — present, unexpired, and not released.
  final bool isHeld;

  /// Whether the recorded lease ended by an orderly [TomLeaseLock.release].
  ///
  /// The distinction that matters after an incident: a lease that was released
  /// belonged to a node that shut down cleanly, while a lease that merely
  /// expired belonged to one that **vanished**. Both leave `isHeld` false, and
  /// telling them apart is the difference between "the cluster scaled down" and
  /// "a node died mid-run".
  final bool wasReleased;

  /// Creates an inspection result.
  const TomLeaseInfo({
    required this.resource,
    required this.lease,
    required this.isHeld,
    this.wasReleased = false,
  });

  /// An inspection result for a resource with no record at all.
  const TomLeaseInfo.free(this.resource)
    : lease = null,
      isHeld = false,
      wasReleased = false;

  /// Whether the last holder lapsed without releasing — i.e. it vanished.
  bool get holderVanished => lease != null && !isHeld && !wasReleased;

  /// A one-line description for a log line or a diagnostics endpoint.
  String describe() {
    final current = lease;
    if (current == null) return 'Lease "$resource": never held.';
    if (isHeld) {
      return 'Lease "$resource": held by ${current.owner} '
          '(token ${current.token}), expires '
          '${current.expiresAt.toIso8601String()}.';
    }
    final ending = wasReleased
        ? 'released by ${current.owner}'
        : 'lapsed at ${current.expiresAt.toIso8601String()} while held by '
              '${current.owner} (holder vanished)';
    return 'Lease "$resource": free; $ending (token ${current.token}).';
  }

  @override
  String toString() => describe();
}

// =============================================================================
// LOCK CONTRACT
// =============================================================================

/// A lease-based distributed lock.
///
/// Implementations must make [acquire] **atomic**: two callers racing for a free
/// resource must not both receive a lease. That is the entire load-bearing
/// requirement — everything else in this contract is bookkeeping around it.
abstract class TomLeaseLock {
  /// Creates a lock.
  const TomLeaseLock();

  /// Attempts to take [resource] for [owner] until `now + ttl`.
  ///
  /// Returns the granted lease, or `null` when another owner currently holds it.
  /// Returning `null` is an ordinary outcome in a cluster — it means another
  /// node is doing the work — and is not an error.
  ///
  /// A lease whose expiry has passed is taken over rather than refused: that is
  /// how a holder that died stops blocking the resource.
  Future<TomLease?> acquire(String resource, String owner, Duration ttl);

  /// Extends [lease] by [ttl] from now.
  ///
  /// Returns the new lease, or `null` if it could no longer be renewed — the
  /// resource was taken over while this holder was working. `null` is a serious
  /// signal: the caller must assume somebody else is now running the work and
  /// must stop treating its own results as authoritative.
  Future<TomLease?> renew(TomLease lease, Duration ttl);

  /// Releases [lease] if it is still held by its owner.
  ///
  /// Releasing a lease that was already taken over is a no-op rather than an
  /// error: the holder losing a race it did not know it was in should not also
  /// have to handle an exception on the way out.
  Future<void> release(TomLease lease);

  /// Reports what is known about [resource] without acquiring it.
  Future<TomLeaseInfo> inspect(String resource);

  /// Discards every record of [resource], fencing-token chain included.
  ///
  /// Only safe for a resource whose name will never appear again — a run id,
  /// which is unique for the life of the queue. Forgetting a **stable** name
  /// such as a job's restarts its tokens at 1, and a token that repeats is not
  /// a fencing token. It exists because a per-run resource would otherwise
  /// accumulate one dead record for every window ever executed.
  Future<void> forget(String resource);

  /// Releases whatever the lock implementation owns.
  void close() {}
}

// =============================================================================
// IN-MEMORY LOCK
// =============================================================================

/// A [TomLeaseLock] confined to one process.
///
/// Atomic by virtue of Dart's single-threaded event loop: it performs no `await`
/// between reading a record and replacing it, so no other code in this isolate
/// can interleave.
///
/// Correct for tests, and correct in production for a **single-node**
/// deployment, where it upgrades the scheduler's in-process overlap set to a
/// uniform mechanism at no cost. It coordinates nothing across processes, which
/// is the whole reason [TomFileLeaseLock] exists.
class TomMemoryLeaseLock extends TomLeaseLock {
  /// The clock. Injectable so tests can expire leases without waiting.
  final DateTime Function() clock;

  /// The current record per resource — kept after release rather than removed,
  /// exactly as [TomFileLeaseLock] keeps its file, so both implementations can
  /// answer "who had it last, and did they leave cleanly?".
  final Map<String, _LeaseRecord> _records = {};

  /// Creates an in-memory lock.
  TomMemoryLeaseLock({DateTime Function()? clock})
    : clock = clock ?? DateTime.now;

  @override
  Future<TomLease?> acquire(String resource, String owner, Duration ttl) async {
    final now = clock();
    final record = _records[resource];
    final held = record?.lease;
    if (record != null && held != null && record.isHeldAt(now)) {
      if (held.owner != owner) return null;
      // Re-acquisition by the live holder is an extension, not a conflict — and
      // it must keep the token. Issuing a new one would invalidate the lease
      // this very owner is already working under.
      return _grant(resource, owner, ttl, now, token: held.token);
    }
    // Free, lapsed or released: this is a fresh acquisition and gets the next
    // token up. The counter lives in the retained record, so it survives
    // release — a token that repeats is not a fencing token.
    return _grant(resource, owner, ttl, now, token: (held?.token ?? 0) + 1);
  }

  @override
  Future<TomLease?> renew(TomLease lease, Duration ttl) async {
    final now = clock();
    final record = _records[lease.resource];
    final held = record?.lease;
    // Token equality, not just owner equality: the same owner re-acquiring
    // after a takeover gets a new token, and the old lease must stay dead.
    if (record == null ||
        held == null ||
        held.owner != lease.owner ||
        held.token != lease.token) {
      return null;
    }
    if (!record.isHeldAt(now)) return null;
    return _grant(lease.resource, lease.owner, ttl, now, token: held.token);
  }

  @override
  Future<void> release(TomLease lease) async {
    final held = _records[lease.resource]?.lease;
    if (held == null || held.owner != lease.owner) return;
    if (held.token != lease.token) return;
    _records[lease.resource] = _LeaseRecord(lease: held, released: true);
  }

  @override
  Future<TomLeaseInfo> inspect(String resource) async {
    final record = _records[resource];
    if (record == null) return TomLeaseInfo.free(resource);
    return TomLeaseInfo(
      resource: resource,
      lease: record.lease,
      isHeld: record.isHeldAt(clock()),
      wasReleased: record.released,
    );
  }

  @override
  Future<void> forget(String resource) async => _records.remove(resource);

  TomLease _grant(
    String resource,
    String owner,
    Duration ttl,
    DateTime now, {
    required int token,
  }) {
    final lease = TomLease(
      resource: resource,
      owner: owner,
      token: token,
      acquiredAt: now,
      expiresAt: now.add(ttl),
    );
    _records[resource] = _LeaseRecord(lease: lease, released: false);
    return lease;
  }

  @override
  void close() {
    _records.clear();
  }
}

// =============================================================================
// FILE-BACKED LOCK
// =============================================================================

/// A [TomLeaseLock] that coordinates **separate processes** through a shared
/// directory.
///
/// ## How it is atomic
///
/// One primitive carries the whole design: `File.createSync(exclusive: true)`
/// is `O_EXCL`, so it fails if the path already exists. That is an atomic
/// test-and-set shared by every process on the filesystem. (`Directory
/// .createSync` is **not** usable for this — it succeeds silently on an
/// existing directory, so the classic mkdir-mutex idiom does not port to Dart.)
///
/// The trick is *what* gets created. Each resource owns a directory, and each
/// acquisition writes a file named after its own fencing token:
///
/// ```text
/// <root>/<encoded resource>/3.lease
/// ```
///
/// Taking over a lapsed lease at token 3 means creating `4.lease` exclusively.
/// Every contender computes the same next token, so exactly one create wins and
/// the rest are refused by the kernel. Nothing is ever deleted from under a
/// reader, and — the property that matters — **the resource is never briefly
/// absent**, so no late arrival can mistake a takeover in progress for a free
/// resource and claim it in parallel.
///
/// A design that instead renames the stale record aside and re-creates it has
/// exactly that hole: between the rename and the create the resource looks
/// untaken, and a node arriving in that window wins it legitimately, alongside
/// the node doing the takeover. Versioned names close the window by never
/// opening it.
///
/// Superseded records are pruned once two newer ones exist, so a resource costs
/// two small files however many times it changes hands. Per-*run* resources are
/// dropped outright by [forget], since a run id never recurs.
///
/// ## What it assumes
///
/// A filesystem where exclusive-create and rename are atomic between the
/// processes sharing it. That is true for a local filesystem and for a
/// well-behaved network filesystem, but network filesystems vary and some cache
/// aggressively enough to break it. Where the deployment already has a database,
/// a database-backed lock is the safer substrate; this one exists so that a
/// file-backed queue has a lock in its own failure domain.
///
/// Clocks are compared across nodes only through expiry timestamps, so the TTL
/// must comfortably exceed the fleet's worst clock skew.
class TomFileLeaseLock extends TomLeaseLock {
  /// The directory lease records live in, one file per resource.
  final Directory directory;

  /// The clock. Injectable so tests can expire leases without waiting.
  final DateTime Function() clock;

  /// Creates a lock over [path], creating the directory if it is missing.
  TomFileLeaseLock(String path, {DateTime Function()? clock})
    : directory = Directory(path),
      clock = clock ?? DateTime.now {
    directory.createSync(recursive: true);
  }

  @override
  Future<TomLease?> acquire(String resource, String owner, Duration ttl) async {
    final now = clock();
    _directoryFor(resource).createSync(recursive: true);
    final current = _scan(resource);

    // Never held: token 1 is up for grabs.
    if (current == null) return _claim(resource, 1, owner, ttl, now);

    final record = current.record;
    if (record == null) {
      // Unreadable. Either an acquirer caught between its exclusive create and
      // its first write — microseconds — or a genuinely corrupt record. Age
      // tells them apart, and only the old one may be stepped over.
      if (!_isAbandoned(_fileFor(resource, current.token), ttl)) return null;
      return _claim(resource, current.token + 1, owner, ttl, now);
    }

    final held = record.lease;
    if (held != null && record.isHeldAt(now)) {
      if (held.owner != owner) return null;
      // Our own live lease: rewrite this same version with a later expiry. A
      // new token here would invalidate the lease we are already working under.
      return _write(
        _fileFor(resource, current.token),
        resource,
        owner,
        ttl,
        now,
        token: current.token,
      );
    }
    return _claim(resource, current.token + 1, owner, ttl, now);
  }

  @override
  Future<TomLease?> renew(TomLease lease, Duration ttl) async {
    final now = clock();
    final current = _scan(lease.resource);
    // A higher version exists, so this lease was taken over while we worked.
    if (current == null || current.token != lease.token) return null;
    final record = current.record;
    final held = record?.lease;
    if (record == null || held == null) return null;
    if (held.owner != lease.owner || held.token != lease.token) return null;
    if (!record.isHeldAt(now)) return null;
    return _write(
      _fileFor(lease.resource, current.token),
      lease.resource,
      lease.owner,
      ttl,
      now,
      token: held.token,
    );
  }

  @override
  Future<void> release(TomLease lease) async {
    final current = _scan(lease.resource);
    if (current == null || current.token != lease.token) return;
    final held = current.record?.lease;
    if (held == null) return;
    if (held.owner != lease.owner || held.token != lease.token) return;
    // The record is marked free rather than deleted, so it still answers "who
    // had it last, and did they leave cleanly?" — the question an operator asks
    // first when a job stops running.
    _writeRecord(
      _fileFor(lease.resource, current.token),
      _LeaseRecord(lease: held, released: true),
    );
  }

  @override
  Future<TomLeaseInfo> inspect(String resource) async {
    final record = _scan(resource)?.record;
    if (record == null) return TomLeaseInfo.free(resource);
    return TomLeaseInfo(
      resource: resource,
      lease: record.lease,
      isHeld: record.isHeldAt(clock()),
      wasReleased: record.released,
    );
  }

  @override
  Future<void> forget(String resource) async {
    final dir = _directoryFor(resource);
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // Losing the race to delete a directory nobody will consult again is not
      // worth failing the caller over.
    }
  }

  // ---------------------------------------------------------------------------
  // PRIMITIVES
  // ---------------------------------------------------------------------------

  /// Grants [token] on [resource] to [owner], or `null` if a peer got there.
  ///
  /// The exclusive create *is* the arbitration: every contender computes the
  /// same next token, and the kernel picks the one winner.
  TomLease? _claim(
    String resource,
    int token,
    String owner,
    Duration ttl,
    DateTime now,
  ) {
    final file = _fileFor(resource, token);
    if (!_createExclusively(file)) return null;
    final lease = _write(file, resource, owner, ttl, now, token: token);
    _pruneBelow(resource, token - 1);
    return lease;
  }

  /// The highest-numbered record for [resource], or `null` if there is none.
  ///
  /// [record] is `null` when that file exists but cannot be read — the
  /// mid-create and corrupt cases, which the caller separates by age.
  ({int token, _LeaseRecord? record})? _scan(String resource) {
    final List<FileSystemEntity> entries;
    try {
      entries = _directoryFor(resource).listSync(followLinks: false);
    } on FileSystemException {
      return null;
    }
    var highest = 0;
    for (final entry in entries) {
      final token = _tokenOf(entry.path);
      if (token != null && token > highest) highest = token;
    }
    if (highest == 0) return null;
    return (token: highest, record: _readFrom(_fileFor(resource, highest)));
  }

  /// Drops records below [oldest], keeping the current one and its predecessor.
  ///
  /// The predecessor is kept deliberately: a reader that listed the directory a
  /// moment before a takeover is about to read the version it saw, and pulling
  /// that file out from under it would turn a clean "somebody else holds this"
  /// into an unreadable record.
  void _pruneBelow(String resource, int oldest) {
    if (oldest <= 1) return;
    final List<FileSystemEntity> entries;
    try {
      entries = _directoryFor(resource).listSync(followLinks: false);
    } on FileSystemException {
      return;
    }
    for (final entry in entries) {
      final token = _tokenOf(entry.path);
      if (token != null && token < oldest) _deleteQuietly(File(entry.path));
    }
  }

  /// Atomically creates [file], returning whether this caller created it.
  bool _createExclusively(File file) {
    try {
      file.createSync(exclusive: true);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Whether an unreadable record is old enough that its writer must be gone.
  ///
  /// The window between exclusive-create and the first write is microseconds; a
  /// record still unreadable a whole TTL later was left by a process that died
  /// inside that window.
  ///
  /// Measured against the **real** clock rather than [clock]: this asks how long
  /// a file has physically existed, and a filesystem timestamp is only
  /// comparable with wall time. An injected clock would compare a simulated
  /// instant with a real one and get an arbitrary answer.
  bool _isAbandoned(File file, Duration ttl) {
    try {
      return DateTime.now().difference(file.lastModifiedSync()) > ttl;
    } on FileSystemException {
      // It vanished under us — let the exclusive create decide.
      return true;
    }
  }

  TomLease _write(
    File file,
    String resource,
    String owner,
    Duration ttl,
    DateTime now, {
    required int token,
  }) {
    final lease = TomLease(
      resource: resource,
      owner: owner,
      token: token,
      acquiredAt: now,
      expiresAt: now.add(ttl),
    );
    _writeRecord(file, _LeaseRecord(lease: lease, released: false));
    return lease;
  }

  void _writeRecord(File file, _LeaseRecord record) {
    file.writeAsStringSync(jsonEncode(record.toJson()), flush: true);
  }

  _LeaseRecord? _readFrom(File file) {
    try {
      final raw = file.readAsStringSync();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _LeaseRecord.fromJson(Map<String, Object?>.from(decoded));
    } catch (_) {
      // Missing, half-written or corrupt. The caller decides what that means;
      // here it is simply "no readable record".
      return null;
    }
  }

  void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A superseded record left behind is harmless: nothing consults it once a
      // higher token exists. Failing the acquisition over it would be worse.
    }
  }

  /// The token encoded in a record's file name, or `null` if it is not one.
  int? _tokenOf(String path) {
    final name = path.split(Platform.pathSeparator).last;
    if (!name.endsWith(_recordSuffix)) return null;
    return int.tryParse(name.substring(0, name.length - _recordSuffix.length));
  }

  /// The directory holding every record for [resource].
  ///
  /// Resource names come from job names and run ids, which may contain
  /// characters a filesystem will not take, so the name is encoded rather than
  /// used raw. Giving each resource its own directory also keeps [_scan] to a
  /// two-entry listing however many resources the lock coordinates.
  Directory _directoryFor(String resource) {
    if (resource.isEmpty) {
      throw TomScheduleException(
        'schedule.lease.unnamed_resource',
        'A lease resource name must not be empty.',
      );
    }
    final safe = base64Url.encode(utf8.encode(resource)).replaceAll('=', '');
    return Directory('${directory.path}${Platform.pathSeparator}$safe');
  }

  /// The record file for one [token] of [resource].
  File _fileFor(String resource, int token) => File(
    '${_directoryFor(resource).path}${Platform.pathSeparator}'
    '$token$_recordSuffix',
  );

  static const String _recordSuffix = '.lease';
}

/// The on-disk shape of a lease: the lease itself plus whether it was released.
///
/// "Released" is recorded rather than represented by deleting the file, because
/// the file is also where the fencing token lives and the token must outlive
/// the lease that carried it.
class _LeaseRecord {
  final TomLease? lease;
  final bool released;

  const _LeaseRecord({required this.lease, required this.released});

  bool isHeldAt(DateTime now) {
    final current = lease;
    if (current == null || released) return false;
    return !current.isExpiredAt(now);
  }

  Map<String, Object?> toJson() => {
    'lease': lease?.toJson(),
    'released': released,
  };

  factory _LeaseRecord.fromJson(Map<String, Object?> map) {
    final raw = map['lease'];
    return _LeaseRecord(
      lease: raw is Map
          ? TomLease.fromJson(Map<String, Object?>.from(raw))
          : null,
      released: map['released'] == true,
    );
  }
}
