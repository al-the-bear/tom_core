/// Moving a deployment's stored files from one blob store to another.
///
/// The hard part is not the copying, it is knowing *what* to copy. A blob store
/// cannot enumerate itself — deliberately, because a listing is a cheap
/// `readdir` on a filesystem and a paginated, eventually-consistent call on an
/// object store, and one contract cannot honestly offer both. So the key list
/// comes from the other side: the rows. A `@TomFileReference` column *is* the
/// index of what a deployment stored, and it is the index that matters, because
/// a blob no row points at is one nothing can serve.
///
/// That is also the limit, stated plainly: this moves what the rows claim, and
/// provably not what they do not. See [TomBlobMigration] for what a deployment
/// must do about the remainder.
library;

import 'dart:async';

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../file_storage/blob_store.dart';
import '../little_things/server_exception.dart';
import 'annotation_analyzer.dart';
import 'crud_repository.dart';
import 'paging.dart';
import 'persistence_annotations.dart';

/// Thrown when a blob migration cannot proceed, or cannot be trusted.
class TomBlobMigrationException extends TomServerException {
  /// Creates a migration exception with a stable [key].
  TomBlobMigrationException(
    super.key,
    super.defaultUserMessage, {
    super.parameters,
    super.stack,
    super.rootException,
    super.autoLog,
  });
}

/// What one blob migration did.
///
/// Counts rather than a boolean, because "it worked" is not the question an
/// operator has afterwards. The question is whether the number of blobs now in
/// the target matches what the rows claim, and which rows it could not satisfy.
class TomBlobMigrationReport {
  /// Creates a report.
  TomBlobMigrationReport({
    required this.rows,
    required this.copied,
    required this.alreadyPresent,
    required this.bytes,
    required this.claimed,
    required this.absent,
  });

  /// How many rows the sweep read.
  final int rows;

  /// How many blobs it copied into the target.
  final int copied;

  /// How many it found already there, verified and left alone.
  ///
  /// A re-run of a completed migration reports every blob here and copies
  /// nothing, which is what makes an interrupted migration resumable by simply
  /// running it again.
  final int alreadyPresent;

  /// How many bytes were copied — the transfer, not the total stored.
  final int bytes;

  /// Every key the target now holds because a row named it.
  ///
  /// The set a deployment diffs its old store against to find what the rows do
  /// not claim. That diff cannot happen here: it needs an enumeration of the
  /// source, which is exactly what the blob contract does not offer.
  final List<String> claimed;

  /// The keys a row names that the source does not hold.
  ///
  /// Reported rather than thrown, because one dangling reference must not stop
  /// a migration of ten thousand rows — and because it is a fault in the data
  /// that predates the migration and outlives it, which an operator wants the
  /// whole list of rather than the first one.
  final List<String> absent;

  /// Whether every key a row named ended up in the target.
  bool get complete => absent.isEmpty;

  @override
  String toString() =>
      'TomBlobMigrationReport($rows rows, $copied copied, '
      '$alreadyPresent already present, ${absent.length} absent, $bytes bytes)';
}

