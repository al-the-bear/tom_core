/// Where audit records go, and how long they stay there (CE-LG).
///
/// The sink is deliberately a separate concern from the trail that produces
/// records. Deployments differ in what they are obliged to keep and for how
/// long — a test wants the last few entries in memory, a regulated production
/// server wants years of append-only files, a bank wants a WORM appliance — and
/// none of that should reach the code that *emits* the records.
///
/// ### Why not just write to the log
///
/// The kernel's logging subsystem rotates by size, drops by level, and is
/// expected to be truncated by an operator who needs disk back. Every one of
/// those is correct for diagnostics and fatal for an audit trail: a trail with
/// a hole in it cannot be distinguished from a trail that was tampered with,
/// so a trail that permits holes proves nothing. The sinks here therefore
/// **append only**, rotate by *moving aside* rather than truncating, and chain
/// each entry to its predecessor by hash.
///
/// ### The hash chain
///
/// Each written entry carries the hash of the previous entry, and its own hash
/// covers both that link and its own content. An entry that is edited, removed
/// or reordered after the fact breaks the chain at that point and at every
/// point after it, which [verifyAuditChain] reports.
///
/// This is *tamper-evidence*, not tamper-proofing. Someone with write access
/// to the files and the algorithm can rewrite the whole chain from the point
/// of the edit onwards. Making that impossible needs an external anchor — a
/// countersigning service, a WORM volume, periodic publication of the head
/// hash — which is a deployment decision rather than a framework one. What the
/// chain buys unconditionally is that a *partial* edit, which is what accident
/// and casual malice both produce, cannot go unnoticed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../little_things/server_exception.dart';
import 'audit_record.dart';

/// Raised when the audit trail cannot do its job.
///
/// Audit failures are **not** client-visible: the caller of an audited action
/// has no business learning that the trail is misconfigured, and the message
/// would describe server-side storage. Hence `clientThrow: false` by default.
class TomAuditException extends TomServerException {
  /// Creates an audit exception.
  TomAuditException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.rootException,
    super.stack,
    super.clientThrow = false,
  });
}

/// The hash a chain starts from, before any entry has been written.
///
/// Sixty-four zeros — the shape of a SHA-256 digest, so a reader never has to
/// special-case the first entry's `previousHash` field.
const String tomAuditGenesisHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

/// A [TomAuditRecord] together with its position in the hash chain.
///
/// The entry — not the record — is what a sink stores, because the chain link
/// only means anything in the context of a particular sink's sequence. The
/// same record written to two sinks legitimately has two different hashes.
class TomAuditEntry {
  /// The audited record.
  final TomAuditRecord record;

  /// The hash of the preceding entry, or [tomAuditGenesisHash] for the first.
  final String previousHash;

  /// This entry's hash, covering [previousHash] and the record's canonical
  /// JSON.
  final String hash;

  /// This entry's zero-based position in the chain, counted from genesis.
  ///
  /// Stored rather than inferred from the entry's offset in whatever the reader
  /// happens to hold, because retention makes those two different numbers. Once
  /// a prefix has been pruned, an offset says where an entry sits in the
  /// *surviving suffix*; the index still says where it sat in the chain. Anchor
  /// verification is a claim about a position ([TomAuditAnchor.entryCount]), so
  /// without this a pruned prefix and a rewritten one look alike — and a check
  /// that reports tampering on every retention pass is one operators learn to
  /// ignore.
  ///
  /// Deliberately outside the hashed payload: [hashOf] covers the link and the
  /// record, so adding the index neither changes existing digests nor lets a
  /// renumbering forge one.
  final int index;

  /// Creates an entry from its parts. Prefer [TomAuditEntry.chain].
  const TomAuditEntry({
    required this.record,
    required this.previousHash,
    required this.hash,
    required this.index,
  });

  /// Links [record] onto a chain whose head is [previousHash], at [index].
  factory TomAuditEntry.chain(
    TomAuditRecord record,
    String previousHash, {
    required int index,
  }) => TomAuditEntry(
    record: record,
    previousHash: previousHash,
    hash: hashOf(record, previousHash),
    index: index,
  );

  /// The hash of [record] linked onto [previousHash].
  ///
  /// The record's canonical JSON is the hashed content — canonical because
  /// [TomAuditRecord.toJson] fixes key order, so re-encoding the same record
  /// twice cannot produce two different digests.
  static String hashOf(TomAuditRecord record, String previousHash) => sha256
      .convert(utf8.encode('$previousHash|${jsonEncode(record.toJson())}'))
      .toString();

