/// Who the ops server *is*, on both sides of the authorization meet.
///
/// A back-office server has no requests, so it has no principal handed to it —
/// and everything downstream of that absence goes wrong quietly. Audit entries
/// come out attributed to `SYSTEM`; access controls see `null` and answer as
/// they answer for an anonymous caller; row scopes resolve to nothing and a job
/// that should have swept a thousand rows sweeps none, successfully. None of
/// those is an error. This file exists so the ops server has an identity on
/// purpose rather than by omission.
///
/// ## Two identities, and they are not the same identity
///
/// The framework distinguishes them, and the distinction is the whole of
/// §5.26's meet:
///
/// | | What it answers | How it is installed | Scope |
/// | - | - | - | - |
/// | [opsServiceAccount] | *who* is acting | zone value, per job run ([runAsOpsService]) | one job body |
/// | [opsDeploymentPrincipal] | what this *deployment* is licensed for | `TomServerPrincipal.install` | the process |
///
/// `TomAccessControl.resolveAuthState` meets them: `min(user, server)`. Neither
/// operand can widen the other, so a deployment that is not licensed for a
/// feature caps it to [TomAuthState.none] no matter what the actor holds — and
/// an actor without the grant is refused however permissive the deployment is.
///
/// ## Why the ops server's cap is deliberately narrow
///
/// It would be easier to install a deployment principal that is entitled to
/// everything, and it would be indistinguishable from installing none at all.
/// The interesting arrangement is the opposite: the ops server is licensed for
/// exactly the four operations it schedules, and for nothing else — so a job
/// that reached beyond them is *refused by the framework* rather than by a
/// review comment.
///
/// [opsServiceAccount] therefore holds one entitlement the deployment does not:
/// [itemReassignEntitlement]. On the user side it is granted, exactly as it
/// would be for the human operator whose duties the service account mirrors. On
/// the deployment side it is absent. The meet is `min(full, none) = none`, and
/// the refusal is observable — `test/ops_authorization_meet_test.dart` shows the
/// same principal allowed the same operation once the narrow cap is lifted,
/// which is what makes it a demonstration of the *meet* and not merely of a
/// missing grant.
library;

import 'dart:async';

import 'package:tom_core_server/tom_core_server.dart';

// =============================================================================
// ENTITLEMENTS
// =============================================================================

/// Deleting task rows that have aged past the retention window.
const String retentionPurgeEntitlement = 'ops.retention.purge';

/// Composing and queueing the per-user digest.
const String digestSendEntitlement = 'ops.digest.send';

/// Rendering a report and publishing it to the blob store.
const String exportPublishEntitlement = 'ops.export.publish';

/// Publishing the audit chain head to the anchor store.
const String auditAnchorEntitlement = 'ops.audit.anchor';

/// Reassigning a live task to a different principal.
///
/// An *application* capability, held by human operators — and pointedly not by
/// this deployment. See the library comment.
const String itemReassignEntitlement = 'app.item.reassign';

/// Everything the ops **deployment** is licensed for.
///
/// The list is the cap, so it is short by design: adding an entitlement here is
/// the deliberate act of widening what any job in this process may do.
const List<String> opsDeploymentEntitlements = [
  retentionPurgeEntitlement,
  digestSendEntitlement,
  exportPublishEntitlement,
  auditAnchorEntitlement,
];

/// Everything the ops **service account** holds as an actor.
///
/// A superset of [opsDeploymentEntitlements] by exactly one entry, which is the
/// point: the account is granted what its human counterpart is granted, and the
/// deployment cap is what actually stops the job.
const List<String> opsServiceAccountEntitlements = [
  ...opsDeploymentEntitlements,
  itemReassignEntitlement,
];

// =============================================================================
// PRINCIPALS
// =============================================================================

/// The username every audit entry this server writes is attributed to.
///
/// A real name rather than `SYSTEM`. `TomAuditActor.fromCurrentZone()` falls
/// back to `SYSTEM` when no principal is in the zone, and that fallback means
/// "we could not tell" — using it for work we *can* attribute would throw away
/// the distinction the actor field exists to preserve.
const String opsServiceUsername = 'ops-service';

/// The surrogate id of the ops service account.
///
/// Negative so it cannot collide with an `auth_users.id`: the account is not a
/// row in the auth database, and giving it a plausible positive id would invite
/// a join that silently matched a real person.
const int opsServiceUserId = -1;

/// The actor every job runs as — see [runAsOpsService].
final TomPrincipal opsServiceAccount = TomPrincipal(
  user: TomUser(id: opsServiceUserId, username: opsServiceUsername),
  aci: TomAccessControlInformation(
    roles: const ['ops'],
    entitlements: opsServiceAccountEntitlements,
  ),
  authenticated: true,
);

