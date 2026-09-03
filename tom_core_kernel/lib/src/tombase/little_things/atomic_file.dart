/// Crash-safe whole-file writes for the kernel's file-backed stores.
///
/// Two stores in this package mirror an in-memory collection to a JSON file on
/// every mutation — `TomFileJobStore` for the scheduler's durable queue and
/// `TomFileLogReplayStore` for buffered log records. Both rewrite the file
/// whole, and both are read back by a loader that can do nothing with a
/// truncated array but discard it. A plain overwrite therefore turns any
/// interruption mid-write — a kill, a power loss, a full disk — into *silent
/// total loss* of exactly the data the store existed to protect.
///
/// This library holds the one write routine both of them use.
///
/// The library is internal: it is not exported from `tom_core_kernel.dart`,
/// because "how a store reaches the disk" is not something a caller should be
/// reaching for. It imports `dart:io` and is safe to keep here only because
/// nothing web-facing imports it.
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:io';
import 'dart:math';

// =============================================================================
// Writer identity
// =============================================================================

/// Identifies *this isolate* among everything that might write the same file.
///
/// A process id is not enough. Every isolate in a process reports the same
/// [pid], so naming a per-writer file after the pid alone gives two isolates
/// one name — and for the staging file below that means one isolate's rename
/// publishes, or destroys, the file the other is still writing.
///
/// The random half is what separates isolates, and it must be *unpredictably*
/// random rather than merely varied: this is computed once per isolate, and
/// isolates spawned in the same instant would draw the same seed from a
/// time-based generator and collide exactly when concurrency is highest.
final String tomFileWriterId =
    '$pid-${Random.secure().nextInt(1 << 32).toRadixString(36)}';

// =============================================================================
// Atomic write
// =============================================================================

/// The sibling path [tomWriteFileAtomically] stages the new content at before
/// renaming it over [path].
///
/// The writer's identity is part of the name on purpose. A staging name shared
/// between writers lets one writer's rename publish another's half-written
/// file — reintroducing, between writers, the very truncation this library
/// exists to prevent. One name per writer per target also means staging files
/// cannot accumulate: a writer reuses its own.
String tomAtomicWriteTempPath(String path) => '$path.$tomFileWriterId.tmp';

/// Writes [contents] to [file] so a reader sees either the complete previous
/// content or the complete new content, never a blend of the two.
///
/// The bytes go to the sibling staging file named by [tomAtomicWriteTempPath],
/// flushed so they are on the device rather than in the OS write-back cache,
/// and that file is then renamed over [file]. Rename within a directory is
/// atomic, which is what buys the guarantee: the target is only ever replaced
/// by a file that was already written in full.
///
/// Missing parent directories are created.
///
/// Throws whatever the underlying filesystem operation throws — a caller that
/// cannot persist must find out. If the staging write fails part-way, the
/// partial file is removed before the error propagates, so a full disk does not
/// leave debris that makes the next attempt harder.
void tomWriteFileAtomically(File file, String contents) {
  file.parent.createSync(recursive: true);
  final temp = File(tomAtomicWriteTempPath(file.path));
  try {
    temp.writeAsStringSync(contents, flush: true);
    temp.renameSync(file.path);
  } catch (_) {
    // Cleanup only. The original error is what the caller needs to see, so a
    // failure to tidy up must not replace it.
    try {
      if (temp.existsSync()) temp.deleteSync();
    } catch (_) {
      // Nothing further to try; the staging file is inert either way.
    }
    rethrow;
  }
}
