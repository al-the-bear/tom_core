/// The offline journal for **document commits**.
///
/// A save made while the transport is down still has to be a save: the
/// document behaves as stored, and the work must survive a process restart.
/// The journal is what makes that true — it records the *pending commit*:
/// **the changeset plus the base head it was built against**. Those two values are enough to re-attempt the write later
/// through the ordinary compare-and-swap path, with no reference to whatever
/// was in memory when it was queued.
///
/// It is deliberately **not** an operation log. An operation log is right for
/// data whose mutations must replay *through* a concurrent remote edit;
/// document edits need no such thing: they coalesce into the working copy, so
/// the next ordinary sync cycle carries every queued edit at once.
/// Here the queue is a **durability and reporting** record — what makes
/// "offline — N pending changes" answerable, and what
/// lets a restarted process re-attempt a write it never delivered.
///
/// A pending commit is dropped **only after its content has reached the
/// remote** — either by its own replay or by the coalesced push that
/// supersedes it. Dropping on attempt loses the edit the moment the network
/// flaps mid-replay.
library;

import 'package:tom_basics/utilities.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:yaml/yaml.dart' as yaml;

import 'location_prefix.dart';
import 'storage.dart';
import 'bundle_medium.dart';

/// One commit that was built but never delivered.
class TomPendingCommit {
  /// Increases with every append **for as long as the queue is non-empty**;
  /// the replay order, and the handle [TomCommitJournal.complete] takes.
  ///
  /// Global across locators rather than per-locator, so a journal serving a
  /// whole workspace has one unambiguous ordering and `complete` can take a
  /// bare number.
  ///
  /// It is explicitly **not** monotonic across all time: a journal that drains
  /// to empty restarts at 1. That is not an oversight in one implementation, it
  /// is the contract both of them keep — a durable journal represents an empty
  /// queue by having no file at all (there is nothing to persist), so the
  /// alternative would be keeping a counter file forever to preserve an
  /// ordering that, by definition, has nothing left to order. Sequences are
  /// meaningful among the entries a journal is holding, and are never a durable
  /// identity for a commit.
  final int sequence;

  /// Which container this commit was for.
  final String locator;

  final TomChangeset changeset;

  /// The head [changeset] was built against — the `expectedHead` a replay
  /// passes to `commit`. Null means "the container did not exist yet", which
  /// is how an offline *create* is journaled.
  final String? baseHead;

  /// The save counter [changeset] writes. Carried for diagnostics and for the
  /// shell's pending-changes listing; the replay does not need it.
  final int version;

  final String? message;

  /// When the commit was queued locally — the answer to "how old is this
  /// pending change?" without inferring it from the remote's timestamps.
  final DateTime queuedAt;

  const TomPendingCommit({
    required this.sequence,
    required this.locator,
    required this.changeset,
    required this.baseHead,
    required this.version,
    required this.queuedAt,
    this.message,
  });

  Map<String, Object?> toMap() => {
    'sequence': sequence,
    'locator': locator,
    'baseHead': baseHead,
    'version': version,
    if (message != null) 'message': message,
    'queuedAt': queuedAt.toUtc().toIso8601String(),
    'writes': {
      for (final entry in changeset.writes.entries)
        entry.key: base64.encode(entry.value),
    },
    'deletes': changeset.deletes.toList()..sort(),
  };

  static TomPendingCommit fromMap(Map<dynamic, dynamic> map) =>
      TomPendingCommit(
        sequence: map['sequence'] as int,
        locator: map['locator'] as String,
        baseHead: map['baseHead'] as String?,
        version: map['version'] as int,
        message: map['message'] as String?,
        queuedAt: DateTime.parse(map['queuedAt'] as String).toUtc(),
        changeset: TomChangeset(
          writes: {
            for (final entry in (map['writes'] as Map).entries)
              entry.key.toString(): Uint8List.fromList(
                base64.decode(entry.value as String),
              ),
          },
          deletes: {
            for (final path in (map['deletes'] as List? ?? const []))
              path.toString(),
          },
        ),
      );

  @override
  String toString() =>
      'TomPendingCommit(#$sequence $locator '
      'v$version on ${baseHead ?? '<new>'}, $changeset)';
}

/// A durable, ordered queue of commits awaiting a reachable remote.
abstract interface class TomCommitJournal {
  /// Queues one undelivered commit, returning it with the assigned sequence.
  Future<TomPendingCommit> append({
    required String locator,
    required TomChangeset changeset,
    required String? baseHead,
    required int version,
    String? message,
  });

  /// Everything still awaiting delivery, oldest first.
  ///
  /// [locator] narrows to one container — what a per-document sync engine
  /// wants; omitting it gives the workspace-wide queue the shell aggregates.
  Future<List<TomPendingCommit>> pending({String? locator});

  /// Drops the entry with [sequence]. Called only once its content is on the
  /// remote.
  Future<void> complete(int sequence);

  /// Drops every entry for [locator].
  ///
  /// The one legitimate caller is a successful push of the current working
  /// copy: because document edits coalesce, that push contains
  /// everything every queued entry for this container was carrying, so the
  /// queue is not discarded — it is *subsumed*.
  Future<void> completeAll(String locator);

  /// Drops everything, for an operator abandoning a queue they have decided
  /// not to replay. Never part of a normal cycle.
  Future<void> clear();

  /// Drops every entry for a container inside the storage location
  /// [location], returning what was dropped.
  ///
  /// the "Forget this repo/location", and nothing else: the entries are
  /// **unpushed work**, so the caller surfaces them for confirmation first
  /// (they are [pending] filtered by the same rule). The rule is
  /// `tomLocationCovers` — a path boundary, so forgetting `…/team` keeps
  /// `…/teammates`.
  Future<List<TomPendingCommit>> scrubLocation(String location);
}