/// The deployment's own principal — the second operand of the meet.
final TomPrincipal opsDeploymentPrincipal = TomPrincipal(
  user: TomUser(id: opsServiceUserId, username: 'advanced_ops_server'),
  aci: TomAccessControlInformation(
    entitlements: opsDeploymentEntitlements,
  ),
  authenticated: true,
);

// =============================================================================
// CAPABILITIES
// =============================================================================

/// The operations this server's jobs ask permission for.
///
/// Each is a [TomEntitlementAccess], which is the one access-control kind that
/// means the same thing asked of a user and asked of a server — "may this person
/// use the feature" and "is this deployment licensed for it" — and is therefore
/// the framework's grant carrier on both sides of the meet.
///
/// The patterns are anchored. An unanchored `ops.export.publish` would also be
/// matched by an entitlement named `evil.ops.export.publish.not`, and a grant
/// carrier that matches more than it names is not a grant carrier.
class OpsCapabilities {
  OpsCapabilities._();

  /// Deleting aged task rows.
  static const TomAccessControl purgeExpiredItems = TomEntitlementAccess([
    r'^ops\.retention\.purge$',
  ]);

  /// Queueing the digest.
  static const TomAccessControl sendDigest = TomEntitlementAccess([
    r'^ops\.digest\.send$',
  ]);

  /// Publishing an export.
  static const TomAccessControl publishExport = TomEntitlementAccess([
    r'^ops\.export\.publish$',
  ]);

  /// Publishing an audit anchor.
  static const TomAccessControl publishAuditAnchor = TomEntitlementAccess([
    r'^ops\.audit\.anchor$',
  ]);

  /// Reassigning a live task — the capability this deployment is *not*
  /// licensed for.
  static const TomAccessControl reassignItems = TomEntitlementAccess([
    r'^app\.item\.reassign$',
  ]);
}

// =============================================================================
// THE GATE
// =============================================================================

/// Refuses [operation] unless the meet allows [capability], and says so in the
/// trail either way it goes wrong.
///
/// Every job body calls this before it does anything. That is not belt and
/// braces: the deployment cap is only real if something consults it, and a
/// server that installed a narrow principal and then never asked would be
/// documentation, not enforcement.
///
/// The refusal is a [TomPermanentJobFailure] on purpose. A retry is for work
/// that might succeed later, and a capability the deployment does not hold will
/// not appear during a backoff — retrying it would spend the whole budget
/// re-deriving the same `no` and end in an alert that named the wrong cause.
Future<void> requireOpsCapability(
  TomAccessControl capability, {
  required String operation,
  required String entitlement,
}) async {
  if (capability.checkAccessibility(opsServiceAccount)) return;
  await TomAuditTrail.recordAction(
    action: TomAuditAction.execute,
    target: operation,
    outcome: TomAuditOutcome.denied,
    detail:
        'refused: the meet of $opsServiceUsername and this deployment does '
        'not grant $entitlement',
  );
  throw TomPermanentJobFailure(
    "The ops deployment is not licensed for '$operation' ($entitlement).",
  );
}

/// Installs the deployment cap for the life of the process.
///
/// Called once at boot, before any job can run. Installing it late would be
/// worse than not installing it: the meet degrades to "the user's grade alone"
/// when no server principal is present, so a job that ran before this call would
/// be *more* privileged than one that ran after, and nothing would say so.
void installOpsDeploymentPrincipal() =>
    TomServerPrincipal.install(opsDeploymentPrincipal);

// =============================================================================
// THE JOB ZONE
// =============================================================================

/// Runs [body] as the ops service account, with a fresh request id.
///
/// The counterpart of what `TomServer` does per HTTP request: the framework
/// reads the actor and the correlation id out of the *zone*, not out of an
/// argument, so a background job that does not establish them gets the
/// anonymous answers rather than an error.
///
/// Both values are load-bearing and for different readers:
///
///  * `TomPrincipal` is what `TomAuditActor.fromCurrentZone()` reads, so it
///    decides whether the trail says `ops-service` or `SYSTEM`; and
///  * `TomRequestId` is what `TomAuditTrail.currentRequestId()` reads, so it is
///    what joins the several entries one job run produces into one run. A purge
///    that deleted forty items writes forty entries, and without a shared id
///    they are forty unrelated deletions.
Future<T> runAsOpsService<T>(Future<T> Function() body) => runZoned(
  body,
  zoneValues: {
    TomPrincipal: opsServiceAccount,
    TomRequestId: TomRequestId(),
  },
);
