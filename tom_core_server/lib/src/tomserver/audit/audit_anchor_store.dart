/// Where published audit anchors are kept, and the scheduler that publishes
/// them.
///
/// ## The store is the part the framework cannot supply
///
/// An anchor is only worth as much as the store's independence from the server
/// it attests to. A store the audited process can rewrite is not an anchor
/// store; it is a second copy of the same claim, and an attacker who rewrote
/// the trail rewrites it too. So the interesting implementations of
/// [TomAuditAnchorStore] are the ones this package cannot ship — an object
/// store with versioning and a deny-delete policy, a WORM volume, a
/// countersigning service, another organisation's inbox.
///
/// What ships here is the seam ([TomAuditAnchorStore]) plus two implementations
/// that are honest about what they are: [TomMemoryAuditAnchorStore] for tests,
/// and [TomFileAuditAnchorStore] for a directory that the deployment has
/// arranged to be outside the server's reach — a read-only-to-the-app mount, a
/// share the process may append to and nothing more. A file store in the
/// application's own writable tree provides no anchoring guarantee whatever,
/// and saying so plainly is more useful than a config flag that pretends
/// otherwise.
///
/// Note what is *not* here: a SQL anchor store. Anchoring the trail into the
/// same database that holds it would be ceremony without a guarantee — one
/// credential, one blast radius. `doc/audit.md` says the same thing at length.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:tom_core_kernel/tom_core_kernel.dart';

import 'audit_anchor.dart';
import 'audit_sink.dart';

/// An append-only archive of published anchors.
///
/// Reading is offered because verification needs it, but a store is free to
/// make reads expensive or to serve them from a different credential than the
/// one that appends: the append path is what runs on the audited server, and it
/// wants the narrowest possible permission.
abstract class TomAuditAnchorStore implements TomClosable {
  /// Appends [anchor]. Must throw rather than silently drop.
  ///
  /// Fail-loud for the same reason [TomAuditSink.write] is: a publisher that
  /// cannot tell a successful publication from a swallowed error would let a
  /// chain run unanchored while reporting that it was anchored.
  Future<void> append(TomAuditAnchor anchor);

  /// Every stored anchor for [writer], oldest first.
  ///
  /// Only that writer's. An implementation that groups anchors by some
  /// derivation of the name — a file per writer, a partition key — must still
  /// filter on the writer recorded in each anchor, because such derivations
  /// are rarely injective and the caller cannot see where the grouping put
  /// things. Anchors from another chain are worse than no anchor at all: they
  /// make [latest] answer the routine check with a position that belongs to a
  /// different trail.
  Future<List<TomAuditAnchor>> read(String writer);

  /// The most recently published anchor for [writer], or `null`.
  ///
  /// The one a routine check uses: it pins the furthest position that can be
  /// verified, and every older anchor is implied by it as long as the chain
  /// between them verifies.
  Future<TomAuditAnchor?> latest(String writer) async {
    final all = await read(writer);
    return all.isEmpty ? null : all.last;
  }

  @override
  void close() {}
}

/// An in-memory anchor store, for tests.
///
/// Explicitly not an anchor: it lives in the process it is anchoring, so it
/// dies with exactly the attacker who would need to rewrite it.
class TomMemoryAuditAnchorStore extends TomAuditAnchorStore {
  final List<TomAuditAnchor> _anchors = [];

  /// Every anchor appended, in order, across all writers.
  List<TomAuditAnchor> get anchors => List.unmodifiable(_anchors);

  @override
  Future<void> append(TomAuditAnchor anchor) async => _anchors.add(anchor);

  @override
  Future<List<TomAuditAnchor>> read(String writer) async =>
      _anchors.where((a) => a.writer == writer).toList(growable: false);

  /// Discards every stored anchor. Test-support only.
  void clear() => _anchors.clear();
}

/// A JSON-Lines anchor store, one file per writer, append-only.
///
/// The format is the same as the file audit sink's and for the same reason:
/// appending a line is the one file operation that cannot damage what came
/// before it. Files are never rotated — anchors are small and their whole value
/// is that the old ones survive.
class TomFileAuditAnchorStore extends TomAuditAnchorStore {
  /// The directory the anchor files live in.
  ///
  /// Must not be somewhere the audited application can rewrite. Append-only is
  /// the requirement; the framework cannot enforce it and does not pretend to.
  final Directory directory;

  /// The file name prefix, so several deployments can share a directory.
  final String filePrefix;

  /// Creates a store in [directory], creating the directory if needed.
  TomFileAuditAnchorStore({
    required this.directory,
    this.filePrefix = 'anchor',
  }) {
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
  }

  /// The file holding [writer]'s anchors.
  ///
  /// The writer name is sanitised into the file name rather than trusted:
  /// it reaches this far from configuration, and a writer called `../../etc`
  /// must produce a strange file name, not a write outside [directory].
  ///
  /// The mapping is deliberately **not injective** — `node/a` and `node_a`
  /// name the same file — and [read] is written knowing it. Making it
  /// injective would mean encoding the original name into the file name
  /// (escaping, or a hash suffix), which buys a tidier directory listing at
  /// the cost of file names an operator can no longer match to a node by
  /// eye. The store already records the writer inside every line, so the
  /// file name does not have to carry that weight.
  File fileFor(String writer) {
    final safe = writer.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File(p.join(directory.path, '$filePrefix-$safe.jsonl'));
  }

