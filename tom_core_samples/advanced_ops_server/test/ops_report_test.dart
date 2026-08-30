/// The scheduled export, asserted where export and file storage meet.
///
/// `export.md` §"Storage: A Deliberately Narrow Seam" narrows the seam to
/// storage: rendering produces bytes, and what happens to them afterwards is
/// the store's business. This job is the first artifact in the suite that
/// crosses it on a timer — the weekly report
/// lands in the very blob store the application's attachments live in, under a
/// date-partitioned key nobody has to invent.
///
/// The renderer is real ([TomExportFormats.standard]) because the claim
/// includes the bytes: a test with a fake renderer would assert that a job
/// called a method. Only the row source and the store are stand-ins, and the
/// store is the framework's own [TomMemoryExportStore] rather than a hand-made
/// one, so the key arithmetic under test is the arithmetic production uses.
///
/// This is the one connection-free suite in the package that needs the
/// reflection build, and not incidentally: `TomTabularResult.fromEntities`
/// derives its columns from `ItemRecord`'s annotations, so an unreflected entity
/// is an export with no columns. That dependency is the feature — the report is
/// defined by the entity rather than by a hand-written projection that drifts
/// from it. Still no database, no scheduler and no socket.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/ops_server_start.reflection.dart' show initializeReflection;

/// A completed item, with just enough set to render a row.
ItemRecord _item(int id, {String title = 'item', String status = 'done'}) =>
    ItemRecord()
      ..id = id
      ..title = title
      ..status = status
      ..updatedAt = DateTime.utc(2026, 7, 30);