/// Copies the blobs a repository's rows point at from one blob store to
/// another.
///
/// ## Why the rows drive it
///
/// [TomBlobStore] has no listing, and [source] therefore cannot be asked what
/// it holds. The rows can: every `@TomFileReference` column holds a storage key,
/// so a sweep of the table *is* an enumeration of the blobs the deployment can
/// still reach. It uses only what the contract already offers — `get`,
/// `describe`, `put` — so it works between any two backends, including one an
/// application wrote.
///
/// ## What it does not do
///
/// **It does not write to the rows.** A migration between backends does not
/// change any key: the column holds the key, and which *store* that key is read
/// from is configuration (`@TomFileReference(store:)` and `TomBlobStoreInfo`),
/// not data. Saving each row back would be a no-op that ran the authorization
/// gates, stamped the audit trail and moved every `updated` timestamp in the
/// table. So this is a read-only sweep of the database, and can run against a
/// live system.
///
/// **It does not find orphans.** A blob no row names is invisible to this, and
/// no amount of care here changes that — finding it requires enumerating the
/// source, which is the one thing the contract refuses. [TomBlobMigrationReport
/// .claimed] is the list a deployment diffs its old store against, using
/// whatever that backend's own tooling offers: `find` over a directory,
/// `ListObjectsV2` over a bucket, a `SELECT` over the manifest table. That is a
/// one-off operation against a known backend, which is a fair thing to ask of a
/// migration and not a fair thing to put on a contract every backend must
/// implement.
///
/// ## Running it
///
/// ```dart
/// final report = await TomBlobMigration(
///   source: TomBlobStoreInfo.storeNamed('files-on-disk'),
///   target: TomBlobStoreInfo.storeNamed('files-on-s3'),
/// ).migrate(documentRepository);
/// if (!report.complete) { /* report.absent names the dangling references */ }
/// ```
///
/// Then repoint the configuration at the new store and re-run it: the second
/// pass copies nothing and confirms the first.
class TomBlobMigration {
  /// Creates a migration from [source] to [target].
  const TomBlobMigration({
    required this.source,
    required this.target,
    this.pageSize = 200,
    this.deleteFromSource = false,
    this.allowScopedRun = false,
  });

  /// The store the blobs are read from.
  final TomBlobStore source;

  /// The store they are written to.
  final TomBlobStore target;

  /// How many rows are read at a time.
  ///
  /// Paged rather than read whole: a migration is run against the table that
  /// grew large enough to need one.
  final int pageSize;

  /// Whether a verified copy is then deleted from [source].
  ///
  /// `false` by default, and the asymmetry is deliberate: a migration that
  /// leaves both copies is undone by changing one setting back, and a migration
  /// that deleted as it went is undone by restoring a backup. Turn it on for
  /// the second pass, once the deployment has been serving from the target.
  final bool deleteFromSource;

  /// Whether to run even though a request principal is in the zone.
  ///
  /// The sweep reads rows through [TomRepository.findAll], which applies the
  /// entity's row scope (C-3) and masks the columns the principal may not read
  /// (C-4). Under a request principal both are in force, so the sweep would
  /// migrate *that principal's view* of the table and report success — and a
  /// masked file column reads back `null`, which is indistinguishable from a row
  /// that holds no file. A migration that quietly moved a subset is the worst
  /// outcome available here, so this refuses by default.
  ///
  /// Set it only where the scope is known to open: a system principal whose
  /// resolver opts out, an entity that declares no scope and no protected
  /// column.
  final bool allowScopedRun;

  /// Copies every blob the rows of [repository] name, from [source] to [target].
  ///
  /// [fields] narrows the sweep to named file columns; empty means all of them.
  ///
  /// Throws [TomBlobMigrationException] (`storage.migration.scoped_run`) when a
  /// request principal is in the zone and [allowScopedRun] is `false`,
  /// (`storage.migration.no_file_columns`) when the entity declares none,
  /// (`storage.migration.unknown_field`) for a [fields] entry that is not one,
  /// and (`storage.migration.verification_failed`) when a copy does not match
  /// what was read.
  Future<TomBlobMigrationReport> migrate<T extends Object, K>(
    TomRepository<T, K> repository, {
    Set<String> fields = const {},
  }) async {
    if (!allowScopedRun && getFromCurrentZone<TomPrincipal>() != null) {
      throw TomBlobMigrationException(
        'storage.migration.scoped_run',
        'A blob migration cannot run inside a request.',
        parameters: {'entity': '$T'},
        autoLog: true,
      );
    }

    final columns = _columnsOf<T>(fields);
    var rows = 0;
    var copied = 0;
    var present = 0;
    var bytes = 0;
    final claimed = <String>[];
    final absent = <String>[];

    for (var page = 0; ; page++) {
      final batch = await repository.findAll(
        TomPageRequest.page(page, pageSize),
      );
      if (batch.isEmpty) break;
      rows += batch.length;
      for (final row in batch) {
        for (final column in columns) {
          final key = column.getVariableValue(row);
          if (key is! String || key.isEmpty) continue;
          final (outcome, moved) = await _relocate(key);
          switch (outcome) {
            case _Outcome.copied:
              copied++;
              bytes += moved;
              claimed.add(key);
            case _Outcome.present:
              present++;
              claimed.add(key);
            case _Outcome.absent:
              absent.add(key);
          }
        }
      }
      if (batch.length < pageSize) break;
    }

    return TomBlobMigrationReport(
      rows: rows,
      copied: copied,
      alreadyPresent: present,
      bytes: bytes,
      claimed: claimed,
      absent: absent,
    );
  }

