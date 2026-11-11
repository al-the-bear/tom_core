/// Deleting stored files no row refers to.
///
/// A file is uploaded and then attached: the upload writes the blob, a later
/// save writes the row naming it. An upload whose row never comes — the form
/// abandoned, the request failed after the upload — leaves a blob nothing can
/// serve and nothing will delete. A plain blob store cannot find those, because
/// it cannot list itself; a [TomDeduplicatingBlobStore] can, because its ledger
/// records every key. [TomBlobOrphanSweep] walks that ledger and asks the rows.
///
/// ## The grace period
///
/// Only keys written more than [TomBlobOrphanSweep.grace] ago are considered,
/// so an upload has that long to be attached. A row saved *after* the sweep
/// asked whether its key is referenced, naming a key older than the grace, can
/// lose its file; the sweep asks a second time immediately before it deletes,
/// which narrows that window to the delete itself. Choose a grace far longer
/// than any upload-to-save delay a deployment allows.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../file_storage/blob_ledger.dart';
import '../file_storage/blob_store.dart';
import '../file_storage/deduplicating_blob_store.dart';
import 'annotation_analyzer.dart';
import 'crud_repository.dart';
import 'entity_lifecycle.dart';
import 'persistence_annotations.dart';
import '../tenancy/tenancy.dart';

/// Something that knows which blob keys its rows refer to.
abstract class TomBlobReferenceSource {
  /// Creates a reference source.
  const TomBlobReferenceSource();

  /// Which of [keys] a row refers to.
  Future<Set<String>> referenced(List<String> keys);
}

/// The `@TomFileReference` columns of [repository]'s entity, as a
/// [TomBlobReferenceSource].
///
/// Soft-deleted rows count: a restore brings their files back into use. The
/// keys are asked in batches of [batchSize], one query per file column and
/// batch — except for a column graded with an `authKey`, whose values a read
/// outside a request may mask, which is counted key by key instead.
class TomRepositoryBlobReferences<T extends Object, K>
    extends TomBlobReferenceSource {
  /// The file columns of `T` — all of them, or those named in [fields] — read
  /// through [repository].
  ///
  /// Throws a [TomStorageException] keyed `storage.sweep.no_file_columns` when
  /// `T` stores no files, and `storage.sweep.unknown_field` when [fields] names
  /// a field that is not one of its file columns.
  TomRepositoryBlobReferences(
    this.repository, {
    Set<String> fields = const {},
    this.batchSize = 100,
  }) : _columns = _columnsOf<T>(fields) {
    if (batchSize < 1) {
      // throws-outside-family: programmer error — a batch of nothing asks
      // nothing.
      throw ArgumentError.value(batchSize, 'batchSize', 'must be at least 1');
    }
  }

  /// The repository the rows are read through.
  final TomRepository<T, K> repository;

  /// How many keys one query asks about.
  final int batchSize;

  final List<TomColumnInformation> _columns;

  /// Which of [keys] a row refers to — under an installed tenancy, for a
  /// tenant table asked outside any tenant (the sweep's own job), a row of
  /// any served tenant, suspended ones included, and of every removed tenant
  /// whose data is kept until it is purged (`TomTenancy.removedTenantIds`,
  /// read through `TomTenancy.readRemovedTenant`): a key one tenant's row
  /// names is in use, and a removed tenant's rows come back with
  /// `restoreTenant`. A removed tenant whose data cannot be opened fails the
  /// question rather than answering "not referenced". In a tenant's context,
  /// that tenant's rows.
  @override
  Future<Set<String>> referenced(List<String> keys) async {
    final tenancy = TomTenancy.current;
    if (tenancy == null ||
        TomTenantContext.currentId != null ||
        !TomAnnotationAnalyzer.isTenantTable(T)) {
      return _referencedHere(keys);
    }
    final found = <String>{};
    for (final tenant in List.of(tenancy.tenants.keys)) {
      found.addAll(
        await TomTenantContext.run(tenant, () => _referencedHere(keys)),
      );
    }
    for (final tenant in await tenancy.removedTenantIds()) {
      found.addAll(
        await tenancy.readRemovedTenant(tenant, () => _referencedHere(keys)),
      );
    }
    return found;
  }

  Future<Set<String>> _referencedHere(List<String> keys) =>
      TomSoftDelete.includingDeleted(() async {
        final found = <String>{};
        for (var start = 0; start < keys.length; start += batchSize) {
          final batch = keys.sublist(
            start,
            start + batchSize > keys.length ? keys.length : start + batchSize,
          );
          final params = {
            for (var i = 0; i < batch.length; i++) 'k$i': batch[i],
          };
          final list = [for (var i = 0; i < batch.length; i++) ':k$i'];
          for (final column in _columns) {
            final field = column.getQueryFieldName();
            if (column.authKey != null) {
              // A graded column (C-4) can come back masked to null from a read
              // made outside a request, and a key the sweep cannot see is one
              // it deletes. A count is never masked, so such a column is asked
              // key by key.
              for (final key in batch) {
                final count = await repository.countByQuerySentence(
                  'COUNT BY $field = :key',
                  {'key': key},
                );
                if ((count.get() ?? 0) > 0) found.add(key);
              }
              continue;
            }
            final rows = await repository.findByQuerySentence(
              'FIND BY $field IS IN '
              '( ${list.join(' , ')} )',
              params,
            );
            for (final row in rows) {
              final key = column.getVariableValue(row);
              if (key is String) found.add(key);
            }
          }
        }
        return found;
      });

  static List<TomColumnInformation> _columnsOf<T>(Set<String> fields) {
    final all = TomAnnotationAnalyzer.findFileColumns(T);
    if (all.isEmpty) {
      throw TomStorageException(
        'storage.sweep.no_file_columns',
        'That entity stores no files.',
        parameters: {'entity': '$T'},
      );
    }
    if (fields.isEmpty) return all;
    final selected = [
      for (final column in all)
        if (fields.contains(column.declaredName) ||
            fields.contains(column.getQueryFieldName()))
          column,
    ];
    final found = {
      for (final column in selected) ...[
        column.declaredName,
        column.getQueryFieldName(),
      ],
    };
    final unknown = fields.where((field) => !found.contains(field));
    if (unknown.isNotEmpty) {
      throw TomStorageException(
        'storage.sweep.unknown_field',
        'That entity has no such file column.',
        parameters: {'entity': '$T', 'fields': unknown.join(', ')},
      );
    }
    return selected;
  }
}

