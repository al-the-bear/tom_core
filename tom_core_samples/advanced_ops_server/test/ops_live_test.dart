/// The half of the retention claim only a database can make.
///
/// `ops_retention_test.dart` proves the *path*: one `destroy` call per candidate,
/// each carrying an entity, never a bulk statement. What it cannot prove is the
/// consequence — that the call it counted actually produces an audit row. Its
/// store is a stand-in, so a repository that quietly stopped recording deletes
/// would leave that suite entirely green.
///
/// This one closes the loop against a live `app_db`: it seeds items that are
/// past the retention window, runs the pass through the real
/// [RepositoryRetentionStore] into the real `itemRepository`, and then reads the
/// trail back. Three rows deleted, three `delete` records naming them. Nothing
/// short of a running database can show a job, a repository and a trail agreeing
/// about one row.
///
/// It also carries the other two claims that need real infrastructure: that the
/// rendered export lands in the same blob store the application's attachments
/// live in, and that the scheduling and audit tables the migration creates are
/// the ones the framework then addresses.
///
/// **Skips rather than fails when `app_db` is unreachable**, so `testkit :test`
/// on a laptop with no docker stays green. `tool/run_ops_integration.sh` boots
/// the database and treats a skip as a failure — which is what makes the skip
/// safe rather than a way to lose coverage.
///
/// The skip is per test via [markTestSkipped], matching
/// `advanced_client_core/test/cross_tier_integration_test.dart`, and not a
/// `skip:` argument on the group. A `skip:` expression is evaluated while
/// `main()` builds the tree — before any `setUpAll` has run — so it could only
/// ever read the *initial* value of [_available] and would skip unconditionally.
library;

import 'dart:convert';

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../bin/ops_server_start.dart'
    show
        blobStoreLoaderFunction,
        datasourceLoaderFunction,
        initializeRuntime,
        initializeServerResources;
import '../bin/ops_server_start.reflection.dart' show initializeReflection;

/// The uniform skip message when the live database is unreachable.
const String _skipMessage =
    'app_db unreachable — start it with `docker compose up -d app-db` in '
    'advanced_app_server, or run tool/run_ops_integration.sh';

/// Whether `app_db` answered. Set once by [_bootstrap].
bool _available = false;

/// Marks the running test skipped when `app_db` did not answer.
///
/// Returns `true` when the caller should return without asserting.
bool _unavailable() {
  if (_available) return false;
  markTestSkipped(_skipMessage);
  return true;
}

/// Brings up the same picture of `app_db` the live server has.
///
/// Deliberately the boot sequence of `bin/ops_server_start.dart`, in its order,
/// and not a shortcut. Two things depend on that order: the config-resource
/// provider must exist before the datasource YAML's `${VAR:default}` terms can
/// resolve, and `registerAppDataScopes` constructs repositories — which requires
/// the datasource *info* to already be registered, `main` delegation included.
/// Getting it wrong fails loudly here rather than subtly later, which is why the
/// loaders are imported from the boot instead of copied.
Future<void> _bootstrap() async {
  TomPlatformUtils.setCurrentPlatform(standalonePlatformUtils);
  initializeReflection();
  registerProjectRoleVocabulary();
  // `env=dev` rather than an empty argument list: the boot resolves the runtime
  // environment from the command line first, and a test that runs from a
  // directory without a `.env` would otherwise fall back to `prod`.
  initializeRuntime(['env=dev']);
  initializeServerResources();
  try {
    await TomDataSourceInfo.initializeDatasourceInfo(
      datasourceLoaderFunction(),
    );
    await TomBlobStoreInfo.initializeBlobStores(blobStoreLoaderFunction());
    registerAppDataScopes();
    registerAppColumnGrades();
    // A query that answers is the only proof worth having; a reachable host with
    // an unmigrated schema would fail later and less clearly.
    await TomDataScope.runUnscoped(
      () => itemRepository.countByQuerySentence('COUNT BY id > :zero', {
        'zero': 0,
      }),
    );
    _available = true;
  } on Object {
    // Any failure — refused connection, missing table, bad credentials — means
    // the same thing for this suite: there is no live database to assert
    // against. The runner turns the resulting skip into a failure.
    _available = false;
  }
}

/// An item that is well past any plausible retention window.
ItemRecord _expiredItem(String title) => ItemRecord()
  ..title = title
  ..status = TodoStatus.done.name
  ..updatedAt = DateTime.utc(2000, 1, 1)
  ..createdAt = DateTime.utc(2000, 1, 1);

