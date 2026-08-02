/// The weekly completion report: rendered by the export module, written into
/// the same blob store the application's attachments live in.
///
/// ## The seam this closes
///
/// `export.md:394` narrows the export module's dependency on storage to one
/// interface — `TomExportStore` — and observes that a deployment already running
/// `TomBlobStore` for its `@TomFileReference` columns has somewhere to put an
/// export without adding infrastructure. `TomBlobExportStore` is that adapter,
/// and until this job existed nothing in the suite instantiated it. Here the two
/// modules genuinely meet: the report goes into `app_db`'s `tom_blob` /
/// `tom_blob_chunk` tables, beside the item attachments of
/// README_advanced_13_file_transfer.md, under a key prefix that keeps them
/// apart.
///
/// ## Why the key is date-partitioned and the report is not
///
/// [TomExportService.keyFor] partitions on the run date, so week after week the
/// store fills with `exports/2026/08/02/…` rather than one flat directory that
/// becomes unlistable long before it becomes large — and a retention rule over
/// exports is then a prefix, not a scan.
///
/// The *content*, by contrast, is a closed window: the seven days ending at the
/// run. A report whose contents depend on when it is read cannot be reconciled
/// with anything, and the whole value of an archived export is that it still
/// says in November what it said in August.
///
/// ## Why CSV
///
/// [TomExportFormats.standard] also ships XLSX and PDF, and either would work
/// unchanged — the format is a string this class takes as a parameter. CSV is
/// the default because the consumer of a scheduled operational export is
/// another program, and a spreadsheet with merged header cells is a worse input
/// to a program than the plainest thing that round-trips.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../ops_identity.dart';
import 'retention_service.dart';

/// The window one report covers.
const Duration opsReportWindow = Duration(days: 7);

/// The format the scheduled report is rendered in — see the library comment.
const String opsReportFormat = 'csv';

/// The key prefix every scheduled export is written under.
///
/// Namespaced so an export can never collide with an item attachment (which the
/// app server keys `items/attachment/…`), and so "delete exports older than a
/// year" is expressible as a prefix rather than a query.
const String opsExportKeyPrefix = 'exports';

/// What one report pass produced.
class OpsReportOutcome {
  /// Creates an outcome.
  const OpsReportOutcome({
    required this.from,
    required this.to,
    required this.rowCount,
    required this.stored,
  });

  /// The inclusive start of the reported window.
  final DateTime from;

  /// The exclusive end of the reported window.
  final DateTime to;

  /// How many rows the report carries.
  final int rowCount;

  /// The store's descriptor: the key to read it back with, and its size.
  final TomStoredExport stored;

  @override
  String toString() =>
      'OpsReportOutcome($from..$to, rows: $rowCount, key: ${stored.key}, '
      'bytes: ${stored.byteCount})';
}

/// The rows one report is built from.
///
/// A port for the same reason [OpsRetentionStore] is one: the claim worth
/// asserting — that the rendered bytes reach the blob store under a partitioned
/// key — is about the export and storage modules, and making it depend on a live
/// `app_db` would put it out of reach of every test that runs by default.
abstract class OpsReportSource {
  /// Items that reached a terminal status between [from] (inclusive) and [to]
  /// (exclusive).
  Future<List<ItemRecord>> completedBetween(DateTime from, DateTime to);
}

/// [OpsReportSource] over the app server's item repository.
class RepositoryReportSource implements OpsReportSource {
  /// Creates a source over the process-wide item repository.
  const RepositoryReportSource();

  @override
  Future<List<ItemRecord>> completedBetween(DateTime from, DateTime to) async {
    // The same terminal set the retention pass uses, and deliberately the same
    // constant: a report that counted a status as "completed" which retention
    // did not count as deletable would describe a population that never shrinks.
    final statuses = retainableTerminalStatuses.map((s) => s.name).toList();
    final placeholders = [
      for (var i = 0; i < statuses.length; i++) ':status$i',
    ].join(' , ');
    final rows = await TomDataScope.runUnscoped(
      () => itemRepository.findByQuerySentence(
        'FIND BY status IS IN ( $placeholders ) '
        'AND updated_at >= :from AND updated_at < :to ORDER BY updated_at',
        {
          for (var i = 0; i < statuses.length; i++) 'status$i': statuses[i],
          'from': from,
          'to': to,
        },
      ),
    );
    return rows.toList();
  }
}

/// Renders the weekly completion report and stores it.
class OpsReportService {
  /// Creates a report pass.
  ///
  /// [exports] must be configured with a store — a service without one throws
  /// on [TomExportService.storeAs], and this job has nowhere else to put its
  /// output.
  OpsReportService({
    required this.source,
    required this.exports,
    this.window = opsReportWindow,
    this.format = opsReportFormat,
    this.baseName = 'completed-items',
  });

  /// Where the rows come from.
  final OpsReportSource source;

  /// The renderer-plus-store the export module supplies.
  final TomExportService exports;

  /// How far back one report reaches.
  final Duration window;

  /// The format id — `csv`, `xlsx` or `pdf`.
  final String format;

  /// The file name stem; the renderer supplies the extension.
  final String baseName;

  /// Renders the window ending at [now] and stores it.
  Future<OpsReportOutcome> publishReport(DateTime now) async {
    await requireOpsCapability(
      OpsCapabilities.publishExport,
      operation: 'OpsReport',
      entitlement: exportPublishEntitlement,
    );

    final to = now.toUtc();
    final from = to.subtract(window);
    final rows = await source.completedBetween(from, to);

    // `fromEntities` reads the column set off `ItemRecord`'s `@TomDbColumn`
    // annotations, so the report is defined by the entity rather than by a
    // hand-written projection that drifts from it. Two kinds of column drop out
    // by themselves and both should: `@TomAudited(redact:)` fields, and the
    // `@TomFileReference` columns — `attachment` and `internalNote` hold
    // internal storage keys, which are useless to a reader and a small leak to
    // anyone else.
    final result = TomTabularResult.fromEntities<ItemRecord>(
      Stream<ItemRecord>.fromIterable(rows),
      title: 'Completed items',
      sectionTitle: 'Completed items',
      metadata: {
        'Window': '${_iso(from)} .. ${_iso(to)}',
        'Statuses': retainableTerminalStatuses.map((s) => s.name).join(', '),
        'Produced by': opsServiceUsername,
      },
    );

    final key = exports.keyFor(baseName, format, partitionOn: to);
    final stored = await exports.storeAs(result, format, key: key);

    // Recorded because the export leaves the system: a file now exists that
    // contains application data, and the trail should be able to answer who
    // produced it and when without consulting the blob store.
    await TomAuditTrail.recordAction(
      // `execute` rather than `read`: the trail's action vocabulary has no
      // `export`, and calling it a read would put it in the same bucket as the
      // query that produced it. What happened is that a job ran and left a file.
      action: TomAuditAction.execute,
      target: 'ItemRecord',
      targetKey: stored.key,
      outcome: TomAuditOutcome.succeeded,
      detail:
          '${rows.length} row(s) for ${_iso(from)}..${_iso(to)}, '
          '${stored.byteCount} byte(s)',
    );

    return OpsReportOutcome(
      from: from,
      to: to,
      rowCount: rows.length,
      stored: stored,
    );
  }

  static String _iso(DateTime value) =>
      value.toUtc().toIso8601String().split('T').first;
}