  /// Puts the blob at [key] into [target], or reports why it did not have to,
  /// with the number of bytes that moved.
  Future<(_Outcome, int)> _relocate(String key) async {
    final wanted = await source.describe(key);
    final already = await target.describe(key);
    if (wanted == null) {
      // The row points at a blob the source does not hold. Reported, never
      // repaired: deleting the reference would destroy the only evidence of
      // what went missing, and inventing an empty blob would hide it.
      return (already == null ? _Outcome.absent : _Outcome.present, 0);
    }
    if (already != null && _sameContent(wanted, already)) {
      if (deleteFromSource) await source.delete(key);
      return (_Outcome.present, 0);
    }

    final stored = await target.put(
      key: key,
      bytes: source.get(key),
      mediaType: wanted.mediaType,
      fileName: wanted.fileName,
    );
    _verify(key, wanted, stored);
    if (deleteFromSource) await source.delete(key);
    return (_Outcome.copied, stored.byteCount);
  }

  /// Whether two descriptors of the same key describe the same bytes.
  ///
  /// The digest when both have one — which is every blob this framework wrote,
  /// and is what makes "already there" a fact rather than a guess. Size alone
  /// otherwise: a store pointed at a bucket somebody else filled records no
  /// digest, and refusing to recognise those would copy them on every run.
  static bool _sameContent(TomStoredBlob wanted, TomStoredBlob already) =>
      wanted.hasDigest && already.hasDigest
      ? wanted.digest == already.digest
      : wanted.byteCount == already.byteCount;

  /// Checks that what the target stored is what the source held.
  ///
  /// Throws rather than reporting, and stops the whole migration: a copy that
  /// silently differs is the one failure a later pass cannot detect, because
  /// the next run finds the key present and moves on.
  static void _verify(String key, TomStoredBlob wanted, TomStoredBlob stored) {
    if (_sameContent(wanted, stored)) return;
    throw TomBlobMigrationException(
      'storage.migration.verification_failed',
      'A migrated file did not arrive intact.',
      parameters: {
        'key': key,
        'sourceBytes': wanted.byteCount,
        'targetBytes': stored.byteCount,
        'sourceDigest': wanted.digest,
        'targetDigest': stored.digest,
      },
      autoLog: true,
    );
  }

  /// The file columns of [T], narrowed to [fields] when it names any.
  static List<TomColumnInformation> _columnsOf<T>(Set<String> fields) {
    final all = TomAnnotationAnalyzer.findFileColumns(T);
    if (all.isEmpty) {
      throw TomBlobMigrationException(
        'storage.migration.no_file_columns',
        'That entity stores no files.',
        parameters: {'entity': '$T'},
      );
    }
    if (fields.isEmpty) return all;
    // Both spellings, because the repository accepts both: a caller naming a
    // column the way its URL does should not be told the entity has no such
    // field.
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
      throw TomBlobMigrationException(
        'storage.migration.unknown_field',
        'That entity has no such file column.',
        parameters: {'entity': '$T', 'fields': unknown.join(', ')},
      );
    }
    return selected;
  }
}

/// What happened to one key.
enum _Outcome {
  /// The blob was read from the source and written to the target.
  copied,

  /// The target already held it, verified against the source.
  present,

  /// The source does not hold what the row names.
  absent,
}
