/// The convergence guard on the tables the **framework itself** owns.
///
/// The application's entities have had a guard since CE-MG: the entity model
/// declares a shape, the migration chain builds one, and `TomSchemaConvergence`
/// proves the two agree. The framework's own seven tables — the job queue, the
/// lease table, the roll call, the blob pair, the audit trail, the pending
/// authorizations — are not entities, so they sat outside it, and each declared
/// its columns twice: once in a `CREATE TABLE` string and again in the column
/// lists of the statements that read and write it. Nothing related the two.
///
/// This file is what relates them. Each table is now declared once, as a
/// [TomFrameworkTable], and the four tests below close the four ways a second
/// spelling could survive:
///
///  * against the **shipped reference migration** a deployment applies;
///  * against the **reflected row types** the mapper materialises, which are the
///    other half of every `SELECT`;
///  * against the **statements the stores actually issue**, driven through a
///    recording data source, so a column reference inside a `SET` or `WHERE`
///    cannot outlive the column;
///  * and, negatively, that a deliberately introduced drift is *caught* — a
///    guard nobody has watched fail is a guard nobody knows works.
///
/// Everything here runs without a database. The remaining variant, which
/// compares a descriptor against a provisioned schema's `information_schema`,
/// needs a server and lives in `framework_schema_db_test.dart`.
library;

import 'dart:collection';
import 'dart:io';

import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

import 'fixtures/reflection_fixture.reflection.dart';

/// The shipped migration chain under [directory], in file order.
///
/// Read from disk rather than re-typed, so what is compared is the file a DBA
/// applies and not a parallel copy of it.
List<TomMigrationArtifact> _chain(String directory) {
  final files = Directory(directory).listSync().whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      TomMigrationArtifact(file.uri.pathSegments.last, file.readAsStringSync()),
  ];
}

/// A data source that records what it was asked and answers nothing.
///
/// Every statement returns an empty result or a zero row count, which is enough
/// for the audit: the point is what SQL the store *emitted*, not what it did
/// with the answer. Where a store cannot proceed without a row, the caller
/// tolerates the resulting exception — the statements issued before it are still
/// recorded, and those are the subject.
class _RecordingDataSource implements TomDataSource {
  @override
  TomStandardSqlDialect get sqlDialect => MariadbSqlDialect();

  /// Every statement issued, command and query alike, in order.
  final List<String> statements = [];

  /// Rows to answer successive queries with, most stores needing none.
  final Queue<List<Object>> answers = Queue();

  @override
  Future<BigInt> executeCommand(
    String command, [
    Map<String, dynamic>? params,
  ]) async {
    statements.add(command);
    return BigInt.zero;
  }

  @override
  Future<List<T>> executeQuery<T extends Object>(
    String command, [
    Map<String, dynamic>? params,
    Type? resultType,
  ]) async {
    statements.add(command);
    if (answers.isEmpty) return <T>[];
    return answers.removeFirst().cast<T>();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'The recording data source was asked for ${invocation.memberName}, which '
    'no test needs. Implement it here if that changes.',
  );
}

/// Runs [body], swallowing whatever it throws.
///
/// The audit drives each store through every statement-issuing method it has.
/// Several cannot complete against a data source that answers nothing — a claim
/// with no candidate row, a lease read that finds none — and that is irrelevant
/// here: the statement was recorded before the store looked at the answer.
Future<void> _issuing(Future<void> Function() body) async {
  try {
    await body();
  } on Object {
    // Deliberately ignored — see above.
  }
}

