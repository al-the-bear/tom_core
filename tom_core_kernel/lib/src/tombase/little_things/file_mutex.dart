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
/// other keeps waiting. Breakers take turns through a second, sibling guard and
/// re-read the guard before deleting it, so the loser of that race cannot then
/// delete the winner's fresh guard. And a writer releases only a guard that
/// still carries its own acquisition token: one whose guard was broken while it
/// worked leaves the new holder's alone.
///
/// The timeout is generous because it is bounded from below by real work: a
/// critical section here is a small read, an encode and one atomic write, so
/// a guard that has stood unchanged for ten seconds is not slow, it is
/// abandoned.
///
/// It imports `dart:io`, so it is not part of the platform-neutral package
/// barrel. A framework store outside the kernel that needs the same guard —
/// `tom_core_flutter`'s file-backed client configuration — reaches the public
/// half, [tomWithFileLock], [tomWithFileLockAsync], [tomFileLockPath] and
/// [tomFileLockStaleAfter], through `package:tom_core_kernel/tom_core_kernel_io.dart`,
/// which only native code may import.
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:io';
import 'dart:math';

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

/// The source of each acquisition's token suffix: secure, so tokens drawn in
/// the same instant by different isolates do not collide.
final Random _tokenRandom = Random.secure();

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
/// Waits synchronously, sleeping between attempts. That suits the kernel's
/// own file-backed stores, which present a synchronous contract; code running
/// on an isolate that must stay responsive while it waits — a UI isolate —
/// wants [tomWithFileLockAsync].
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
  final token = _newToken();
  final deadline = DateTime.now().add(timeout);
  while (!_attempt(lockFile, token, staleAfter, onBrokenLock)) {
    _failIfPast(deadline, lockFile, timeout);
    sleep(_retryInterval);
  }
  try {
    return body();
  } finally {
    _release(lockFile, token);
  }
}

/// [tomWithFileLock] for a caller that must not block its isolate while it
/// waits: the waits between attempts are [Future.delayed], and [body] may be
/// asynchronous.
///
/// The exclusion is the same guard file, so it holds against every other
/// holder of [lockFile] — another asynchronous task on this isolate as much as
/// another isolate or process: the second task's exclusive create fails while
/// the first holds the guard, exactly as a foreign process's would. Between
/// the awaits of [body] the isolate runs other code, and that is the price of
/// not blocking: code that must not run inside the critical section has to
/// take the same guard to be kept out.
Future<T> tomWithFileLockAsync<T>(
  File lockFile,
  Future<T> Function() body, {
  Duration staleAfter = tomFileLockStaleAfter,
  Duration timeout = const Duration(seconds: 30),
  void Function(String warning)? onBrokenLock,
}) async {
  final token = _newToken();
  final deadline = DateTime.now().add(timeout);
  while (!_attempt(lockFile, token, staleAfter, onBrokenLock)) {
    _failIfPast(deadline, lockFile, timeout);
    await Future<void>.delayed(_retryInterval);
  }
  try {
    return await body();
  } finally {
    _release(lockFile, token);
  }
}

/// A token naming one acquisition: the writer and a random suffix.
///
/// It is what lets [_release] and [_breakIfAbandoned] tell this guard from a
/// later one standing at the same path. Without it, a guard file is just a
/// name, and deleting "the guard" can delete somebody else's.
String _newToken() =>
    '$tomFileWriterId#${_tokenRandom.nextInt(1 << 32).toRadixString(36)}';

/// Throws the timeout failure once [deadline] has passed.
void _failIfPast(DateTime deadline, File lockFile, Duration timeout) {
  if (!DateTime.now().isAfter(deadline)) return;
  throw FileSystemException(
    'Could not acquire the lock on ${lockFile.path} within '
    '${timeout.inSeconds}s — another writer is holding it and is not '
    'making progress. Nothing was written.',
    lockFile.path,
  );
}

/// One attempt to take [lockFile] for [token], never waiting: `true` when this
/// writer now holds it.
///
/// Both waiters share it, so the synchronous and the asynchronous lock are one
/// lock with two ways of passing the time between attempts.
bool _attempt(
  File lockFile,
  String token,
  Duration staleAfter,
  void Function(String warning)? onBrokenLock,
) {
  while (true) {
    try {
      lockFile.parent.createSync(recursive: true);
      lockFile.createSync(exclusive: true);
      // Whose guard this is: for whoever finds it abandoned, and for this
      // writer's own release, which deletes the guard only while it still
      // holds this token. Best-effort: the guard is already held by this
      // point, and failing to annotate it must not fail the acquire — a guard
      // without a token is released by no one and is broken once stale.
      try {
        lockFile.writeAsStringSync(token, flush: true);
      } catch (_) {
        // The token is a safeguard, not the lock.
      }
      return true;
    } on FileSystemException {
      // Someone holds it. Break it if it has been abandoned, then race for it
      // again at once on equal terms with everyone else that was waiting.
      if (!_breakIfAbandoned(lockFile, staleAfter, onBrokenLock)) return false;
    }
  }
}

