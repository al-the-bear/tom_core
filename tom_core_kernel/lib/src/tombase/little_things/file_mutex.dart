/// Mutual exclusion between everything that might write one file.
///
/// The kernel's file-backed stores mirror an in-memory collection to a JSON
/// file, rewriting it whole on every mutation. [tomWriteFileAtomically] makes
/// each of those writes indivisible, so a reader never sees a half-written
/// file. It does nothing about a *second writer*: two owners of the same path
/// each read it once, each rewrite it whole, and the later write erases
/// everything the earlier one added. Records vanish with no error.
///
/// This library is the guard that makes a mutation a read-modify-write nobody
/// else can interleave with.
///
/// ## Why not `dart:io`'s own file locks
///
/// [RandomAccessFile.lockSync] looks like the obvious answer and is the wrong
/// one: it is **process-scoped**. Two isolates of one process both acquire an
/// "exclusive" lock on the same file and neither is told, because the
/// underlying POSIX locks belong to the process rather than to the opener. A
/// worker isolate and the isolate that spawned it are the first case this
/// guard has to cover, so a primitive that is blind to them cannot be the one.
///
/// Creating a file with `exclusive: true` is a single `O_CREAT | O_EXCL`
/// syscall with no such scoping. Exactly one caller creates it and everyone
/// else gets `EEXIST` — across isolates and across processes alike, on every
/// platform Dart runs on.
///
/// ## The cost of a guard that can be orphaned
///
/// An OS lock dies with the process holding it; a file does not. A writer
/// killed between creating the guard and removing it leaves a file that would
/// block every later owner **forever** — trading silent loss for a permanent
/// hang, which is not a trade worth making.
///
/// So an orphan is broken: a guard whose last-modified time is older than
/// [tomFileLockStaleAfter] is deleted, and the acquirer then re-enters the
/// ordinary exclusive-create race like everyone else. Breaking a guard only
/// removes the obstacle, it never grants the lock — so two waiters that both
/// decide to break cannot both end up holding it; one wins the create and the
/// other keeps waiting. Staleness is re-checked immediately before the delete
/// so the loser of that race cannot then delete the winner's fresh guard.
///
/// The timeout is generous because it is bounded from below by real work: a
/// critical section here is a small read, an encode and one atomic write, so
/// a guard that has stood unchanged for ten seconds is not slow, it is
/// abandoned.
///
/// The library is internal — how a store reaches the disk is not something a
/// caller should reach for — and imports `dart:io`, so nothing web-facing may
/// import it.
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:io';

import 'atomic_file.dart';

// =============================================================================
// Configuration
// =============================================================================

/// How long a guard may stand unchanged before it is presumed abandoned.
///
/// See the library documentation for why this is generous rather than tight.
const Duration tomFileLockStaleAfter = Duration(seconds: 10);

/// How long to wait between attempts while another writer holds the guard.
///
/// Short enough that an uncontended handover is not noticeably delayed, long
/// enough that waiting does not become a spin.
const Duration _retryInterval = Duration(milliseconds: 2);

// =============================================================================
// Guarded execution
// =============================================================================

/// The guard file protecting [path].
///
/// A sibling rather than [path] itself, because the file being protected is
/// replaced by a rename on every write: a guard held *on* it would be a guard
/// on an inode that no longer has the name.
String tomFileLockPath(String path) => '$path.lock';

/// Runs [body] with exclusive access to [lockFile] among every isolate and
/// process using this guard, and releases it however [body] ends.
///
/// [onBrokenLock] is called when an abandoned guard had to be broken, since
/// that means some other writer died mid-mutation and its last write may not
/// have landed — worth saying out loud rather than silently recovering from.
/// It is a callback rather than a log call so this library keeps no dependency
/// on the logging module, which is itself one of its callers.
///
/// Throws a [FileSystemException] if the guard cannot be taken within
/// [timeout]. A caller that could not take the lock has not written, and must
/// find that out rather than believe it has persisted.
T tomWithFileLock<T>(
  File lockFile,
  T Function() body, {
  Duration staleAfter = tomFileLockStaleAfter,
  Duration timeout = const Duration(seconds: 30),
  void Function(String warning)? onBrokenLock,
}) {
  _acquire(lockFile, staleAfter, timeout, onBrokenLock);
  try {
    return body();
  } finally {
    _release(lockFile);
  }
}