  /// Whether [hash] actually matches the record and link this entry claims.
  bool get isSelfConsistent => hash == hashOf(record, previousHash);

  /// The entry as a JSON map: the position, the chain link, then the record.
  Map<String, Object?> toJson() => {
    'index': index,
    'previousHash': previousHash,
    'hash': hash,
    'record': record.toJson(),
  };

  /// Rebuilds an entry from [json] as written by [toJson].
  ///
  /// Every field is required. Nothing here is defaulted, because a default
  /// does not produce a vague entry — it produces a **specific accusation**
  /// about a record nobody touched, and an investigation that starts from the
  /// wrong finding goes somewhere else entirely:
  ///
  /// - A guessed `index` guesses the entry's position, which is precisely what
  ///   anchor verification is built on — it would turn a truncated trail into
  ///   a merely short one.
  /// - A defaulted `hash` reads back as an entry whose stored hash does not
  ///   match its contents, which [verifyAuditChain] reports as *content
  ///   changed after writing*: the signature of an edited record.
  /// - A defaulted `previousHash` claims the entry began a chain. Mid-chain
  ///   that is a link mismatch — *an entry was removed or reordered here* —
  ///   and at the head it is not a finding at all: the entry is self-consistent
  ///   against the link it was handed, so damage verifies as health.
  ///
  /// The hashes are also refused when present but empty, since the empty string
  /// was the old default and an empty hash is not a short hash but an absent
  /// one. The unnamed constructor cannot enforce any of this — it is `const` —
  /// so this factory is where storage that has been damaged, hand-edited or
  /// written by something other than [toJson] is turned away. That is what lets
  /// [parseAuditLines] promise that a line it cannot read is reported rather
  /// than silently reinterpreted.
  factory TomAuditEntry.fromJson(Map<String, Object?> json) {
    final index = json['index'];
    if (index is! int) {
      throw TomAuditException(
        'audit.entry.missing_index',
        'Audit entry has no chain index, so its position cannot be known.',
      );
    }
    final previousHash = _requiredHash(
      json,
      'previousHash',
      'audit.entry.missing_previous_hash',
      'Audit entry has no link to its predecessor, so its place in the chain '
          'cannot be checked.',
    );
    final hash = _requiredHash(
      json,
      'hash',
      'audit.entry.missing_hash',
      'Audit entry has no hash, so nothing states what its contents were.',
    );
    final record = json['record'];
    if (record is! Map) {
      throw TomAuditException(
        'audit.entry.missing_record',
        'Audit entry has no record, so there is nothing to attest to.',
      );
    }
    return TomAuditEntry(
      record: TomAuditRecord.fromJson(record.cast<String, Object?>()),
      previousHash: previousHash,
      hash: hash,
      index: index,
    );
  }

  /// Reads a chain-hash field from [json], refusing anything that is not one.
  static String _requiredHash(
    Map<String, Object?> json,
    String field,
    String key,
    String message,
  ) {
    final value = json[field];
    if (value is! String || value.isEmpty) {
      throw TomAuditException(key, message, parameters: {'field': field});
    }
    return value;
  }

  /// The entry as one line of JSON, with no embedded newline.
  ///
  /// The storage format is JSON Lines precisely because appending a line is
  /// the one file operation that cannot corrupt what came before it.
  String toJsonLine() => jsonEncode(toJson());

  @override
  String toString() => '${record.toString()} [${hash.substring(0, 8)}]';
}

/// The outcome of checking a chain's integrity.
class TomAuditChainVerification {
  /// Whether every entry linked and hashed correctly.
  final bool isValid;

  /// How many entries were checked.
  final int entryCount;

  /// The zero-based index of the first entry that failed, or `null`.
  final int? brokenAtIndex;

  /// What went wrong at [brokenAtIndex], or `null` when [isValid].
  final String? detail;

  /// Creates a verification result.
  const TomAuditChainVerification({
    required this.isValid,
    required this.entryCount,
    this.brokenAtIndex,
    this.detail,
  });

  @override
  String toString() => isValid
      ? 'audit chain valid ($entryCount entries)'
      : 'audit chain BROKEN at entry $brokenAtIndex of $entryCount: $detail';
}

