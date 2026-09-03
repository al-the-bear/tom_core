/// File-backed [TomLogReplayStore] for durable replay buffering.
///
/// This library provides a persistent replay store so records that failed
/// every send attempt survive a process restart while the remote endpoint is
/// down — the one edge the in-memory store cannot cover. The queue is mirrored
/// to a JSON file on every mutation and reloaded from that file when the store
/// is constructed, so a fresh process pointed at the same path resumes with the
/// records that were buffered before it exited.
///
/// It is entirely opt-in: assign an instance to
/// [TomRemoteLogOutput.globalSettingReplayStore] to enable durability. The
/// default stays the zero-config in-memory store.
library;

// =============================================================================
// Imports
// =============================================================================

import 'dart:convert';
import 'dart:io';

import 'package:tom_basics/tom_basics.dart';

import '../little_things/atomic_file.dart';
import '../little_things/file_mutex.dart';
import 'remote_logoutput.dart';

// =============================================================================
// File-backed Replay Store
// =============================================================================

/// A [TomLogReplayStore] that persists buffered records to a JSON file.
///
/// Records are held in memory for fast access and mirrored to [file] on every
/// mutation (`flush: true`, so the bytes reach disk before the call returns).
/// Constructing the store reloads any records previously written to [file], so
/// buffered records survive a process restart during an endpoint outage.
///
/// The on-disk format is a JSON array of objects, one per [TomRemoteLogMessage]
/// — a self-contained encoding kept here (rather than on the message type) so
/// the reflected/bridged surface of [TomRemoteLogMessage] is not affected.
///
/// ## Writes are atomic
///
/// Each mutation writes the whole queue to a sibling temp file and renames it
/// into place. Rename within a directory is atomic, so a process killed
/// mid-write leaves either the previous queue or the new one — never a
/// half-written array.
///
/// ## The file may be shared
///
/// Two stores on one path — a worker isolate and the isolate that spawned it,
/// or a restarted process overlapping the one it replaces — are safe. Every
/// operation re-reads the file and every mutation runs under a sibling lock
/// (see [tomWithFileLock]), so a mutation applies to what is on disk *now*
/// rather than to a snapshot taken when this store was constructed. Without
/// that, each owner would rewrite the file whole from its own stale copy and
/// the later write would erase the other's records silently — the worst
/// failure available to a store whose entire purpose is that records survive.
///
/// [length], [snapshot] and [oldest] therefore answer from the file, not from
/// memory, and cost a read. That is deliberate: an owner that reported its own
/// private count would make [oldest] and [removeOldest] disagree about which
/// record is the oldest, and the drain loop would then delete a record it had
/// never sent.
///
/// What sharing does *not* buy is exactly-once delivery. Two owners draining
/// concurrently can both read the same [oldest] before either removes it, and
/// both will send it. A duplicated log record is a nuisance; a lost one is the
/// failure this store exists to prevent, and the two cannot both be excluded
/// without coordination the kernel deliberately has no room for.
///
/// ## A damaged file never blocks startup
///
/// Construction cannot throw on account of the file's content. This store is
/// normally wired up during startup, so a constructor that threw would let a
/// past crash prevent the next start: the durable buffer would take down the
/// process it exists to protect. Instead, an unreadable file is handled by
/// salvaging what can be read, moving the previous content aside to
/// `<path>.corrupt` so it is preserved for diagnosis rather than overwritten,
/// and reporting the loss — the path, what went wrong, and how many entries
/// were dropped — through [TomRemoteLogOutput.globalSettingFallbackOutput].
///
/// How much survives depends on where the damage is. A well-formed array with
/// unusable entries keeps its usable records, so partial damage does not
/// present as an empty queue. Anything the decoder cannot parse at all — a
/// truncated array, unreadable bytes, a non-list top level — yields an empty
/// queue, because JSON parses all-or-nothing and a half-written array has no
/// readable prefix. That case is the one a crash produces, which is why the
/// atomic write above matters: preventing the truncation is what saves those
/// records, since recovery cannot.
///
/// An empty or missing file is not damage and is not reported.
class TomFileLogReplayStore implements TomLogReplayStore {
  /// The file the queue is mirrored to and reloaded from.
  final File file;

