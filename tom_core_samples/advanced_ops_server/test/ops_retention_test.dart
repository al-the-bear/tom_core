/// The retention pass, asserted on the two things a log line cannot show: the
/// *path* each delete took, and the fact that the trail saw every one of them.
///
/// A retention job is easy to make look right. It prints "deleted 37 rows" and
/// everybody moves on. The claim `retention_service.dart` actually makes is
/// narrower and much easier to break: that each row leaves through
/// `delete(entity)` — the call that carries a before-image into the audit trail
/// — rather than through one bulk statement that is faster, invisible, and
/// indistinguishable in the log.
///
/// So the stand-in store here records *calls*, not effects. `deleted: 3` proves
/// nothing on its own; `three separate destroy calls, each holding an entity` is
/// the claim, and it is the one that fails the day somebody replaces the loop
/// with `deleteByQuery`.
///
/// Connection-free throughout: [OpsRetentionService] takes its store through the
/// constructor, so none of this needs a database, a scheduler or a reflection
/// build. The live half — that the trail really does hold one row per delete
/// once a repository is behind it — is `ops_live_test.dart`.
library;

import 'dart:io';

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// An expired candidate. Only the fields the pass reads are set.
ItemRecord _item(int id, {String status = 'done'}) => ItemRecord()
  ..id = id
  ..title = 'item-$id'
  ..status = status
  ..updatedAt = DateTime.utc(2025, 1, 1);

