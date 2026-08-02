/// The `min(user, server)` meet, as a test rather than as a comment.
///
/// csexd4 built the deployment cap and csexd6 documented it. What neither could
/// show is the arrangement that makes it *observable*: a principal that holds a
/// grant, in a process that is not licensed for it, being refused — and the same
/// principal, holding the same grant, being allowed the moment the cap is
/// lifted. One of those halves alone proves nothing. A refusal without the
/// second half is indistinguishable from a missing entitlement; a success
/// without the first is indistinguishable from an absent cap.
///
/// So every assertion here comes in pairs, and the *only* thing that changes
/// between the two runs is [TomServerPrincipal]. That is the whole content of
/// the claim.
///
/// Connection-free: `TomAccessControl` is kernel code over two in-memory
/// principals, so none of this needs a database, a scheduler or a reflection
/// build.
library;

import 'package:advanced_app_server/advanced_app_server.dart';
import 'package:advanced_ops_server/advanced_ops_server.dart';
import 'package:test/test.dart';
import 'package:tom_core_server/tom_core_server.dart';

/// A principal holding exactly [entitlements] — the second operand under test.
TomPrincipal _principal(String username, List<String> entitlements) =>
    TomPrincipal(
      user: TomUser(id: 99, username: username),
      aci: TomAccessControlInformation(entitlements: entitlements),
      authenticated: true,
    );