  /// The guard held for the duration of every operation.
  final File _lockFile;

  /// The queue as of the operation currently running.
  ///
  /// A working copy rather than a cache: [_guarded] refills it from the file at
  /// the start of every operation, because the file may have been changed by
  /// another owner since the last one.
  final List<TomRemoteLogMessage> _records = [];

  /// Creates a store backed by [path], loading any previously persisted
  /// records so the queue resumes where a prior process left off.
  ///
  /// Never throws because of the file's content: see the class documentation
  /// for how a damaged file is salvaged, quarantined and reported.
  TomFileLogReplayStore(String path)
    : file = File(path),
      _lockFile = File(tomFileLockPath(path)) {
    _guarded(() {});
  }

  @override
  int get length => _guarded(() => _records.length);

  @override
  void append(TomRemoteLogMessage message) => _guarded(() {
    _records.add(message);
    _persist();
  });

  @override
  List<TomRemoteLogMessage> snapshot() => _guarded(() => List.of(_records));

  @override
  TomRemoteLogMessage? get oldest =>
      _guarded(() => _records.isEmpty ? null : _records.first);

  @override
  void removeOldest() => _guarded(() {
    if (_records.isEmpty) return;
    _records.removeAt(0);
    _persist();
  });

  @override
  void trim(int maxSize) => _guarded(() {
    if (maxSize <= 0) {
      _records.clear();
      _persist();
      return;
    }
    if (_records.length <= maxSize) return;
    while (_records.length > maxSize) {
      _records.removeAt(0);
    }
    _persist();
  });

  @override
  void clear() => _guarded(() {
    _records.clear();
    _persist();
  });

  /// Runs [operation] holding the lock, over a queue freshly read from [file].
  ///
  /// This is the whole of the sharing story. Reading inside the guard is what
  /// makes a mutation a read-modify-write of the *current* file rather than a
  /// rewrite from whatever this owner last saw, and it is why reads are guarded
  /// too: [oldest] and [removeOldest] are consecutive calls in the drain loop,
  /// and one answering from memory while the other rewrites the file would let
  /// the loop delete a record it had never sent.
  ///
  /// Not reentrant — no operation may call another. Each is written against
  /// [_records] directly for that reason, including [trim]'s clearing branch,
  /// which would otherwise delegate to [clear] and deadlock on the guard this
  /// call already holds.
  T _guarded<T>(T Function() operation) => tomWithFileLock(
    _lockFile,
    () {
      _records.clear();
      _load();
      return operation();
    },
    onBrokenLock: _report,
  );

  /// Where damaged content is moved so the next [_persist] cannot overwrite
  /// the evidence of what was lost.
  String get _corruptPath => '${file.path}.corrupt';

  /// Reads and decodes records from [file] if it exists, appending them to the
  /// (already emptied) working copy. Called from [_guarded], so it runs at the
  /// start of every operation and always with the lock held.
  ///
  /// This method never throws. It first runs from the constructor, and the
  /// store is normally built during startup wiring, so a throw here would turn
  /// a past crash into a boot failure — the durable buffer would take down the
  /// very process it exists to protect. Every unreadable state instead degrades
  /// to "carry on with what could be salvaged, and say what was lost".
  ///
  /// Damage is reported once, not once per operation: [_recoverFrom] moves the
  /// unreadable content aside and writes the salvaged records back, so the next
  /// read finds a healthy file.
  void _load() {
    if (!file.existsSync()) return;

    final String raw;
    try {
      raw = file.readAsStringSync();
    } catch (error) {
      // Unreadable bytes (permissions, invalid UTF-8) — nothing to salvage.
      _recoverFrom('could not be read ($error)');
      return;
    }
    // A zero-byte file is what a create-then-crash leaves behind. It holds no
    // records, but nothing was lost either, so it is not corruption.
    if (raw.trim().isEmpty) return;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      // The shape a crash mid-write actually produces: a truncated array.
      _recoverFrom('could not be read (invalid JSON: $error)');
      return;
    }
    if (decoded is! List) {
      _recoverFrom(
        'could not be read (expected a JSON array, got '
        '${decoded.runtimeType})',
      );
      return;
    }