  @override
  Future<void> append(TomAuditAnchor anchor) async {
    await fileFor(anchor.writer).writeAsString(
      '${anchor.toJsonLine()}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  /// Every stored anchor for [writer], oldest first.
  ///
  /// Filtered by the writer recorded *in each anchor*, not by the file it was
  /// found in, because [fileFor] is lossy: two writer names can share one file
  /// and the file therefore holds two chains. Returning both would mean
  /// [latest] hands the routine check an anchor describing a different trail —
  /// which reads as tampering on a healthy chain when the foreign position is
  /// ahead, and, when it is behind the retained window, as `beforeRetention`:
  /// no finding at all, so a genuine rewrite passes the check unexamined.
  ///
  /// The filter is applied *after* parsing, and that ordering is load-bearing.
  /// Matching the writer in the raw text first would be faster and would skip
  /// the malformed lines that do not look like ours — but a line too damaged
  /// to parse is a line too damaged to attribute, and the archive's whole
  /// claim is that its contents cannot be edited. Every line is parsed so that
  /// every line is checked.
  @override
  Future<List<TomAuditAnchor>> read(String writer) async {
    final file = fileFor(writer);
    if (!file.existsSync()) return const [];
    final anchors = <TomAuditAnchor>[];
    var lineNumber = 0;
    for (final line in await file.readAsLines()) {
      lineNumber++;
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final TomAuditAnchor anchor;
      try {
        anchor = TomAuditAnchor.fromJson(
          (jsonDecode(trimmed) as Map).cast<String, Object?>(),
        );
      } on Object catch (e) {
        // A damaged anchor line is itself a finding — the archive is supposed
        // to be the thing that cannot be edited — so it is reported, not
        // skipped.
        throw TomAuditException(
          'audit.anchor.malformed_line',
          'Anchor file ${file.path} line $lineNumber is not a valid anchor.',
          parameters: {'line': lineNumber, 'file': file.path},
          rootException: e,
        );
      }
      if (anchor.writer == writer) anchors.add(anchor);
    }
    return anchors;
  }
}

/// Publishes anchors for a sink's chain on a schedule.
///
/// ## Why this is not a `TomScheduler` job
///
/// The scheduler exists to run a job *once across the cluster*, which is
/// exactly wrong here. Each node keeps its own chain — the chain is per
/// [writer] precisely so that several nodes may append to one table — so each
/// node must anchor its own head. A cluster-single-fire publisher would anchor
/// one node and leave the rest unanchored, which is worse than not anchoring at
/// all because the dashboard would say it was covered.
///
/// ## Why every tick publishes, even when nothing was written
///
/// An anchor over an unchanged head is not redundant: it says *the head was
/// still this at time T*, which narrows when a later divergence must have
/// happened. Anchors are a couple of hundred bytes; an hourly publisher costs
/// about two megabytes a year, and the alternative — suppressing duplicates —
/// buys that back by discarding the evidence that bounds the attack window.
class TomAuditAnchorPublisher implements TomClosable {
  /// The sink whose chain is anchored.
  final TomAuditSink sink;

  /// Where anchors are published.
  final TomAuditAnchorStore store;

  /// The chain's name, matching the sink's own writer identity.
  final String writer;

  /// Signs each anchor before publication, when the deployment has a key.
  final TomAuditAnchorSigner? signer;

  /// How often an anchor is published once [start] has been called.
  final Duration interval;

  Timer? _timer;
  bool _closed = false;
  TomAuditAnchor? _lastPublished;

  /// Creates a publisher. Nothing is published until [start] or [publishNow].
  TomAuditAnchorPublisher({
    required this.sink,
    required this.store,
    required this.writer,
    this.signer,
    this.interval = const Duration(hours: 1),
  });

  /// The most recent anchor this publisher wrote, or `null`.
  TomAuditAnchor? get lastPublished => _lastPublished;

  /// Begins publishing every [interval], starting with one immediately.
  ///
  /// The immediate publication matters: a process that starts, is compromised
  /// and is killed inside one interval would otherwise never anchor at all, and
  /// the gap would be exactly the interesting one.
  Future<void> start() async {
    if (_closed) {
      throw TomAuditException(
        'audit.anchor.publisher_closed',
        'Audit anchor publisher for $writer is closed.',
      );
    }
    _timer?.cancel();
    await publishNow();
    _timer = Timer.periodic(interval, (_) => unawaited(_tick()));
  }

  /// Stops the schedule. [publishNow] still works.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Captures the sink's position and publishes it, returning the anchor.
  ///
  /// Throws when the store refuses — a caller that asked for a publication is
  /// entitled to learn that it did not happen. The scheduled path swallows and
  /// logs instead; see [_tick].
  Future<TomAuditAnchor> publishNow() async {
    final anchor = TomAuditAnchor.of(sink, writer: writer);
    final published = signer == null ? anchor : anchor.signedWith(signer!);
    await store.append(published);
    _lastPublished = published;
    return published;
  }

  /// The scheduled publication: never throws into the timer.
  ///
  /// A store outage must not take the server down, but it must not be silent
  /// either — an unanchored chain that nobody was told about is the worst of
  /// both worlds, so the failure is logged at error level every time it
  /// happens.
  Future<void> _tick() async {
    try {
      await publishNow();
    } on Object catch (e, s) {
      tomLog.error(
        'audit anchor publication failed for chain "$writer": $e\n$s',
      );
    }
  }

  /// Stops the schedule after publishing a final anchor.
  ///
  /// The last anchor of a graceful shutdown is the one that pins the chain's
  /// final head, so skipping it would leave every entry written since the last
  /// tick unanchored. A failure here is logged rather than thrown: close must
  /// not be the call that fails a shutdown.
  @override
  void close() {
    if (_closed) return;
    _closed = true;
    stop();
    unawaited(_tick());
  }
}