void main() {
  // Installed per test rather than in `setUpAll`, because half the tests here
  // are about the *uncapped* regime and a leaked principal would make them pass
  // for the wrong reason.
  setUp(TomServerPrincipal.clear);
  tearDown(() {
    TomServerPrincipal.clear();
    TomAuditTrail.uninstall();
  });

  group('the two operands are not the same set', () {
    test('the account holds exactly one grant the deployment does not', () {
      final extra = opsServiceAccountEntitlements
          .toSet()
          .difference(opsDeploymentEntitlements.toSet());
      // Spelled as a set difference rather than as a length check: the claim is
      // *which* grant differs, and an assertion that merely counted would still
      // pass if somebody swapped one entitlement for another.
      expect(extra, {itemReassignEntitlement});
    });

    test('the deployment is licensed for the four scheduled operations', () {
      expect(opsDeploymentEntitlements, [
        retentionPurgeEntitlement,
        digestSendEntitlement,
        exportPublishEntitlement,
        auditAnchorEntitlement,
      ]);
    });

    test('every capability pattern is anchored at both ends', () {
      // An unanchored `ops\.export\.publish` also matches
      // `evil.ops.export.publish.not`, which would make the grant carrier
      // grant more than it names. Asserted for all five rather than argued for
      // one, because the mistake is made per pattern.
      const capabilities = <TomAccessControl>[
        OpsCapabilities.purgeExpiredItems,
        OpsCapabilities.sendDigest,
        OpsCapabilities.publishExport,
        OpsCapabilities.publishAuditAnchor,
        OpsCapabilities.reassignItems,
      ];
      for (final capability in capabilities) {
        for (final pattern in (capability as TomEntitlementAccess).patterns) {
          expect(pattern, startsWith('^'), reason: pattern);
          expect(pattern, endsWith(r'$'), reason: pattern);
        }
      }
    });
  });

  group('min(user, server) — the same actor, capped and uncapped', () {
    test('uncapped, the service account may reassign an item', () {
      // No deployment principal installed: `resolveAuthState` returns the user
      // operand untouched, so this is purely "does the actor hold the grant".
      expect(TomServerPrincipal.isConfigured, isFalse);
      expect(
        OpsCapabilities.reassignItems.checkAccessibility(opsServiceAccount),
        isTrue,
      );
    });

    test('under the ops cap, the identical actor may not', () {
      installOpsDeploymentPrincipal();
      expect(
        OpsCapabilities.reassignItems.checkAccessibility(opsServiceAccount),
        isFalse,
        reason: 'min(full, none) is none — the deployment is not licensed for '
            '$itemReassignEntitlement however entitled the actor is',
      );
    });

    test('the four scheduled capabilities survive the same cap', () {
      // The refusal above must be about *this* grant and not about the cap
      // refusing everything. A deployment principal that denied all five would
      // make the test above pass and mean nothing.
      installOpsDeploymentPrincipal();
      expect(
        OpsCapabilities.purgeExpiredItems.checkAccessibility(opsServiceAccount),
        isTrue,
      );
      expect(
        OpsCapabilities.sendDigest.checkAccessibility(opsServiceAccount),
        isTrue,
      );
      expect(
        OpsCapabilities.publishExport.checkAccessibility(opsServiceAccount),
        isTrue,
      );
      expect(
        OpsCapabilities.publishAuditAnchor.checkAccessibility(
          opsServiceAccount,
        ),
        isTrue,
      );
    });

    test('neither operand can widen the other', () {
      // The mirror image, and the reason this is a meet rather than a cap: a
      // deployment licensed for everything still cannot let through an actor
      // who holds nothing.
      TomServerPrincipal.install(
        _principal('generous-deployment', opsServiceAccountEntitlements),
      );
      final stranger = _principal('stranger', const []);
      expect(
        OpsCapabilities.purgeExpiredItems.checkAccessibility(stranger),
        isFalse,
      );
      // And the licensed actor is allowed in that same process, so the refusal
      // above is about the actor and not about the installation.
      expect(
        OpsCapabilities.purgeExpiredItems.checkAccessibility(opsServiceAccount),
        isTrue,
      );
    });

    test('an empty deployment principal is not the same as none at all', () {
      // The distinction `TomServerPrincipal` documents, asserted because it is
      // the one a caller is most likely to erase by "defaulting" the cap.
      TomServerPrincipal.install(_principal('unlicensed', const []));
      expect(
        OpsCapabilities.purgeExpiredItems.checkAccessibility(opsServiceAccount),
        isFalse,
      );
      TomServerPrincipal.clear();
      expect(
        OpsCapabilities.purgeExpiredItems.checkAccessibility(opsServiceAccount),
        isTrue,
      );
    });
  });

  group('the retention pass reports the refusal it was given', () {
    final service = OpsRetentionService(store: _NullRetentionStore());

    test('uncapped it would archive rather than destroy', () {
      expect(service.reassignInsteadOfDeleting, isTrue);
    });

    test('under the ops cap it may only destroy', () {
      installOpsDeploymentPrincipal();
      expect(service.reassignInsteadOfDeleting, isFalse);
    });

    test('and says so in the pass report', () async {
      installOpsDeploymentPrincipal();
      final report = await runAsOpsService(
        () => service.purgeExpired(DateTime.utc(2026, 8, 2)),
      );
      // Reported rather than logged: a deployment that expected archiving and
      // silently got deletion is the failure mode this field exists for.
      expect(report.reassignmentRefused, isTrue);
    });
  });

  group('the gate refuses, records, and does not ask for a retry', () {
    late TomMemoryAuditSink sink;

    setUp(() {
      sink = TomMemoryAuditSink();
      TomAuditTrail.install(sink);
      installOpsDeploymentPrincipal();
    });

    test('a capability the deployment lacks throws permanently', () async {
      await expectLater(
        runAsOpsService(
          () => requireOpsCapability(
            OpsCapabilities.reassignItems,
            operation: 'OpsReassign',
            entitlement: itemReassignEntitlement,
          ),
        ),
        // Permanent, not retryable: a grant the deployment does not hold will
        // not appear during a backoff, so a retry would spend the whole budget
        // re-deriving the same no.
        throwsA(isA<TomPermanentJobFailure>()),
      );
    });

    test('the refusal reaches the trail, attributed to the service account',
        () async {
      await runAsOpsService(() async {
        try {
          await requireOpsCapability(
            OpsCapabilities.reassignItems,
            operation: 'OpsReassign',
            entitlement: itemReassignEntitlement,
          );
        } on TomPermanentJobFailure {
          // The throw is asserted above; here the interest is the record it
          // left behind on the way out.
        }
      });

      final record = sink.records.single;
      expect(record.outcome, TomAuditOutcome.denied);
      expect(record.target, 'OpsReassign');
      expect(record.action, TomAuditAction.execute);
      // `SYSTEM` would mean the zone was never established — which is exactly
      // what happens to a job body that forgets `runAsOpsService`.
      expect(record.actor.username, opsServiceUsername);
      expect(record.detail, contains(itemReassignEntitlement));
    });

    test('a capability the deployment holds passes silently', () async {
      await runAsOpsService(
        () => requireOpsCapability(
          OpsCapabilities.purgeExpiredItems,
          operation: 'OpsRetention',
          entitlement: retentionPurgeEntitlement,
        ),
      );
      // Nothing recorded: the trail is for refusals and mutations, and an entry
      // per successful permission check would bury both.
      expect(sink.records, isEmpty);
    });
  });
}

/// A retention store with nothing in it.
///
/// The meet tests are about the *decision*, not about the sweep, so the store
/// returns no candidates and would fail loudly if one were destroyed anyway.
class _NullRetentionStore implements OpsRetentionStore {
  @override
  Future<List<ItemRecord>> expiredItems(
    DateTime cutoff, {
    required int limit,
  }) async =>
      const [];

  @override
  Future<void> destroy(ItemRecord item) async =>
      throw StateError('nothing should be destroyed by an empty pass');
}