void main() {
  // The column set is read off the entity's annotations — see the library
  // comment for why that is the point rather than an inconvenience.
  setUpAll(initializeReflection);

  late TomMemoryExportStore store;
  late TomExportService exports;

  setUp(() {
    TomServerPrincipal.clear();
    installOpsDeploymentPrincipal();
    store = TomMemoryExportStore();
    exports = TomExportService(
      formats: TomExportFormats.standard(),
      store: store,
    );
  });
  tearDown(() {
    TomServerPrincipal.clear();
    TomAuditTrail.uninstall();
  });

  group('the report lands in the store, under a key it did not invent', () {
    test('the key is date-partitioned by the window end', () async {
      final service = OpsReportService(
        source: _FakeReportSource([_item(1)]),
        exports: exports,
      );

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      // `YYYY/MM/DD/<name>.<ext>` — the framework's own partitioning, not a
      // string this job assembled. A report published weekly for five years is
      // 260 files, and a flat namespace is the difference between a directory
      // somebody can read and one they can only grep.
      expect(outcome.stored.key, '2026/08/02/completed-items.csv');
      expect(store.keys, ['2026/08/02/completed-items.csv']);
    });

    test(
      'the stored object is the rendered bytes, not a promise of them',
      () async {
        final service = OpsReportService(
          source: _FakeReportSource([_item(1, title: 'write the readme')]),
          exports: exports,
        );

        final outcome = await runAsOpsService(
          () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
        );

        final text = store.textOf(outcome.stored.key);
        expect(text, isNotNull);
        expect(text, contains('write the readme'));
        expect(outcome.stored.byteCount, greaterThan(0));
      },
    );

    test('the rendered rows are the rows the source returned', () async {
      final service = OpsReportService(
        source: _FakeReportSource([
          _item(1, title: 'first'),
          _item(2, title: 'second'),
          _item(3, title: 'third'),
        ]),
        exports: exports,
      );

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      expect(outcome.rowCount, 3);
      final text = store.textOf(outcome.stored.key);
      for (final title in ['first', 'second', 'third']) {
        expect(text, contains(title));
      }
    });

    test('an empty week still publishes a file', () async {
      final service = OpsReportService(
        source: _FakeReportSource(const []),
        exports: exports,
      );

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      // A missing file is ambiguous — it could mean a quiet week or a job that
      // never ran. A file with a header and no rows says which.
      expect(outcome.rowCount, 0);
      expect(store.keys, hasLength(1));
      expect(store.textOf(outcome.stored.key), isNotNull);
    });

    test('the internal storage keys are not in the export', () async {
      final item = _item(1)
        ..attachment = 'items/attachment/secret-blob-key'
        ..internalNote = 'items/internal_note/secret-note-key';
      final service = OpsReportService(
        source: _FakeReportSource([item]),
        exports: exports,
      );

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      // `@TomFileReference` columns hold internal blob keys: useless to a
      // reader of the report, and a small leak to anybody else. They drop out
      // of `fromEntities` by themselves, and this asserts that they still do.
      final text = store.textOf(outcome.stored.key);
      expect(text, isNot(contains('secret-blob-key')));
      expect(text, isNot(contains('secret-note-key')));
    });
  });

  group('the window is derived from the run instant', () {
    test('it reaches back exactly one week', () async {
      final source = _FakeReportSource(const []);
      final service = OpsReportService(source: source, exports: exports);

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      expect(outcome.to, DateTime.utc(2026, 8, 2, 5));
      expect(outcome.from, DateTime.utc(2026, 7, 26, 5));
      // Half-open on purpose: the same bounds reach the query, so two
      // consecutive reports neither overlap nor leave a gap.
      expect(source.windows.single, (
        DateTime.utc(2026, 7, 26, 5),
        DateTime.utc(2026, 8, 2, 5),
      ));
    });

    test('a local run instant is normalised to UTC', () async {
      final source = _FakeReportSource(const []);
      final service = OpsReportService(source: source, exports: exports);

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5).toLocal()),
      );

      expect(outcome.to.isUtc, isTrue);
      expect(outcome.to, DateTime.utc(2026, 8, 2, 5));
    });

    test('the reported statuses are the retention set, not a second list', () {
      // The two must agree: a report that counted a status as "completed"
      // which retention did not count as deletable would describe a population
      // that never shrinks.
      expect(retainableTerminalStatuses, {
        TodoStatus.done,
        TodoStatus.cancelled,
      });
    });

    test('the window constant is a week and the format is csv', () {
      expect(opsReportWindow, const Duration(days: 7));
      expect(opsReportFormat, 'csv');
    });
  });

  group('the trail can answer for a file that left the system', () {
    late TomMemoryAuditSink sink;

    setUp(() {
      sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
    });

    test('one record, naming the key the bytes landed under', () async {
      final service = OpsReportService(
        source: _FakeReportSource([_item(1), _item(2)]),
        exports: exports,
      );

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      final record = sink.records.single;
      // The trail answers "who produced this file and when" without anybody
      // having to consult the blob store — which is the point of recording an
      // export at all.
      expect(record.targetKey, outcome.stored.key);
      expect(record.target, 'ItemRecord');
      // `execute`, not `read`: what happened is that a job ran and left a file.
      // Calling it a read would bucket it with the query that produced it.
      expect(record.action, TomAuditAction.execute);
      expect(record.outcome, TomAuditOutcome.succeeded);
      expect(record.actor.username, opsServiceUsername);
      expect(record.detail, contains('2 row(s)'));
    });

    test('a deployment without the export grant never reads a row', () async {
      TomServerPrincipal.clear();
      TomServerPrincipal.install(
        TomPrincipal(
          user: TomUser(id: 7, username: 'unlicensed-deployment'),
          aci: TomAccessControlInformation(entitlements: const []),
          authenticated: true,
        ),
      );
      final source = _FakeReportSource([_item(1)]);
      final service = OpsReportService(source: source, exports: exports);

      await expectLater(
        runAsOpsService(() => service.publishReport(DateTime.utc(2026, 8, 2))),
        throwsA(isA<TomPermanentJobFailure>()),
      );
      expect(source.windows, isEmpty);
      expect(store.keys, isEmpty);
      expect(
        sink.records.single.outcome,
        TomAuditOutcome.denied,
        reason: 'the refusal is recorded even though nothing was produced',
      );
    });
  });
}

/// An [OpsReportSource] that returns fixed rows and records its windows.
class _FakeReportSource implements OpsReportSource {
  _FakeReportSource(this.rows);

  /// What every call returns.
  final List<ItemRecord> rows;

  /// The `(from, to)` of each call — the assertion target for the window rules.
  final List<(DateTime, DateTime)> windows = [];

  @override
  Future<List<ItemRecord>> completedBetween(DateTime from, DateTime to) async {
    windows.add((from, to));
    return rows;
  }
}
