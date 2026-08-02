/// The retention pass: delete tasks that finished long enough ago, through the
/// path that audits.
///
/// ## Why this is the interesting job
///
/// `audit.md` makes the repository the chokepoint — every `save` and every
/// `delete` on a `TomSqlDatasourceRepository` writes an audit record, so an
/// application cannot mutate an entity through the supported path and forget to
/// record it. Everything demonstrated about that so far has been a *human*
/// mutation arriving over HTTP. This is the other half: a machine deciding, on a
/// timer, at 03:00, with nobody watching, to destroy rows. It is the mutation an
/// audit trail exists for, and it is the one that never appears in an endpoint
/// test.
///
/// ## The delete this job deliberately does not do
///
/// `DELETE FROM app_items WHERE status = 'done' AND updated_at < ?` is one
/// statement, one round trip, and *invisible to the trail*. `deleteByQuery` and
/// `deleteByQuerySentence` are not audited, and cannot be: an audit record names
/// a target key and carries a before-image, and a bulk statement has neither —
/// the database applies it to a row set the application never held.
///
/// So the pass is row-by-row on purpose: [OpsRetentionStore.expiredItems] finds
/// the candidates, and each one is destroyed with `delete(entity)`, which is the
/// call that carries a before-image into the trail. It is slower, and that is the
/// trade the deployment is making — a retention pass that cannot say *which*
/// rows it destroyed is not a retention pass anybody can defend afterwards.
/// [OpsRetentionReport.deleted] is counted from the calls actually made, never
/// from a row count, so the assertion in the test is about the path taken.
///
/// ## Why the pass runs unscoped
///
/// `ItemRecord` carries `@TomDbScope(field: 'id', scope: itemVisibilityScope)` —
/// an async row scope that resolves the *current principal's* owned ∪ shared
/// id-set and pushes it into the query as an OR-union predicate. That is exactly
/// right for a request and exactly wrong here: the ops service account owns
/// nothing and is shared nothing, so a scoped pass would find zero rows and
/// report a clean, successful, entirely fictional retention run.
///
/// [TomDataScope.runUnscoped] is the framework's answer, and this server is the
/// one caller in the sample that legitimately uses it. It pays for that in the
/// only currency available: everything it then does is attributed and audited.
/// A bypass that was also invisible would be indistinguishable from a bug.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_todo_domain/advanced_todo_domain.dart';
import 'package:tom_core_server/tom_core_server.dart';

import '../ops_identity.dart';

/// The statuses a task must be in to be eligible for retention.
///
/// Terminal states only. An item that is merely stale — untouched for a year but
/// still `todo` — is a backlog problem, not a retention candidate, and deleting
/// it would be the ops server making a product decision.
const Set<TodoStatus> retainableTerminalStatuses = {
  TodoStatus.done,
  TodoStatus.cancelled,
};

/// What one retention pass did.
class OpsRetentionReport {
  /// Creates a report.
  const OpsRetentionReport({
    required this.cutoff,
    required this.examined,
    required this.deleted,
    required this.reassignmentRefused,
  });

  /// The instant rows had to predate to be eligible.
  final DateTime cutoff;

  /// How many candidate rows the pass loaded.
  final int examined;

  /// How many rows were destroyed **through the audited call**.
  ///
  /// Counted from the deletes this pass issued, not from anything the database
  /// reported: the claim being made is about which code path ran.
  final int deleted;

  /// Whether the pass was refused the archival alternative — see
  /// [OpsRetentionService.reassignInsteadOfDeleting].
  final bool reassignmentRefused;

  @override
  String toString() =>
      'OpsRetentionReport(cutoff: $cutoff, examined: $examined, '
      'deleted: $deleted, reassignmentRefused: $reassignmentRefused)';
}

/// The two repository operations a retention pass performs.
///
/// Narrow on purpose. `TomRepository` has eighteen methods, and a job that
/// depended on all of them could only be tested against a database — which would
/// make the one claim worth asserting (that the delete goes through the audited
/// call) the one claim the test could not reach. Two methods can be implemented
/// by a recording stand-in in twenty lines.
///
/// The production implementation is [RepositoryRetentionStore], and it is the
/// only place the app server's `itemRepository` is named.
abstract class OpsRetentionStore {
  /// Candidate rows: terminal status, last touched before [cutoff].
  ///
  /// Returns at most [limit] rows so one pass cannot become unbounded; the next
  /// window picks up the remainder.
  Future<List<ItemRecord>> expiredItems(DateTime cutoff, {required int limit});

  /// Destroys [item] through the repository call that audits.
  Future<void> destroy(ItemRecord item);
}

/// [OpsRetentionStore] over the app server's own `itemRepository`.
///
/// The class is three lines of delegation and one query, and that is the point:
/// the ops server does not own a second entity model for `app_items`. It deletes
/// through the very repository the app server's write endpoints delete through,
/// so "a machine-initiated delete is audited exactly like a human one" is true
/// by construction rather than by two implementations agreeing.
class RepositoryRetentionStore implements OpsRetentionStore {
  /// Creates a store over the app server's process-wide item repository.
  const RepositoryRetentionStore();