/// Journal held in memory. For tests, and for a session that has explicitly
/// chosen not to persist a queue across restarts.
///
/// Behaviourally indistinguishable from [TomMediumCommitJournal] apart from
/// the one property that separates them — surviving a restart. That is on
/// purpose: the sync suite runs the same scenarios over both, and two
/// implementations that differed in some *other* observable way would let a
/// scenario pass on one and mean nothing on the other.
@visibleForTesting
final class TomMemoryCommitJournal implements TomCommitJournal {
  final List<TomPendingCommit> _entries = [];
  int _next = 1;

  final DateTime Function() clock;

  TomMemoryCommitJournal({DateTime Function()? clock})
    : clock = clock ?? (() => DateTime.now().toUtc());

  @override
  Future<TomPendingCommit> append({
    required String locator,
    required TomChangeset changeset,
    required String? baseHead,
    required int version,
    String? message,
  }) async {
    final entry = TomPendingCommit(
      sequence: _next++,
      locator: locator,
      changeset: changeset,
      baseHead: baseHead,
      version: version,
      message: message,
      queuedAt: clock(),
    );
    _entries.add(entry);
    return entry;
  }

  @override
  Future<List<TomPendingCommit>> pending({String? locator}) async => [
    for (final entry in _entries)
      if (locator == null || entry.locator == locator) entry,
  ];

  @override
  Future<void> complete(int sequence) async {
    _entries.removeWhere((e) => e.sequence == sequence);
    _resetIfDrained();
  }

  @override
  Future<void> completeAll(String locator) async {
    _entries.removeWhere((e) => e.locator == locator);
    _resetIfDrained();
  }

  @override
  Future<void> clear() async {
    _entries.clear();
    _resetIfDrained();
  }

  @override
  Future<List<TomPendingCommit>> scrubLocation(String location) async {
    final dropped = [
      for (final entry in _entries)
        if (tomLocationCovers(location, entry.locator)) entry,
    ];
    _entries.removeWhere(dropped.contains);
    _resetIfDrained();
    return dropped;
  }

  /// Mirrors the durable journal's "an empty queue is an absent file": with
  /// nothing left to order, the numbering starts over. See
  /// [TomPendingCommit.sequence].
  void _resetIfDrained() {
    if (_entries.isEmpty) _next = 1;
  }
}

/// Journal persisted as one YAML file in a [TomBundleMedium].
///
/// Over the medium rather than `dart:io` for the same reason every other
/// persisted queue in this package is: the journal has to work over a real
/// folder, an in-memory one, and a browser-backed one, and none of that is the
/// journal's business.
final class TomMediumCommitJournal implements TomCommitJournal {
  /// Under the cache's `journal/` area, dot-prefixed so no bundle
  /// load can mistake a queue for a document part.
  static const path = '.tom/commit-journal.yaml';

  static const formatVersion = '1';

  final TomBundleMedium medium;
  final DateTime Function() clock;

  TomMediumCommitJournal({required this.medium, DateTime Function()? clock})
    : clock = clock ?? (() => DateTime.now().toUtc());

  @override
  Future<TomPendingCommit> append({
    required String locator,
    required TomChangeset changeset,
    required String? baseHead,
    required int version,
    String? message,
  }) async {
    // Re-read rather than cache: a second engine on the same journal may have
    // queued since, and two writers overwriting each other's queue is exactly
    // the loss the queue exists to prevent.
    final entries = await _read();
    final sequence = entries.isEmpty
        ? 1
        : entries.map((e) => e.sequence).reduce((a, b) => a > b ? a : b) + 1;
    final entry = TomPendingCommit(
      sequence: sequence,
      locator: locator,
      changeset: changeset,
      baseHead: baseHead,
      version: version,
      message: message,
      queuedAt: clock(),
    );
    await _write([...entries, entry]);
    return entry;
  }

  @override
  Future<List<TomPendingCommit>> pending({String? locator}) async => [
    for (final entry in await _read())
      if (locator == null || entry.locator == locator) entry,
  ];

  @override
  Future<void> complete(int sequence) async {
    await _write((await _read())..removeWhere((e) => e.sequence == sequence));
  }

  @override
  Future<void> completeAll(String locator) async {
    await _write((await _read())..removeWhere((e) => e.locator == locator));
  }

  @override
  Future<void> clear() async => _write(const []);

  @override
  Future<List<TomPendingCommit>> scrubLocation(String location) async {
    final entries = await _read();
    final dropped = [
      for (final entry in entries)
        if (tomLocationCovers(location, entry.locator)) entry,
    ];
    if (dropped.isEmpty) return dropped;
    await _write([
      for (final entry in entries)
        if (!tomLocationCovers(location, entry.locator)) entry,
    ]);
    return dropped;
  }

  Future<List<TomPendingCommit>> _read() async {
    if (!await medium.exists(path)) return [];
    final root = yaml.loadYaml(await medium.readString(path));
    if (root is! Map) return [];
    final journal = root['journal'];
    if (journal is! Map) return [];
    final entries = journal['entries'];
    if (entries is! List) return [];
    return [for (final raw in entries) TomPendingCommit.fromMap(raw as Map)]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  Future<void> _write(List<TomPendingCommit> entries) async {
    if (entries.isEmpty) {
      // An empty queue is an absent file, so a drained journal leaves no
      // artifact behind for a reader to wonder about.
      await medium.delete(path);
      return;
    }
    final sorted = List.of(entries)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    await medium.writeString(
      path,
      tomEmitYamlDocument({
        'journal': {
          'version': formatVersion,
          'entries': [for (final entry in sorted) entry.toMap()],
        },
      }),
    );
  }
}