    var skipped = 0;
    for (final entry in decoded) {
      if (entry is Map<String, Object?>) {
        _records.add(_decodeReplayRecord(entry));
      } else {
        skipped++;
      }
    }
    if (skipped > 0) {
      // Partial corruption used to present as "the queue was empty". Keep what
      // is readable, and count what is not rather than dropping it in silence.
      _recoverFrom(
        'contained $skipped unreadable '
        '${skipped == 1 ? 'entry' : 'entries'} which were dropped '
        '(${_records.length} recovered)',
      );
    }
  }

  /// Reports the loss described by [detail], moves the damaged file aside to
  /// [_corruptPath], and writes whatever was salvaged back to [file].
  ///
  /// The rewrite is what makes a partial recovery real: the original has just
  /// been renamed away, so without it the salvaged records would live only in
  /// memory and be lost at the next restart.
  void _recoverFrom(String detail) {
    String outcome;
    try {
      // rename, not delete: the unreadable content is the only evidence of
      // what was in the queue, and it is worth more than the disk space.
      file.renameSync(_corruptPath);
      outcome = 'its previous content was moved to $_corruptPath';
    } catch (error) {
      // Say why. "Could not be moved aside" on its own leaves the reader
      // unable to tell a permissions problem from a full disk.
      outcome = 'its previous content could not be moved aside ($error)';
    }
    try {
      _persist();
    } catch (error) {
      outcome =
          '$outcome, and the salvaged records could not be '
          'written back ($error)';
    }
    _report('Log replay file ${file.path} $detail; $outcome');
  }

  /// Writes [message] to the remote output's fallback — the module's channel
  /// for failures of the logging path itself.
  ///
  /// Never throws: the fallback is part of that same path and can be broken
  /// too, and reporting a loss must not become a second, larger failure.
  void _report(String message) {
    try {
      TomRemoteLogOutput.globalSettingFallbackOutput.output(
        TomLogLevel.warn,
        TomLogLevel.warn,
        'WARN  ',
        // Collapsed to one line: a decoder's complaint carries the offending
        // text and its caret on separate lines, and a warning split over four
        // lines is one a reader cannot grep for.
        message.replaceAll(RegExp(r'\s+'), ' ').trim(),
        TomPlatformUtils.current.getIsolateName(),
        DateTime.now(),
        null,
      );
    } catch (error) {
      // Nothing left to report to.
    }
  }

  /// Writes the current queue to [file], creating parent directories as needed
  /// and flushing so the bytes reach disk before returning.
  ///
  /// The write is atomic — see [tomWriteFileAtomically] — so a process killed
  /// mid-write leaves either the old queue or the new one, never the
  /// half-written array that [_load] would have to throw away.
  void _persist() {
    final encoded = jsonEncode(_records.map(_encodeReplayRecord).toList());
    tomWriteFileAtomically(file, encoded);
  }
}

// =============================================================================
// Record serialization
// =============================================================================

/// Encodes a [TomRemoteLogMessage] into a JSON-native map.
///
/// Kept here rather than on [TomRemoteLogMessage] so the message type's
/// reflected/bridged surface stays unchanged.
Map<String, Object?> _encodeReplayRecord(TomRemoteLogMessage message) => {
  'sender': message.sender,
  'timeStamp': message.timeStamp,
  'loggerLevel': message.loggerLevel,
  'logLevel': message.logLevel,
  'level': message.level,
  'message': message.message,
  'isolateName': message.isolateName,
  'origin': message.origin,
};

/// Decodes a map produced by [_encodeReplayRecord] back into a message,
/// defaulting any missing or mistyped fields to their empty values.
TomRemoteLogMessage _decodeReplayRecord(Map<String, Object?> map) {
  return TomRemoteLogMessage()
    ..sender = _asString(map['sender'])
    ..timeStamp = _asString(map['timeStamp'])
    ..loggerLevel = _asInt(map['loggerLevel'])
    ..logLevel = _asInt(map['logLevel'])
    ..level = _asString(map['level'])
    ..message = _asString(map['message'])
    ..isolateName = _asString(map['isolateName'])
    ..origin = map['origin'] is String ? map['origin'] as String : null;
}

String _asString(Object? value) => value is String ? value : '';

int _asInt(Object? value) => value is int ? value : 0;