/// What one [TomBlobOrphanSweep.sweep] did.
class TomBlobOrphanSweepReport {
  /// A report of [scanned] keys considered, [deleted] keys removed and
  /// [reclaimed] contents freed.
  const TomBlobOrphanSweepReport({
    required this.scanned,
    required this.deleted,
    required this.reclaimed,
  });

  /// How many keys were old enough to be considered.
  final int scanned;

  /// The keys no row referred to, which were deleted.
  final List<String> deleted;

  /// How many contents the reclaim after the sweep freed.
  final int reclaimed;

  @override
  String toString() =>
      'TomBlobOrphanSweepReport($scanned scanned, ${deleted.length} deleted, '
      '$reclaimed reclaimed)';
}

/// Deletes the keys of [store] that no row of [sources] refers to, once they
/// are older than [grace], and then reclaims the content they held.
class TomBlobOrphanSweep {
  /// A sweep of [store] against [sources], considering only keys under one of
  /// [prefixes] when any are given — the `keyPrefix`es of the file columns the
  /// sources read, when the store also holds files nothing here describes.
  ///
  /// [allowScopedRun] lets the sweep run inside a request; by default it is
  /// refused there (`storage.sweep.scoped_run`), because a request's data
  /// scope hides rows, and a row the sweep cannot see is a reference it
  /// deletes. [clock] is the time a sweep run without `now` measures the grace
  /// from.
  TomBlobOrphanSweep({
    required this.store,
    required List<TomBlobReferenceSource> sources,
    this.grace = const Duration(days: 1),
    List<String> prefixes = const [],
    this.batchSize = 500,
    this.reclaim = true,
    this.allowScopedRun = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       sources = List.unmodifiable(sources),
       prefixes = List.unmodifiable([
         for (final prefix in prefixes) TomBlobStore.validateKey(prefix),
       ]) {
    if (sources.isEmpty) {
      // throws-outside-family: programmer error — with nothing to ask, every
      // key is unreferenced and the sweep would empty the store.
      throw ArgumentError.value(sources, 'sources', 'must not be empty');
    }
    if (grace <= Duration.zero || batchSize < 1) {
      // throws-outside-family: programmer error — a sweep that takes uploads
      // before they can be attached, or never makes progress.
      throw ArgumentError(
        'grace must be positive and batchSize at least 1; got $grace and '
        '$batchSize.',
      );
    }
  }

  /// The store swept.
  final TomDeduplicatingBlobStore store;

  /// Everything that may refer to a key.
  final List<TomBlobReferenceSource> sources;

  /// How old a key must be to be considered.
  final Duration grace;

  /// The key prefixes considered; empty for every key.
  final List<String> prefixes;

  /// How many keys one page of the ledger holds.
  final int batchSize;

  /// Whether to run [TomDeduplicatingBlobStore.reclaim] after the sweep.
  final bool reclaim;

  /// Whether the sweep may run inside a request.
  final bool allowScopedRun;

  final DateTime Function() _clock;

  /// Deletes every key written before [now] (default: the sweep's clock) minus
  /// [grace] that no source refers to.
  Future<TomBlobOrphanSweepReport> sweep({DateTime? now}) async {
    if (!allowScopedRun && getFromCurrentZone<TomPrincipal>() != null) {
      throw TomStorageException(
        'storage.sweep.scoped_run',
        'An orphan sweep cannot run inside a request.',
        autoLog: true,
      );
    }
    final at = (now ?? _clock()).toUtc();
    final cutoff = at.subtract(grace);
    var scanned = 0;
    final deleted = <String>[];
    var after = '';
    while (true) {
      final page = await store.ledger.storedBefore(
        cutoff,
        after: after,
        limit: batchSize,
      );
      if (page.isEmpty) break;
      after = page.last.key;
      final candidates = [
        for (final entry in page)
          if (_considered(entry.key)) entry.key,
      ];
      scanned += candidates.length;
      var orphans = await _unreferenced(candidates);
      // Asked again immediately before deleting, so a row saved while the
      // page was being checked keeps its file.
      if (orphans.isNotEmpty) orphans = await _unreferenced(orphans);
      for (final key in orphans) {
        if (await store.delete(key)) deleted.add(key);
      }
      if (page.length < batchSize) break;
    }
    final reclaimed = reclaim ? await store.reclaim(now: at) : 0;
    return TomBlobOrphanSweepReport(
      scanned: scanned,
      deleted: deleted,
      reclaimed: reclaimed,
    );
  }

  /// A job running [sweep] on [schedule] (default: daily), for a
  /// [TomScheduler] to run in its own isolate ([TomInlineJobDispatcher]),
  /// since its body holds this sweep.
  TomJobDefinition jobDefinition({
    String name = 'tom.storage.orphan_sweep',
    TomSchedule? schedule,
  }) => TomJobDefinition(
    name: name,
    schedule: schedule ?? TomIntervalSchedule(const Duration(days: 1)),
    body: (_) => _TomBlobOrphanSweepCommand(this),
    missedWindowPolicy: TomMissedWindowPolicy.runOnce,
  );

  bool _considered(String key) =>
      prefixes.isEmpty || prefixes.any((p) => tomBlobKeyUnder(key, p));

  Future<List<String>> _unreferenced(List<String> keys) async {
    if (keys.isEmpty) return const [];
    final referenced = <String>{};
    for (final source in sources) {
      referenced.addAll(await source.referenced(keys));
    }
    return [
      for (final key in keys)
        if (!referenced.contains(key)) key,
    ];
  }
}

/// One run of [TomBlobOrphanSweep.sweep].
class _TomBlobOrphanSweepCommand extends TomCommand {
  _TomBlobOrphanSweepCommand(this._sweep);

  final TomBlobOrphanSweep _sweep;

  @override
  Future<Object?> execute() async => (await _sweep.sweep()).toString();
}