void main() {
  setUpAll(_bootstrap);

  group('a machine-initiated delete is audited exactly like a human one', () {
    late TomMemoryAuditSink sink;
    final seeded = <ItemRecord>[];

    setUp(() async {
      if (!_available) return;
      sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      installOpsDeploymentPrincipal();
      seeded.clear();
      // Seeded unscoped and outside the trail's interest: the assertions below
      // count *delete* records, and the inserts that set the stage would
      // otherwise be indistinguishable noise.
      await TomAuditTrail.runUnaudited(() async {
        for (final title in ['ops-live-1', 'ops-live-2', 'ops-live-3']) {
          // The *returned* row, not the argument: `save` re-reads the stored
          // row and hands it back rather than mutating what it was given, so
          // the database-assigned id is on the return value. Keeping the
          // argument would leave every seeded id null, and the assertions
          // below address rows by id.
          final stored = await TomDataScope.runUnscoped(
            () => itemRepository.save(_expiredItem(title)),
          );
          seeded.add(stored);
        }
      });
      sink.clear();
    });

    tearDown(() async {
      if (!_available) return;
      // Whatever the pass did not delete must not survive into the next test —
      // a leaked expired row would make a later count ambiguous.
      await TomAuditTrail.runUnaudited(() async {
        for (final item in seeded) {
          if (item.id == null) continue;
          try {
            await TomDataScope.runUnscoped(() => itemRepository.delete(item));
          } on Object {
            // Already destroyed by the pass under test — the expected case.
          }
        }
      });
      TomAuditTrail.uninstall();
      TomServerPrincipal.clear();
    });

    test(
      'the pass destroys the seeded rows and the trail holds each one',
      () async {
        if (_unavailable()) return;
        final service = OpsRetentionService(
          store: const RepositoryRetentionStore(),
          retention: const Duration(days: 1),
        );

        final report = await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        expect(report.deleted, greaterThanOrEqualTo(3));

        // The claim the connection-free suite cannot reach: the delete the loop
        // issued produced an audit record, because it went through the repository
        // chokepoint rather than around it.
        final deletes = sink.records
            .where((record) => record.action == TomAuditAction.delete)
            .toList();
        expect(deletes.length, report.deleted);
        final titles = seeded.map((item) => item.title).toSet();
        final recordedKeys = deletes
            .map((record) => record.targetKey)
            .whereType<String>()
            .toSet();
        for (final item in seeded) {
          expect(
            recordedKeys,
            contains(item.id.toString()),
            reason: 'no audit record names the row deleted for ${item.title}',
          );
        }
        expect(titles, hasLength(3));
      },
    );

    test(
      'each record carries the before-image a bulk delete could not',
      () async {
        if (_unavailable()) return;
        final service = OpsRetentionService(
          store: const RepositoryRetentionStore(),
          retention: const Duration(days: 1),
        );

        await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        final deletes = sink.records
            .where((record) => record.action == TomAuditAction.delete)
            .toList();
        expect(deletes, isNotEmpty);
        // The before-image is the whole reason the pass is row-by-row. A record
        // without one names a row that is gone and says nothing about what it
        // held — which is a log line, not an audit record.
        expect(deletes.first.before, isNotEmpty);
        expect(deletes.first.before['title'], startsWith('ops-live-'));
        // A delete has no after-image; an empty map rather than null, because
        // `TomAuditRecord` normalises both images to maps.
        expect(deletes.first.after, isEmpty);
      },
    );

    test('the deletes are attributed to the ops service account', () async {
      if (_unavailable()) return;
      final service = OpsRetentionService(
        store: const RepositoryRetentionStore(),
        retention: const Duration(days: 1),
      );

      await runAsOpsService(
        () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
      );

      final deletes = sink.records.where(
        (record) => record.action == TomAuditAction.delete,
      );
      // `SYSTEM` here would mean the row was destroyed by nobody in
      // particular — the outcome for a job body that forgot `runAsOpsService`,
      // and the one that makes a trail unanswerable afterwards.
      for (final record in deletes) {
        expect(record.actor.username, opsServiceUsername);
      }
    });

    test('the pass sees rows the scoped read would have hidden', () async {
      if (_unavailable()) return;
      // The ops service account owns nothing and is shared nothing, so a scoped
      // read finds zero rows. Both halves are asserted, because the unscoped
      // result alone cannot show that the bypass was needed.
      final scoped = await runAsOpsService(
        () => itemRepository.findByQuerySentence(
          'FIND BY status IS IN ( :done ) AND updated_at < :cutoff',
          {'done': TodoStatus.done.name, 'cutoff': DateTime.utc(2001)},
        ),
      );
      final unscoped = await runAsOpsService(
        () => TomDataScope.runUnscoped(
          () => itemRepository.findByQuerySentence(
            'FIND BY status IS IN ( :done ) AND updated_at < :cutoff',
            {'done': TodoStatus.done.name, 'cutoff': DateTime.utc(2001)},
          ),
        ),
      );

      expect(unscoped, hasLength(greaterThanOrEqualTo(3)));
      expect(
        scoped.length,
        lessThan(unscoped.length),
        reason:
            'a scoped pass would report a clean, successful, entirely '
            'fictional retention run',
      );
    });
  });

  group('the export lands in the blob store the attachments live in', () {
    setUp(() {
      if (!_available) return;
      installOpsDeploymentPrincipal();
    });
    tearDown(() {
      TomAuditTrail.uninstall();
      TomServerPrincipal.clear();
    });

    test('a rendered report is stored and can be read back', () async {
      if (_unavailable()) return;
      // The store comes from `assets/blobstores_default.yaml` via [_bootstrap],
      // not from a literal here: a test that declared its own would prove only
      // that *some* database store works, not that the one the deployment
      // configures is the app server's.
      final service = OpsReportService(
        source: const RepositoryReportSource(),
        exports: TomExportService(
          store: TomBlobExportStore.named(null, keyPrefix: opsExportKeyPrefix),
        ),
      );

      final outcome = await runAsOpsService(
        () => service.publishReport(DateTime.utc(2026, 8, 2, 5)),
      );

      // The seam the connection-free suite mocks away: `TomExportStore` over a
      // `TomBlobStore` means the weekly report is rows in the same `tom_blob` /
      // `tom_blob_chunk` pair as an item attachment, under its own prefix.
      expect(outcome.stored.key, endsWith('completed-items.csv'));
      expect(outcome.stored.byteCount, greaterThan(0));
      // Read back through `open(key)` rather than through
      // `TomStoredExport.location`. A database-backed blob store has no
      // address to publish, so its `location` is legitimately null — and the
      // documented way to retrieve an export is the key it was stored under,
      // because only the store knows how keys map to storage.
      final store = TomBlobExportStore.named(
        null,
        keyPrefix: opsExportKeyPrefix,
      );
      final bytes = await store
          .open(outcome.stored.key)
          .fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      expect(bytes, hasLength(outcome.stored.byteCount));
      // The rendered header, so this asserts the report's *content* survived
      // the round trip and not merely that some bytes did.
      expect(utf8.decode(bytes), startsWith('id,'));
    });
  });

  group(
    'the framework tables the migration created are the ones it addresses',
    () {
      test('the scheduler can plan, claim and complete a run', () async {
        if (_unavailable()) return;
        final datasource = TomDataSourceInfo.getDataSourceInfo(
          'app_db',
        )!.datasource;
        final store = TomSqlJobStore(datasource, createSchema: false);
        final scheduler = TomScheduler(
          store: store,
          dispatcher: const TomInlineJobDispatcher(),
          ownerId: 'ops-live-test',
          lock: TomSqlLeaseLock(datasource, createSchema: false),
        );
        addTearDown(scheduler.close);

        // Registering validates every declaration against the live store; a
        // column the framework addresses and the migration did not create fails
        // here, which is the failure `ops_framework_schema_test.dart` predicts
        // without a connection.
        final definitions = TomScheduledJobs.registerAll(scheduler);

        // The sample's own four, named rather than counted. The framework
        // registers into the same scheduler — `tom.audit.anchorVerification`
        // today — so a count reads a framework addition as a regression in a
        // sample that has not changed, and the framework will add more.
        expect(
          definitions.map((definition) => definition.name).toSet().difference({
            tomAuditAnchorVerificationJobName,
          }),
          {
            opsPurgeJobName,
            opsReportJobName,
            opsDigestJobName,
            opsBlobSweepJobName,
          },
        );
        expect(
          definitions.map((definition) => definition.name),
          contains(tomAuditAnchorVerificationJobName),
          reason: 'the subtraction above must be subtracting something',
        );
        await scheduler.tick();
      });
    },
  );
}