/// Checks that [entries] form an unbroken chain from [startHash].
///
/// Three distinct failures are reported, because they mean different things:
/// a self-inconsistent entry says *this record was edited*; a broken link says
/// *an entry was removed, inserted or reordered here*; and a jump in
/// [TomAuditEntry.index] says *the chain was renumbered*.
///
/// The index check is not redundant. The index sits outside the hashed payload
/// — deliberately, so that adding it did not invalidate every existing digest —
/// which means it is the one field an attacker can rewrite without breaking a
/// single hash. Left unchecked, renumbering would silently slide the window
/// that [verifyAgainstAnchor] compares against, and an anchored position could
/// be made to point at a different entry.
TomAuditChainVerification verifyAuditChain(
  Iterable<TomAuditEntry> entries, {
  String startHash = tomAuditGenesisHash,
}) {
  var expectedPrevious = startHash;
  var offset = 0;
  int? expectedIndex;
  for (final entry in entries) {
    if (entry.previousHash != expectedPrevious) {
      return TomAuditChainVerification(
        isValid: false,
        entryCount: offset + 1,
        brokenAtIndex: offset,
        detail:
            'link mismatch: expected previousHash $expectedPrevious, '
            'found ${entry.previousHash}',
      );
    }
    if (!entry.isSelfConsistent) {
      return TomAuditChainVerification(
        isValid: false,
        entryCount: offset + 1,
        brokenAtIndex: offset,
        detail: 'content changed after writing: hash does not match record',
      );
    }
    if (expectedIndex != null && entry.index != expectedIndex) {
      return TomAuditChainVerification(
        isValid: false,
        entryCount: offset + 1,
        brokenAtIndex: offset,
        detail:
            'chain renumbered: expected index $expectedIndex, '
            'found ${entry.index}',
      );
    }
    expectedPrevious = entry.hash;
    expectedIndex = entry.index + 1;
    offset++;
  }
  return TomAuditChainVerification(isValid: true, entryCount: offset);
}

/// Parses JSON-Lines audit storage, skipping blank lines.
///
/// Throws [TomAuditException] on a line that is not a valid entry — a
/// malformed line in an audit file is itself a finding, and silently dropping
/// it would hide exactly the damage the chain exists to reveal.
List<TomAuditEntry> parseAuditLines(Iterable<String> lines) {
  final entries = <TomAuditEntry>[];
  var lineNumber = 0;
  for (final line in lines) {
    lineNumber++;
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      entries.add(
        TomAuditEntry.fromJson(
          (jsonDecode(trimmed) as Map).cast<String, Object?>(),
        ),
      );
    } catch (e) {
      throw TomAuditException(
        'audit.parse.malformed_line',
        'Audit storage line $lineNumber is not a readable audit entry: $e',
      );
    }
  }
  return entries;
}

/// Where a [TomAuditRecord] is persisted.
///
/// [write] is expected to **throw** when it cannot store the record. The trail
/// is fail-closed — an action whose audit record could not be stored is not
/// allowed to look like it succeeded — so a sink that swallows its own storage
/// errors defeats the guarantee for everything above it.
abstract class TomAuditSink implements TomClosable {
  /// Persists [record], returning the entry as stored.
  Future<TomAuditEntry> write(TomAuditRecord record);

  /// The hash of the most recently written entry.
  ///
  /// Publishing this head hash somewhere outside the sink's own storage is how
  /// a deployment turns tamper-*evidence* into something an attacker with file
  /// access cannot quietly repair — see [TomAuditAnchor].
  String get headHash;

  /// How many entries have been written to this chain since genesis.
  ///
  /// Counted from the stored [TomAuditEntry.index] rather than from how many
  /// entries the sink currently holds, so retention does not move it. Together
  /// with [headHash] this is the pair an anchor records, which is why the two
  /// must be read as one: an anchor claiming a count that belongs to a
  /// different head is worse than no anchor, because it reports a divergence
  /// that never happened.
  int get entryCount;