void main() {
  setUpAll(initializeReflection);

  final check = TomFrameworkSchemaCheck();

  group('the descriptors and the shipped migrations build the same tables', () {
    /// Asserts that [chain] builds exactly what [tables] declare.
    void converges(String directory, List<TomFrameworkTable> tables) {
      final report = check.verifyChain(
        datasource: 'reference',
        schema: 'tomcore',
        tables: tables,
        chain: _chain(directory),
      );
      expect(report.converged, isTrue, reason: report.describe());
    }

    test('the scheduling chain builds the scheduling descriptors', () {
      converges('example/scheduling/migrations/main/tomcore', [
        jobRunTable(defaultJobRunTable),
        leaseTable(defaultLeaseTable),
        schedulerNodeTable(defaultSchedulerNodeTable),
      ]);
    });

    test('the file-storage chain builds the blob descriptors', () {
      converges('example/file_storage/migrations/main/tomcore', [
        blobManifestTable(defaultBlobManifestTable),
        blobChunkTable(defaultBlobChunkTable),
      ]);
    });

    test('the audit chain builds the trail descriptor', () {
      // The chain's other two artifacts are the write-once triggers, which
      // create no table and so contribute nothing to the replayed schema.
      converges('example/audit/migrations/main/tomcore', [
        auditTrailTable(defaultAuditTrailTable),
      ]);
    });

    test('the authentication chain builds the OAuth state descriptor', () {
      // Only `[2]` builds a descriptor table. The chain's `[1]`, `[3]` and `[4]`
      // create the two-factor enrolment, retained-token and identity-link
      // tables, which are *entities* and so are covered by the application
      // convergence check rather than this one; restricting to the descriptors'
      // tables drops them.
      converges('example/authentication/migrations/main/tomcore', [
        oauthStateTable(defaultOAuthStateTable),
        scimResourceTable(defaultScimResourceTable),
      ]);
    });

    test('the messaging chain builds the delivery-report and inbox '
        'descriptors', () {
      converges('example/messaging/migrations/main/tomcore', [
        deliveryReportTable(defaultDeliveryReportTable),
        inboxTable(defaultInboxTable),
      ]);
    });

    test('the endpoints chain builds the idempotency-key descriptor', () {
      converges('example/endpoints/migrations/main/tomcore', [
        idempotencyTable(defaultIdempotencyTable),
      ]);
    });

    test('the transactions chain builds the saga descriptor', () {
      converges('example/transactions/migrations/main/tomcore', [
        sagaTable(defaultSagaTable),
      ]);
    });

    test('the cache chain builds the invalidation-log descriptor', () {
      converges('example/cache/migrations/main/tomcore', [
        invalidationTable(defaultInvalidationTable),
      ]);
    });

    test('a chain that omits a column is reported, not tolerated', () {
      // The guard's own proof. Without it, all three tests above would still
      // pass against a comparison that reported nothing whatsoever.
      final report = check.verifyChain(
        datasource: 'reference',
        schema: 'tomcore',
        tables: [leaseTable(defaultLeaseTable)],
        chain: const [
          TomMigrationArtifact(
            'truncated',
            'CREATE TABLE tom_lease (\n'
                '  resource VARCHAR(191) NOT NULL,\n'
                '  owner VARCHAR(191) NOT NULL,\n'
                '  token BIGINT NOT NULL,\n'
                '  acquired_at DATETIME(6) NOT NULL,\n'
                '  expires_at DATETIME(6) NOT NULL,\n'
                '  released TINYINT(1) NOT NULL,\n'
                '  PRIMARY KEY (resource)\n'
                ')',
          ),
        ],
      );
      expect(report.converged, isFalse);
      expect(
        report.errors.map((e) => e.column),
        contains('version'),
        reason: report.describe(),
      );
    });
  });

  group('every column a row type maps is a column its table declares', () {
    /// Asserts that [rowTypes] map only columns [table] declares.
    void maps(TomFrameworkTable table, List<Type> rowTypes) {
      final divergences = check.verifyRowTypes(table, rowTypes);
      final errors = [
        for (final d in divergences)
          if (d.isError) d,
      ];
      expect(errors, isEmpty, reason: errors.map((e) => e.message).join('\n'));
    }

    test('the job queue', () {
      maps(jobRunTable(defaultJobRunTable), [TomJobRunRow, TomJobRunWindowRow]);
    });

    test('the lease table', () {
      maps(leaseTable(defaultLeaseTable), [TomLeaseRow]);
    });

    test('the delivery-report index', () {
      maps(deliveryReportTable(defaultDeliveryReportTable), [
        TomDeliveryReportRow,
      ]);
    });

    test('the inbox', () {
      maps(inboxTable(defaultInboxTable), [TomInboxRow]);
    });

    test('the idempotency keys', () {
      maps(idempotencyTable(defaultIdempotencyTable), [TomIdempotencyRow]);
    });

    test('the sagas', () {
      maps(sagaTable(defaultSagaTable), [TomSagaRow]);
    });

    test('the roll call', () {
      maps(schedulerNodeTable(defaultSchedulerNodeTable), [
        TomSchedulerNodeRow,
      ]);
    });

    test('the blob manifest', () {
      maps(blobManifestTable(defaultBlobManifestTable), [TomBlobManifestRow]);
    });

    test('the blob chunks', () {
      maps(blobChunkTable(defaultBlobChunkTable), [TomBlobChunkRow]);
    });

    test('the audit trail', () {
      // `TomAuditTriggerRow` is deliberately absent: it reads
      // `information_schema.TRIGGERS`, not the trail, so measuring it against
      // the trail's columns would be measuring the wrong table.
      maps(auditTrailTable(defaultAuditTrailTable), [
        TomAuditTrailRow,
        TomAuditHeadRow,
        TomAuditSeqRow,
      ]);
    });

    test('the OAuth state table', () {
      maps(oauthStateTable(defaultOAuthStateTable), [TomOAuthStateRow]);
    });

    test('the SCIM resource table', () {
      maps(scimResourceTable(defaultScimResourceTable), [TomScimResourceRow]);
    });

    test('a rename in the descriptor that the mapper did not follow fails', () {
      // The drift the whole exercise exists to catch, staged: the descriptor
      // renames `record` to `payload_json` and the row type still maps
      // `record`. Both halves still compile; the projection would simply return
      // nothing, on whichever path happened to read the trail.
      final renamed = TomFrameworkTable(
        name: defaultAuditTrailTable,
        origin: 'a renamed auditTrailTable',
        columns: const [
          TomFrameworkColumn('entry_index', 'BIGINT'),
          TomFrameworkColumn('previous_hash', 'CHAR(64)'),
          TomFrameworkColumn('hash', 'CHAR(64)'),
          TomFrameworkColumn('payload_json', 'LONGTEXT'),
        ],
      );
      final errors = check
          .verifyRowTypes(renamed, [TomAuditTrailRow])
          .where((d) => d.isError);
      expect(errors.map((e) => e.column), contains('record'));
    });

    test('a type the mapper cannot coerce the column into fails', () {
      // A `String` field is exempt — the driver decodes every value to text —
      // but an `int` field is a coercion claim, and a claim can be wrong.
      final retyped = TomFrameworkTable(
        name: defaultSchedulerNodeTable,
        origin: 'a retyped schedulerNodeTable',
        columns: const [
          TomFrameworkColumn('node_id', 'VARCHAR(191)'),
          TomFrameworkColumn('checkin_at', 'DATETIME(6)'),
          TomFrameworkColumn('checkin_interval', 'VARCHAR(32)'),
        ],
      );
      final errors = check
          .verifyRowTypes(retyped, [TomSchedulerNodeRow])
          .where((d) => d.isError);
      expect(errors.map((e) => e.column), contains('checkin_interval'));
    });
  });

  group('every column a statement names is a column its table declares', () {
    /// Drives [store] through [body] and audits every statement it issued.
    ///
    /// This is the guard on the half a generated column list cannot cover: the
    /// references inside `SET`, `WHERE` and `ORDER BY`, which stay written out
    /// because the exact shape of a conditional write is load-bearing.
    Future<void> audit(
      _RecordingDataSource datasource,
      List<TomFrameworkTable> tables,
      Future<void> Function() body,
    ) async {
      await body();
      expect(datasource.statements, isNotEmpty);
      for (final statement in datasource.statements) {
        expect(
          unknownFrameworkColumns(statement, tables),
          isEmpty,
          reason: 'in: $statement',
        );
      }
    }

    test('the job store', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlJobStore(datasource);
      final now = DateTime.utc(2026, 7, 28, 12);
      final run = TomJobRun(
        id: 'run-1',
        jobName: 'job',
        scheduledFor: now,
        runAt: now,
        state: TomJobRunState.running,
        claimedBy: 'node-a',
        claimedAt: now,
        claimToken: 1,
      );
      // A ticket built by hand: the recording data source never answers a claim,
      // so `claimDue` cannot supply one, and this test only cares about which
      // columns the statements name.
      final claim = TomJobClaim(run, 'node-a', 1);
      await audit(datasource, [jobRunTable(defaultJobRunTable)], () async {
        await _issuing(() => store.enqueue(run));
        await _issuing(() => store.findWindow('job', now));
        await _issuing(() => store.lastWindow('job'));
        await _issuing(() => store.claimDue(now, 'node-a'));
        await _issuing(() => store.markStarted(claim, now));
        await _issuing(() => store.renewClaim(claim, now));
        await _issuing(() => store.release(claim));
        await _issuing(() => store.complete(claim, now));
        await _issuing(() => store.fail(claim, 'boom', now));
        await _issuing(() => store.fail(claim, 'boom', now, retryAt: now));
        await _issuing(
          () => store.recoverAbandoned(now, const Duration(minutes: 5)),
        );
        await _issuing(() => store.all());
        await _issuing(() => store.purgeFinished(now));
        await _issuing(() => store.deleteAll());
      });
    });

    test('the lease lock', () async {
      final datasource = _RecordingDataSource();
      final lock = TomSqlLeaseLock(datasource);
      final lease = TomLease(
        resource: 'resource',
        owner: 'node-a',
        token: 1,
        acquiredAt: DateTime.utc(2026, 7, 28, 12),
        expiresAt: DateTime.utc(2026, 7, 28, 12, 1),
      );
      await audit(datasource, [leaseTable(defaultLeaseTable)], () async {
        await _issuing(
          () => lock.acquire('resource', 'node-a', const Duration(minutes: 1)),
        );
        await _issuing(() => lock.renew(lease, const Duration(minutes: 1)));
        await _issuing(() => lock.inspect('resource'));
        await _issuing(() => lock.release(lease));
      });
    });

    test('the roll call', () async {
      final datasource = _RecordingDataSource();
      final roll = TomSqlSchedulerNodes(
        datasource,
        nodeId: 'node-a',
        checkinInterval: const Duration(seconds: 5),
      );
      final now = DateTime.utc(2026, 7, 28, 12);
      await audit(
        datasource,
        [schedulerNodeTable(defaultSchedulerNodeTable)],
        () async {
          await _issuing(() => roll.checkIn(now));
          await _issuing(() => roll.nodes());
          await _issuing(() => roll.failedNodes(now));
          await _issuing(() => roll.forget('node-b'));
        },
      );
    });

    test('the OAuth state store', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlOAuthStateStore(datasource);
      final pending = TomOAuthAuthorizationState(
        state: 'handle',
        providerId: 'google',
        createdAt: DateTime.utc(2026, 7, 28, 12),
        pkce: const TomOAuthPkce('verifier', 'challenge'),
        client: 'web',
      );
      await audit(
        datasource,
        [oauthStateTable(defaultOAuthStateTable)],
        () async {
          await _issuing(() => store.store(pending));
          await _issuing(() => store.peek('handle'));
          await _issuing(() => store.consume('handle'));
          await _issuing(
            () => store.purgeExpired(DateTime.utc(2026, 7, 28, 12)),
          );
          await _issuing(() => store.deleteAll());
        },
      );
    });

    test('the SCIM store', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlScimStore(datasource);
      await audit(
        datasource,
        [scimResourceTable(defaultScimResourceTable)],
        () async {
          await _issuing(
            () => store.create(TomScimResourceType.user, {'userName': 'a'}),
          );
          await _issuing(() => store.read(TomScimResourceType.user, '1'));
          await _issuing(() => store.findByName(TomScimResourceType.user, 'a'));
          await _issuing(() => store.list(TomScimResourceType.group));
          await _issuing(
            () =>
                store.replace(TomScimResourceType.user, '1', {'userName': 'b'}),
          );
          await _issuing(() => store.delete(TomScimResourceType.user, '1'));
          await _issuing(() => store.deleteAll());
        },
      );
    });

    test('the delivery-report store', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlDeliveryReportStore(datasource);
      await audit(
        datasource,
        [deliveryReportTable(defaultDeliveryReportTable)],
        () async {
          await _issuing(
            () => store.remember(
              TomDeliveryCorrelation(
                remoteId: 'SM1',
                messageId: 'm1',
                channel: TomMessageChannel.sms,
                sentAt: DateTime.utc(2026, 9, 15, 12),
              ),
            ),
          );
          await _issuing(() => store.messageOf('SM1'));
          await _issuing(
            () => store.record(
              TomDeliveryReport(
                remoteId: 'SM1',
                state: TomDeliveryState.delivered,
                at: DateTime.utc(2026, 9, 15, 12, 5),
              ),
            ),
          );
          await _issuing(() => store.purgeSentBefore(DateTime.utc(2026, 9, 1)));
          await _issuing(() => store.deleteAll());
        },
      );
    });

    test('the inbox', () async {
      final datasource = _RecordingDataSource();
      final inbox = TomSqlInbox(datasource);
      await audit(datasource, [inboxTable(defaultInboxTable)], () async {
        await _issuing(() => inbox.process('billing', 'm1', () {}));
        await _issuing(() => inbox.hasProcessed('billing', 'm1'));
        await _issuing(
          () => inbox.purgeProcessedBefore(DateTime.utc(2026, 10, 1)),
        );
        await _issuing(() => inbox.deleteAll());
      });
    });

    test('the idempotency store', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlIdempotencyStore.over(datasource);
      const scope = TomIdempotencyScope(
        tenant: '',
        principal: 'u1',
        operation: 'POST /orders',
        key: 'k1',
      );
      final now = DateTime.utc(2026, 10, 20, 12);
      await audit(
        datasource,
        [idempotencyTable(defaultIdempotencyTable)],
        () async {
          await _issuing(
            () => store.claim(
              scope,
              'h',
              now: now,
              expiresAt: now.add(const Duration(days: 1)),
              staleBefore: now.subtract(const Duration(minutes: 5)),
            ),
          );
          await _issuing(
            () => store.complete(
              scope,
              status: 201,
              headers: const {},
              body: const [],
            ),
          );
          await _issuing(() => store.release(scope));
          await _issuing(() => store.purgeExpired(now));
          await _issuing(() => store.deleteAll());
        },
      );
    });

    test('the saga store', () async {
      final datasource = _RecordingDataSource();
      final store = TomSqlSagaStore.over(datasource);
      final now = DateTime.utc(2026, 10, 20, 12);
      final state = TomSagaState(
        id: 's1',
        name: 'place_order',
        tenant: '',
        status: TomSagaStatus.running,
        step: 0,
        version: 0,
        data: const {'order': 1},
        runWindow: now,
        createdAt: now,
        updatedAt: now,
      );
      await audit(datasource, [sagaTable(defaultSagaTable)], () async {
        await _issuing(() => store.insert(state));
        await _issuing(() => store.load('s1'));
        await _issuing(() => store.update(state, expectedVersion: 0));
        await _issuing(() => store.unfinished());
        await _issuing(() => store.purgeFinishedBefore(now));
        await _issuing(() => store.deleteAll());
      });
    });

    test('the database blob store', () async {
      final datasource = _RecordingDataSource();
      final store = TomDatabaseBlobStore(datasource);
      final tables = [
        blobManifestTable(defaultBlobManifestTable),
        blobChunkTable(defaultBlobChunkTable),
      ];
      await audit(datasource, tables, () async {
        await _issuing(
          () => store.put(key: 'key', bytes: Stream.value(const [1, 2, 3])),
        );
        await _issuing(() => store.describe('key'));
        await _issuing(() => store.exists('key'));
        await _issuing(() => store.get('key').drain<void>());
        await _issuing(() => store.delete('key'));
      });
    });

    test('the cache-invalidation channel', () async {
      final datasource = _RecordingDataSource();
      final channel = TomSqlInvalidationChannel(datasource);
      await audit(
        datasource,
        [invalidationTable(defaultInvalidationTable)],
        () async {
          await channel.start((_) async {});
          await channel.poll();
          await channel.publish(TomCacheInvalidation.principal('alice'));
          await channel.stop();
        },
      );
    });
  });
}