/// Deletes [lockFile] if it has stood unchanged for longer than [staleAfter],
/// returning whether the caller should retry immediately.
///
/// Breaking only removes the obstacle; the caller still has to win the
/// exclusive create afterwards. That is what keeps two simultaneous breakers
/// from both concluding they hold the guard.
///
/// **Breakers take turns.** Deciding a guard is stale and deleting it are two
/// steps, and between them another waiter can break the same guard and take
/// the path with a fresh one of its own — which the first breaker's delete then
/// removes, letting a third writer in beside a live holder. So a breaker first
/// wins a second, sibling guard ([_breakPath]) by the same exclusive create,
/// and only then re-reads the guard and deletes it if it is still stale. A
/// guard broken and re-taken in the meantime is fresh, so it survives the
/// re-read. Nothing else deletes the guard while the
/// break guard is held — the holder of an abandoned guard is dead, and every
/// other breaker is waiting — so what was re-read is what is deleted.
///
/// The break guard is held for the length of one read and one delete. A
/// breaker killed inside that window would orphan it, so a break guard older
/// than [staleAfter] is cleared like any other.
bool _breakIfAbandoned(
  File lockFile,
  Duration staleAfter,
  void Function(String warning)? onBrokenLock,
) {
  final _GuardReading? seen = _read(lockFile);
  // Released while we looked at it — retry, the guard is free.
  if (seen == null) return true;
  if (DateTime.now().difference(seen.modified) < staleAfter) return false;

  final breakGuard = File(_breakPath(lockFile.path));
  try {
    breakGuard.createSync(exclusive: true);
  } on FileSystemException {
    // Another waiter is breaking it. Wait our turn, clearing a break guard
    // whose breaker died, since it would otherwise block every waiter.
    final turn = _read(breakGuard);
    if (turn != null &&
        DateTime.now().difference(turn.modified) >= staleAfter) {
      try {
        breakGuard.deleteSync();
      } on FileSystemException {
        // Cleared by someone else.
      }
    }
    return false;
  }
  try {
    final now = _read(lockFile);
    // Gone: the breaker before us broke it. Retry for the path.
    if (now == null) return true;
    // Fresh: the breaker before us broke it and the path was taken again.
    // Wait for that holder like everyone else.
    if (DateTime.now().difference(now.modified) < staleAfter) return false;
    try {
      lockFile.deleteSync();
    } on FileSystemException {
      return true;
    }
  } finally {
    try {
      breakGuard.deleteSync();
    } on FileSystemException {
      // Left behind; cleared once stale.
    }
  }
  onBrokenLock?.call(
    'Broke an abandoned lock on ${lockFile.path} held by '
    '${seen.token.isEmpty ? 'unknown' : seen.token} for '
    '${DateTime.now().difference(seen.modified).inSeconds}s. That writer died '
    'inside a mutation, so its last change may not have been written.',
  );
  return true;
}

/// The guard that serializes breakers of the guard at [lockPath].
String _breakPath(String lockPath) => '$lockPath.break';

/// What a guard file says about its holder, or `null` when there is no file.
final class _GuardReading {
  _GuardReading(this.token, this.modified);

  /// The holder's acquisition token; empty in the instant between the
  /// exclusive create and the write that names it.
  final String token;

  /// When the guard was last written.
  final DateTime modified;
}

_GuardReading? _read(File guard) {
  try {
    final modified = guard.lastModifiedSync();
    return _GuardReading(guard.readAsStringSync().trim(), modified);
  } on FileSystemException {
    return null;
  }
}

/// Releases the guard, if it is still this acquisition's.
///
/// A guard whose token is not [token] belongs to someone else: this writer's
/// guard was broken as stale while it worked, and the path now holds a live
/// guard of another writer's. Deleting it would let a third writer in beside
/// that one, so it is left alone.
///
/// A failure here is swallowed deliberately: the body has already run, and
/// throwing would report the *work* as failed when only the cleanup was. The
/// staleness recovery in [_attempt] is what covers a guard that outlives its
/// holder, whether through a crash or through this.
void _release(File lockFile, String token) {
  try {
    if (lockFile.readAsStringSync().trim() == token) lockFile.deleteSync();
  } catch (_) {
    // Gone already, or left behind; the next acquirer breaks it once stale.
  }
}