  @override
  Future<List<ItemRecord>> expiredItems(
    DateTime cutoff, {
    required int limit,
  }) async {
    // `IS IN ( … )` takes one expression per element, so the placeholders are
    // generated from the status set rather than written out. Spelling them by
    // hand would silently stop covering a status the day the domain grows one,
    // and a retention pass that quietly narrowed its own definition of
    // "finished" is the kind of bug nobody reports.
    final statuses = retainableTerminalStatuses.map((s) => s.name).toList();
    final placeholders = [
      for (var i = 0; i < statuses.length; i++) ':status$i',
    ].join(' , ');
    final parameters = <String, Object?>{
      for (var i = 0; i < statuses.length; i++) 'status$i': statuses[i],
      'cutoff': cutoff,
    };
    // `TOP` is a sentence keyword, not a bind parameter — it is interpolated
    // because the compiler parses it as a literal. Safe here and only here:
    // [limit] is this class's own int, never anything a request supplied.
    //
    // Unscoped: see the library comment. The bypass covers the *read* as well as
    // the write — a scoped read would return nothing to delete, and the pass
    // would succeed having done nothing.
    final matches = await TomDataScope.runUnscoped(
      () => itemRepository.findByQuerySentence(
        'FIND TOP $limit BY status IS IN ( $placeholders ) '
        'AND updated_at < :cutoff ORDER BY updated_at',
        parameters,
      ),
    );
    return matches.toList();
  }

  @override
  Future<void> destroy(ItemRecord item) =>
      TomDataScope.runUnscoped(() => itemRepository.delete(item));
}

/// Deletes terminal tasks that have aged past the retention window.
///
/// Separate from the job class that schedules it, so the behaviour can be
/// exercised without reflection, without a scheduler and without a database —
/// and so the job class stays what it should be: a trigger.
class OpsRetentionService {
  /// Creates a retention pass.
  ///
  /// [retention] is how long a finished task is kept. [batchLimit] bounds one
  /// pass; a backlog drains over successive windows rather than in one
  /// transaction long enough to matter.
  OpsRetentionService({
    required this.store,
    this.retention = const Duration(days: 90),
    this.batchLimit = 500,
  });

  /// Where candidates come from and where deletes go.
  final OpsRetentionStore store;

  /// How long a terminal task is kept before it becomes a candidate.
  final Duration retention;

  /// The most rows one pass will destroy.
  final int batchLimit;

  /// Whether this deployment may archive rather than destroy.
  ///
  /// The archival alternative — reassigning an expired task to a retention
  /// custodian instead of deleting it — is a *live-data mutation*, and this
  /// deployment is deliberately not licensed for one. The check is the meet:
  /// [OpsCapabilities.reassignItems] resolved for [opsServiceAccount], which
  /// holds [itemReassignEntitlement], against the ambient
  /// [TomServerPrincipal], which does not.
  ///
  /// So it is `false` here and `true` for the human operator with the identical
  /// grant, in a process without the narrow cap. That difference is the whole
  /// observable content of `min(user, server)`, and
  /// `test/ops_authorization_meet_test.dart` asserts both halves of it.
  bool get reassignInsteadOfDeleting =>
      OpsCapabilities.reassignItems.checkAccessibility(opsServiceAccount);

  /// Runs one pass against the window ending at [now].
  ///
  /// Deletes are issued one at a time and counted as they are made; a row that
  /// vanished between the read and the delete is not an error, so the count is
  /// of *attempts that returned*, which is what the trail will also hold.
  Future<OpsRetentionReport> purgeExpired(DateTime now) async {
    await requireOpsCapability(
      OpsCapabilities.purgeExpiredItems,
      operation: 'OpsRetention',
      entitlement: retentionPurgeEntitlement,
    );

    final cutoff = now.toUtc().subtract(retention);
    final refused = !reassignInsteadOfDeleting;
    if (refused) {
      // Recorded once per pass rather than once per row: the denial is a
      // property of the deployment, not of any particular item, and one entry
      // per item would drown the trail in a fact that does not vary.
      await TomAuditTrail.recordAction(
        action: TomAuditAction.execute,
        target: 'ItemRecord',
        outcome: TomAuditOutcome.denied,
        detail:
            'archive-instead-of-delete refused: this deployment is not '
            'licensed for $itemReassignEntitlement',
      );
    }

    final candidates = await store.expiredItems(cutoff, limit: batchLimit);
    var deleted = 0;
    for (final item in candidates) {
      await store.destroy(item);
      deleted++;
    }
    return OpsRetentionReport(
      cutoff: cutoff,
      examined: candidates.length,
      deleted: deleted,
      reassignmentRefused: refused,
    );
  }
}