  /// Closes the sink without waiting for records already queued.
  ///
  /// This is [TomClosable]'s method and inherits its **synchronous** contract,
  /// which is what decides the behaviour: no synchronous method can wait for a
  /// queue, so a record that was enqueued and had not yet started cannot be
  /// stored. It is **refused** — its `write` future completes with
  /// `audit.sink.closed` — rather than dropped or written anyway.
  ///
  /// Refusing is the only honest answer of the three. Writing it anyway means
  /// a sink that is closed is still writing, which for the file sink meant
  /// reopening the file it had just closed. Dropping it means an audited
  /// action reports success with no entry behind it, which is the one outcome
  /// a fail-closed trail exists to prevent. Refusing tells the caller, and the
  /// caller is the code that knows whether the action can still be allowed to
  /// stand.
  ///
  /// Use [flushAndClose] wherever an `await` is available; reach for this one
  /// only from the synchronous shutdown path.
  @override
  void close();

  /// Waits for every queued record to be stored, then closes.
  ///
  /// The counterpart to [close] for callers that have an `await` to spend:
  /// nothing enqueued before the call is refused. Idempotent, and safe to call
  /// after [close] — the sink is already closed and there is nothing left to
  /// drain, so it returns without reopening anything.
  ///
  /// Records enqueued *during* the drain are refused like any other write
  /// after close: the drain would otherwise have no fixed point to reach.
  Future<void> flushAndClose();
}

/// An in-memory sink, bounded by entry count.
///
/// For tests and for development servers where an audit trail is required to
/// exist but not required to survive a restart. Not for production: memory
/// does not survive a crash, and a trail that loses its most interesting
/// entries exactly when the server falls over is not a trail.
class TomMemoryAuditSink implements TomAuditSink {
  /// How many entries are retained before the oldest are dropped.
  final int maxEntries;

  final List<TomAuditEntry> _entries = [];
  String _headHash = tomAuditGenesisHash;
  int _droppedCount = 0;
  int _entryCount = 0;

  /// Creates a memory sink retaining at most [maxEntries] entries.
  TomMemoryAuditSink({this.maxEntries = 1000});

  /// The retained entries, oldest first.
  List<TomAuditEntry> get entries => List.unmodifiable(_entries);

  /// The retained records, oldest first.
  List<TomAuditRecord> get records =>
      _entries.map((e) => e.record).toList(growable: false);

  /// How many entries have been dropped to stay within [maxEntries].
  ///
  /// Exposed rather than hidden: a caller verifying the chain needs to know
  /// that it is verifying a *suffix*, since a suffix cannot start from the
  /// genesis hash.
  int get droppedCount => _droppedCount;

  @override
  String get headHash => _headHash;

  @override
  int get entryCount => _entryCount;

  @override
  Future<TomAuditEntry> write(TomAuditRecord record) async {
    final entry = TomAuditEntry.chain(record, _headHash, index: _entryCount);
    _entries.add(entry);
    _headHash = entry.hash;
    _entryCount++;
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
      _droppedCount++;
    }
    return entry;
  }

  /// Verifies the retained entries.
  ///
  /// When entries have been dropped the check starts from the oldest retained
  /// entry's own link rather than from genesis, so a bounded sink reports the
  /// integrity of what it still has instead of a false break at the front.
  TomAuditChainVerification verify() => verifyAuditChain(
    _entries,
    startHash: _entries.isEmpty ? _headHash : _entries.first.previousHash,
  );

  /// Discards all retained entries and resets the chain.
  ///
  /// Test-support only — clearing an audit trail is not an operation a server
  /// should ever perform on itself.
  void clear() {
    _entries.clear();
    _droppedCount = 0;
    _entryCount = 0;
    _headHash = tomAuditGenesisHash;
  }

  @override
  void close() {}

  /// Nothing to drain: [write] stores the entry before its future completes
  /// and there is no queue behind it.
  @override
  Future<void> flushAndClose() async => close();
}

/// An append-only JSON-Lines file sink with age- and count-based retention.
///
/// Files are named `audit-<yyyy-mm-dd>.jsonl` and rotated when they exceed
/// [maxFileBytes]; a rotated file is **renamed** to
/// `audit-<yyyy-mm-dd>-<n>.jsonl` and never rewritten. Retention deletes whole
/// files that are older than [retention] or that exceed [maxFiles] — deleting
/// a whole file, on a boundary the chain records, is auditable in a way that
/// trimming lines out of a live file is not.
///
/// Rotation sequence numbers are **monotonic for the sink's lifetime and never
/// reused**, including after retention has deleted the file that held one. A
/// scheme that reissued the lowest free number would let a newly rotated file
/// take an older file's name, and file order — which is the order entries are
/// read back in — would stop matching write order.
///
/// The chain **continues across files**: the first entry of a new file links
/// to the last entry of the previous one. So retention leaves a verifiable
/// suffix rather than a set of unrelated fragments, and the missing prefix is
/// visible as such.
class TomFileAuditSink implements TomAuditSink {
  /// The directory the audit files live in.
  final Directory directory;