/// Blocks until this writer holds [lockFile].
///
/// Synchronous on purpose. The stores this guards present a synchronous
/// contract and already block on flushed writes; an asynchronous acquire would
/// let the isolate run other code inside a critical section that exists
/// precisely to keep other code out.
void _acquire(
  File lockFile,
  Duration staleAfter,
  Duration timeout,
  void Function(String warning)? onBrokenLock,
) {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    try {
      lockFile.parent.createSync(recursive: true);
      lockFile.createSync(exclusive: true);
      // Whose guard this is, for whoever finds it abandoned. Best-effort: the
      // guard is already held by this point, and failing to annotate it must
      // not fail the acquire.
      try {
        lockFile.writeAsStringSync(tomFileWriterId, flush: true);
      } catch (_) {
        // The name is a diagnostic, not the lock.
      }
      return;
    } on FileSystemException {
      // Someone holds it. Break it if it has been abandoned, then race for it
      // on equal terms with everyone else that was waiting.
      if (_breakIfAbandoned(lockFile, staleAfter, onBrokenLock)) continue;
      if (DateTime.now().isAfter(deadline)) {
        throw FileSystemException(
          'Could not acquire the lock on ${lockFile.path} within '
          '${timeout.inSeconds}s — another writer is holding it and is not '
          'making progress. Nothing was written.',
          lockFile.path,
        );
      }
      sleep(_retryInterval);
    }
  }
}

/// Deletes [lockFile] if it has stood unchanged for longer than [staleAfter],
/// returning whether the caller should retry immediately.
///
/// Breaking only removes the obstacle; the caller still has to win the
/// exclusive create afterwards. That is what keeps two simultaneous breakers
/// from both concluding they hold the guard.
bool _breakIfAbandoned(
  File lockFile,
  Duration staleAfter,
  void Function(String warning)? onBrokenLock,
) {
  final DateTime heldSince;
  try {
    heldSince = lockFile.lastModifiedSync();
  } on FileSystemException {
    // Released while we looked at it — retry, the guard is free.
    return true;
  }
  final age = DateTime.now().difference(heldSince);
  if (age < staleAfter) return false;

  String holder;
  try {
    holder = lockFile.readAsStringSync().trim();
  } catch (_) {
    holder = 'unknown';
  }
  try {
    // Re-check under the freshest reading available: if another waiter broke
    // this guard and took it while we were deciding, its guard is new and
    // deleting it would hand the file to two writers at once — the exact
    // failure this library exists to prevent.
    if (DateTime.now().difference(lockFile.lastModifiedSync()) < staleAfter) {
      return true;
    }
    lockFile.deleteSync();
  } on FileSystemException {
    // Someone else broke or released it first. Either way it is gone.
    return true;
  }
  onBrokenLock?.call(
    'Broke an abandoned lock on ${lockFile.path} held by $holder for '
    '${age.inSeconds}s. That writer died inside a mutation, so its last '
    'change may not have been written.',
  );
  return true;
}

/// Releases the guard.
///
/// A failure here is swallowed deliberately: the body has already run, and
/// throwing would report the *work* as failed when only the cleanup was. The
/// staleness recovery in [_acquire] is what covers a guard that outlives its
/// holder, whether through a crash or through this.
void _release(File lockFile) {
  try {
    if (lockFile.existsSync()) lockFile.deleteSync();
  } catch (_) {
    // Left behind; the next acquirer will break it once it goes stale.
  }
}