void main() {
  setUp(() {
    TomServerPrincipal.clear();
    installOpsDeploymentPrincipal();
  });
  tearDown(() {
    TomServerPrincipal.clear();
    TomAuditTrail.uninstall();
  });

  group('the pass deletes one row at a time, through the audited call', () {
    test(
      'every candidate is destroyed by its own call, carrying the entity',
      () async {
        final store = _RecordingRetentionStore([_item(1), _item(2), _item(3)]);
        final service = OpsRetentionService(store: store);

        final report = await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        // Three calls, not "three rows affected". A bulk delete would report the
        // same count from one call, which is exactly the substitution this
        // assertion exists to catch.
        expect(store.destroyed, hasLength(3));
        expect(store.destroyed.map((item) => item.id), [1, 2, 3]);
        expect(report.deleted, 3);
        expect(report.examined, 3);
      },
    );

    test(
      'the reported count comes from the calls, not from the candidates',
      () async {
        // The read found four; the pass is credited with the four deletes it
        // *issued*. Wiring `deleted` to `candidates.length` would pass the test
        // above and fail here the moment a destroy stopped being reached.
        final store = _RecordingRetentionStore([
          _item(1),
          _item(2),
          _item(3),
          _item(4),
        ]);
        final service = OpsRetentionService(store: store);

        final report = await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        expect(report.deleted, store.destroyed.length);
      },
    );

    test(
      'an empty window destroys nothing and still reports a cutoff',
      () async {
        final store = _RecordingRetentionStore(const []);
        final service = OpsRetentionService(store: store);

        final report = await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        expect(store.destroyed, isEmpty);
        expect(report.deleted, 0);
        expect(report.examined, 0);
        // A pass that found nothing still says which window it looked at — the
        // difference between "nothing was expired" and "the pass never ran".
        expect(report.cutoff, DateTime.utc(2026, 5, 4));
      },
    );
  });

  group('the window is derived, not guessed', () {
    test('the cutoff is the retention period before the run instant', () async {
      final store = _RecordingRetentionStore(const []);
      final service = OpsRetentionService(
        store: store,
        retention: const Duration(days: 30),
      );

      await runAsOpsService(
        () => service.purgeExpired(DateTime.utc(2026, 8, 2, 3)),
      );

      expect(store.cutoffs.single, DateTime.utc(2026, 7, 3, 3));
    });

    test(
      'a local run instant is normalised to UTC before subtracting',
      () async {
        // The job passes `run.scheduledFor`; a caller passing a local `DateTime`
        // must not shift the window by the host's offset, or two nodes in two
        // zones would purge two different sets.
        final store = _RecordingRetentionStore(const []);
        final service = OpsRetentionService(store: store);
        final local = DateTime.utc(2026, 8, 2, 3).toLocal();

        await runAsOpsService(() => service.purgeExpired(local));

        expect(store.cutoffs.single.isUtc, isTrue);
        expect(store.cutoffs.single, DateTime.utc(2026, 5, 4, 3));
      },
    );

    test(
      'the batch limit is passed to the read, so one pass stays bounded',
      () async {
        final store = _RecordingRetentionStore(const []);
        final service = OpsRetentionService(store: store, batchLimit: 25);

        await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        expect(store.limits.single, 25);
      },
    );

    test('only terminal statuses are retention candidates', () {
      // Asserted as a set rather than argued in prose: an item that is merely
      // stale is a backlog problem, and a pass that silently widened this set
      // would be deleting live work.
      expect(retainableTerminalStatuses, {
        TodoStatus.done,
        TodoStatus.cancelled,
      });
    });
  });

  group('the pass is gated before it reads anything', () {
    test(
      'a deployment without the purge grant never reaches the store',
      () async {
        TomServerPrincipal.clear();
        TomServerPrincipal.install(
          TomPrincipal(
            user: TomUser(id: 7, username: 'unlicensed-deployment'),
            aci: TomAccessControlInformation(entitlements: const []),
            authenticated: true,
          ),
        );
        final store = _RecordingRetentionStore([_item(1)]);
        final service = OpsRetentionService(store: store);

        await expectLater(
          runAsOpsService(() => service.purgeExpired(DateTime.utc(2026, 8, 2))),
          throwsA(isA<TomPermanentJobFailure>()),
        );
        // The gate is before the read, not after it: a refused pass must not even
        // have looked, or a deployment could learn what it may not touch.
        expect(store.cutoffs, isEmpty);
        expect(store.destroyed, isEmpty);
      },
    );
  });

  group('the trail carries the refusal the pass was given', () {
    late TomMemoryAuditSink sink;

    setUp(() {
      sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
    });

    test(
      'the archival refusal is recorded once per pass, not once per row',
      () async {
        final store = _RecordingRetentionStore([_item(1), _item(2), _item(3)]);
        final service = OpsRetentionService(store: store);

        await runAsOpsService(
          () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
        );

        // One entry for three rows. The denial is a property of the deployment
        // and does not vary per item, so an entry each would bury the deletes
        // this trail exists to hold.
        final denials = sink.records
            .where((r) => r.outcome == TomAuditOutcome.denied)
            .toList();
        expect(denials, hasLength(1));
        expect(denials.single.target, 'ItemRecord');
        expect(denials.single.detail, contains(itemReassignEntitlement));
        expect(denials.single.actor.username, opsServiceUsername);
      },
    );

    test('all entries of one pass share a request id', () async {
      final store = _RecordingRetentionStore([_item(1)]);
      final service = OpsRetentionService(store: store);

      await runAsOpsService(
        () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
      );

      // What makes a night's trail readable: the several entries of one run can
      // be gathered afterwards without correlating on timestamps.
      final ids = sink.records.map((r) => r.requestId).toSet();
      expect(ids, hasLength(1));
      expect(ids.single, isNotNull);
    });

    test('an uncapped deployment records no refusal at all', () async {
      // The mirror: the entry above must be about the cap and not about the
      // pass always writing one.
      TomServerPrincipal.clear();
      final store = _RecordingRetentionStore([_item(1)]);
      final service = OpsRetentionService(store: store);

      final report = await runAsOpsService(
        () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
      );

      expect(report.reassignmentRefused, isFalse);
      expect(
        sink.records.where((r) => r.outcome == TomAuditOutcome.denied),
        isEmpty,
      );
    });
  });

  group('the bulk delete this pass must never acquire', () {
    // An architecture test, and the only kind of assertion available for it:
    // the claim is about a call that is *absent*, and a behavioural test can
    // only observe calls that happen. `deleteByQuery` would make this job
    // faster, would pass every test above that counts rows, and would silently
    // empty the audit trail — which is the whole reason the loop is written the
    // slow way.
    final source = File(
      'lib/src/jobs/retention_service.dart',
    ).readAsStringSync();

    test('the retention service issues no unaudited bulk delete', () {
      // `deleteByQuery` / `deleteByQuerySentence` cannot be audited: an audit
      // record names a target key and carries a before-image, and a bulk
      // statement has neither.
      final code = source.split('library;').last;
      expect(code, isNot(contains('deleteByQuery')));
      expect(code, isNot(contains('deleteByQuerySentence')));
    });

    test('it deletes through the repository call that carries an entity', () {
      expect(source, contains('itemRepository.delete(item)'));
    });
  });
}

/// An [OpsRetentionStore] that records what it was asked to do.
///
/// Deliberately not a mock framework: the assertions are about *which calls
/// happened with what*, and three public lists say that more plainly than a
/// verification DSL.
class _RecordingRetentionStore implements OpsRetentionStore {
  _RecordingRetentionStore(this.candidates);

  /// What the next read returns.
  final List<ItemRecord> candidates;

  /// One entry per [expiredItems] call.
  final List<DateTime> cutoffs = [];

  /// The `limit` of each [expiredItems] call.
  final List<int> limits = [];

  /// One entry per [destroy] call, in order — the heart of this test file.
  final List<ItemRecord> destroyed = [];

  @override
  Future<List<ItemRecord>> expiredItems(
    DateTime cutoff, {
    required int limit,
  }) async {
    cutoffs.add(cutoff);
    limits.add(limit);
    return candidates;
  }

  @override
  Future<void> destroy(ItemRecord item) async => destroyed.add(item);
}