  /// The byte size at which the current file is rotated.
  final int maxFileBytes;

  /// How long a rotated file is kept.
  final Duration retention;

  /// How many files are kept, regardless of [retention].
  final int maxFiles;

  /// The file name prefix, so several trails can share a directory.
  final String filePrefix;

  IOSink? _sink;
  File? _currentFile;
  int _currentBytes = 0;
  String _headHash = tomAuditGenesisHash;
  int _entryCount = 0;
  bool _closed = false;

  /// True only while [flushAndClose] is waiting for the queue.
  ///
  /// The sink is closed to new records throughout, so this is not a second
  /// "open" state — it is the narrow window in which records enqueued *before*
  /// the close are still allowed to complete.
  bool _draining = false;

  /// The last rotation sequence number handed out. Only ever increases.
  int _rotationSequence = 0;

  /// Serialises writes.
  ///
  /// Each entry's hash depends on the previous entry's, so two concurrent
  /// writes would race for the head and produce a chain that fails its own
  /// verification. Chaining the futures makes the ordering explicit instead of
  /// hoping the event loop is kind.
  Future<void> _queue = Future<void>.value();

  /// Opens (or creates) an audit trail in [directory].
  ///
  /// The head hash is recovered from the newest existing file so that a
  /// restart continues the chain rather than starting a second one.
  TomFileAuditSink({
    required this.directory,
    this.maxFileBytes = 16 * 1024 * 1024,
    this.retention = const Duration(days: 3650),
    this.maxFiles = 512,
    this.filePrefix = 'audit',
  }) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    _rotationSequence = _highestRotationSequence();
    final recovered = _recoverHead();
    _headHash = recovered.hash;
    _entryCount = recovered.entryCount;
  }

  @override
  String get headHash => _headHash;

  @override
  int get entryCount => _entryCount;

  /// The audit files in [directory], oldest first.
  ///
  /// Ordered by day and then by rotation sequence, with the day's *current*
  /// (unrotated) file last for its day, because it is the newest. The order is
  /// computed rather than left to the file names: everything that reads a trail
  /// back — [readAll], [verify], [_recoverHeadHash] and the retention pass —
  /// depends on this being write order, and inferring it from a lexicographic
  /// name sort would make that guarantee hostage to the naming scheme.
  List<File> get files {
    final result = directory
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              p.basename(f.path).startsWith('$filePrefix-') &&
              p.basename(f.path).endsWith('.jsonl'),
        )
        .toList();
    result.sort((a, b) {
      final keyA = _orderKey(a);
      final keyB = _orderKey(b);
      final byDay = keyA.day.compareTo(keyB.day);
      return byDay != 0 ? byDay : keyA.sequence.compareTo(keyB.sequence);
    });
    return result;
  }

  /// Matches a rotated file name: `<prefix>-<yyyy-mm-dd>-<sequence>.jsonl`.
  RegExp get _rotatedNamePattern => RegExp(
    '^${RegExp.escape(filePrefix)}-(\\d{4}-\\d{2}-\\d{2})-0*(\\d+)\\.jsonl\$',
  );

  /// The (day, sequence) pair a file is ordered by.
  ///
  /// A file with no sequence is the day's live file, so it sorts after every
  /// rotated file of that day.
  ({String day, int sequence}) _orderKey(File file) {
    final name = p.basename(file.path);
    final rotated = _rotatedNamePattern.firstMatch(name);
    if (rotated != null) {
      return (day: rotated.group(1)!, sequence: int.parse(rotated.group(2)!));
    }
    final day = p
        .basenameWithoutExtension(name)
        .substring(filePrefix.length + 1);
    return (day: day, sequence: _liveFileSequence);
  }

  /// The order key a day's live file gets: after any rotated file of that day.
  static const int _liveFileSequence = 1 << 40;

  /// The highest rotation sequence already present in [directory].
  ///
  /// Read once at construction so a restart continues numbering instead of
  /// starting again at 1 and colliding with the files it finds.
  int _highestRotationSequence() {
    var highest = 0;
    for (final file in files) {
      final match = _rotatedNamePattern.firstMatch(p.basename(file.path));
      if (match == null) continue;
      final sequence = int.parse(match.group(2)!);
      if (sequence > highest) highest = sequence;
    }
    return highest;
  }

  /// Reads every retained entry, oldest first.
  List<TomAuditEntry> readAll() => [
    for (final file in files) ...parseAuditLines(file.readAsLinesSync()),
  ];

  /// Verifies the retained entries, starting from the oldest retained link.
  ///
  /// Retention may have removed the head of the chain, so verification starts
  /// from what survives — the point is to detect edits within the retained
  /// window, not to complain about a deletion the policy asked for.
  TomAuditChainVerification verify() {
    final entries = readAll();
    return verifyAuditChain(
      entries,
      startHash: entries.isEmpty
          ? tomAuditGenesisHash
          : entries.first.previousHash,
    );
  }

  @override
  Future<TomAuditEntry> write(TomAuditRecord record) {
    if (_closed) throw _closedException();
    final result = _queue.then((_) => _writeSerialised(record));
    // Keep the queue alive on failure: one failed write must not wedge the
    // sink, and the error is delivered to the caller through `result`.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The refusal every closed-sink check raises.
  TomAuditException _closedException() => TomAuditException(
    'audit.sink.closed',
    'Audit sink for ${directory.path} is closed and cannot accept records.',
  );

  /// Whether a record already in the queue may still be written.
  ///
  /// Consulted from the serialised body and again at the one place a file
  /// handle is opened, rather than only from [write] at enqueue time: between
  /// the enqueue and the write lies the whole lifetime of a queued record, and
  /// [close] can land anywhere in it. Checking only on the way in answers for
  /// the moment the caller asked rather than for the moment the write happens,
  /// and those are the same moment only when nothing is queued.
  ///
  /// A closed sink normally refuses. [flushAndClose] is the exception it
  /// exists to be: during the drain the sink is closed to *new* records while
  /// the ones already queued are deliberately allowed through.
  bool get _queueMayProceed => !_closed || _draining;

  Future<TomAuditEntry> _writeSerialised(TomAuditRecord record) async {
    if (!_queueMayProceed) throw _closedException();
    final entry = TomAuditEntry.chain(record, _headHash, index: _entryCount);
    final line = '${entry.toJsonLine()}\n';
    final bytes = utf8.encode(line).length;
    try {
      await _ensureOpen(additionalBytes: bytes);
      _sink!.write(line);
      await _sink!.flush();
    } on TomAuditException {
      // A refusal from `_ensureOpen` is an answer, not a storage failure.
      // Relabelling it `write_failed` would tell the caller the disk let them
      // down when in fact the sink was closed underneath them.
      rethrow;
    } catch (e, stack) {
      throw TomAuditException(
        'audit.sink.write_failed',
        'Could not write the audit record to ${_currentFile?.path}: $e',
        rootException: e,
        stack: stack,
      );
    }
    _currentBytes += bytes;
    _headHash = entry.hash;
    _entryCount++;
    return entry;
  }

  /// Ensures a file is open with room for [additionalBytes], rotating first if
  /// the current one is full.
  ///
  /// Closing the outgoing file is **awaited**: rotation renames the file out
  /// from under the sink, and a rename racing an unflushed buffer is how a
  /// rotation loses the last entries it was supposed to preserve.
  Future<void> _ensureOpen({required int additionalBytes}) async {
    if (_sink != null && _currentBytes + additionalBytes <= maxFileBytes) {
      return;
    }
    if (_sink != null) {
      final outgoing = _sink!;
      _sink = null;
      await outgoing.flush();
      await outgoing.close();
      _rotate();
    }
    _currentFile = File(
      p.join(directory.path, '$filePrefix-${_today()}.jsonl'),
    );
    _currentBytes = _currentFile!.existsSync() ? _currentFile!.lengthSync() : 0;
    if (_currentBytes + additionalBytes > maxFileBytes) {
      _rotate();
      _currentBytes = 0;
    }
    // The one place a file handle comes into existence, and therefore the
    // place the closed check has to be repeated: rotation above awaits, so
    // `close()` can land in the middle of this method. Resuming afterwards
    // would open a handle on a sink that is already closed — and the caller
    // that closed it has no way to learn a new one exists.
    if (!_queueMayProceed) throw _closedException();
    _sink = _currentFile!.openWrite(mode: FileMode.append);
    _applyRetention();
  }

  /// Moves the current file aside under the next rotation sequence number.
  ///
  /// Renaming rather than truncating is the whole point: the bytes already
  /// written are never touched again, so rotation cannot lose or alter an
  /// entry the way a size-capped log rotation legitimately does.
  ///
  /// The sequence only ever advances. Reusing a number freed by retention
  /// would give a newly rotated file the name of an older one, and the trail
  /// would then read back out of write order — which the chain reports as a
  /// break, indistinguishable from tampering.
  void _rotate() {
    final file = _currentFile;
    if (file == null || !file.existsSync()) return;
    final base = p.basenameWithoutExtension(file.path);
    File target;
    do {
      _rotationSequence++;
      target = File(
        p.join(
          directory.path,
          '$base-${_rotationSequence.toString().padLeft(6, '0')}.jsonl',
        ),
      );
    } while (target.existsSync());
    file.renameSync(target.path);
  }

  void _applyRetention() {
    final now = DateTime.now();
    final all = files;
    final current = _currentFile?.path;
    for (final file in all) {
      if (file.path == current) continue;
      final age = now.difference(file.lastModifiedSync());
      if (age > retention) {
        file.deleteSync();
      }
    }
    final remaining = files.where((f) => f.path != current).toList();
    final excess = remaining.length + 1 - maxFiles;
    for (var i = 0; i < excess && i < remaining.length; i++) {
      remaining[i].deleteSync();
    }
  }

  /// Reads the last chain hash and position from the newest existing file.
  ///
  /// A restart that began a fresh chain would present every pre-restart entry
  /// as unverifiable, which is indistinguishable from tampering — so the head
  /// is recovered rather than reset. The count is recovered from the same entry
  /// for the same reason: restarting the numbering would make every anchor
  /// taken before the restart point at the wrong entry.
  ({String hash, int entryCount}) _recoverHead() {
    final all = files;
    for (final file in all.reversed) {
      final lines = file.readAsLinesSync().where((l) => l.trim().isNotEmpty);
      if (lines.isEmpty) continue;
      try {
        final last = TomAuditEntry.fromJson(
          (jsonDecode(lines.last) as Map).cast<String, Object?>(),
        );
        return (hash: last.hash, entryCount: last.index + 1);
      } catch (_) {
        // A truncated final line (a crash mid-write) is the one damage the
        // chain cannot repair by itself. Continue to the previous file rather
        // than refusing to start: the break stays visible to verification.
        continue;
      }
    }
    return (hash: tomAuditGenesisHash, entryCount: 0);
  }

  String _today() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// Closes the sink, refusing whatever is still queued.
  ///
  /// Every [write] that has *returned* has already flushed, so nothing
  /// completed is at risk. What this cannot save is a record still sitting in
  /// `_queue`: [TomClosable] requires this method to return synchronously and
  /// no synchronous method can wait for a queue. Those records are refused
  /// with `audit.sink.closed` — see [TomAuditSink.close] for why refusing
  /// beats the two alternatives. [flushAndClose] is the route that stores them.
  ///
  /// The handle's own close is allowed to finish in the background. That is
  /// safe *because* of the refusal: with no queued write able to reach
  /// `_ensureOpen` any more, nothing can reopen the file while the close is in
  /// flight.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    final sink = _sink;
    _sink = null;
    if (sink != null) unawaited(sink.close());
  }

  /// Waits for the queued records to be written, then closes.
  ///
  /// The drain awaits `_queue` rather than the individual write futures
  /// because `_queue` is the tail of the chain: awaiting it means every record
  /// enqueued before this call has run. It swallows nothing — `_queue` already
  /// absorbs write errors so one failure cannot wedge the sink, and each
  /// error was delivered to its own caller through the future `write`
  /// returned.
  @override
  Future<void> flushAndClose() async {
    if (_closed) return;
    // Close to new records *first*, then wait. Taking them in this order is
    // what gives the drain a fixed point to reach: a caller writing in a loop
    // would otherwise keep extending the queue for as long as we waited on it.
    // `_draining` is what keeps the already-queued records from being refused
    // by the very flag that stops the new ones.
    _closed = true;
    _draining = true;
    try {
      await _queue;
    } finally {
      _draining = false;
    }
    final sink = _sink;
    _sink = null;
    if (sink != null) {
      await sink.flush();
      await sink.close();
    }
  }
}
