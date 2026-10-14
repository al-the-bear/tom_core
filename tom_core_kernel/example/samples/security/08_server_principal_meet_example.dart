/// Demonstrates the **meet** — the second operand every authorization decision
/// in the framework has, and the one most people do not know is there.
///
/// A control does not simply ask "may this user?". It asks that *and* "is this
/// deployment licensed for it at all?", then returns the more restrictive of
/// the two answers over the `none < disabled < read < full` ladder:
///
/// ```text
/// effective = min(user grade, deployment grade)
/// ```
///
/// So a grant that is plainly present in the user's token can still resolve to
/// [TomAuthState.none] — not a bug, but this deployment declining a feature it
/// is not entitled to. That is the symptom this sample exists to make legible.
///
/// Key concepts covered:
/// - [TomServerPrincipal] as the process-wide holder for the deployment's own
///   principal, installed once at startup from its service token
/// - [TomAccessControl.checkPrincipalAccess] (the user operand) and
///   [TomAccessControl.resolveServerAuthState] (the deployment operand) as
///   separate hooks, met by the `@nonVirtual`
///   [TomAccessControl.resolveAuthState]
/// - The cap is one-directional: the deployment narrows a user's grade and can
///   never widen it
/// - `null` is **not** an empty principal — unconfigured means *uncapped*,
///   whereas a principal holding nothing denies everything
/// - Why [TomEntitlementAccess] is the grant carrier: entitlements are the one
///   requirement kind that means the same thing asked of either principal,
///   while role and group controls keep the `full` (uncapped) default
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/08_server_principal_meet_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// Server Principal / Meet Example
// =============================================================================

/// Builds a principal holding exactly [entitlements] (and optionally [roles]).
TomPrincipal _principal(
  String username, {
  List<String> entitlements = const [],
  List<String> roles = const [],
}) => TomPrincipal(
  authenticated: true,
  user: TomUser(id: 'u-${username.hashCode.abs() % 1000}', username: username),
  aci: TomAccessControlInformation(entitlements: entitlements, roles: roles),
);

void run() {
  print('=== 08: The Server Principal and the Meet ===\n');

  // The holder is process-wide, so a sample that leaves a principal installed
  // would silently cap whatever runs next.
  TomServerPrincipal.clear();

  // ---------------------------------------------------------------------------
  // Setup: one control, one user who unambiguously holds the entitlement.
  //   Nothing about the user changes anywhere below — every difference in the
  //   outcome comes from the *other* operand.
  // ---------------------------------------------------------------------------
  const exportReports = TomEntitlementAccess(['feature.reports.export']);

  final user = _principal(
    'jo',
    entitlements: ['feature.reports.export', 'feature.reports.view'],
    roles: ['analyst'],
  );

  print('The user holds: ${user.aci.entitlements}');
  print('The control demands: feature.reports.export\n');

  // ---------------------------------------------------------------------------
  // Example 1: unconfigured — the deployment contributes no opinion.
  //   This is the designed default, not a failure mode: it is byte-for-byte
  //   the behaviour of every deployment built before server-as-principal
  //   existed.
  // ---------------------------------------------------------------------------
  print('1. No server principal installed (the uncapped regime):');

  final isConfiguredAtStart = TomServerPrincipal.isConfigured;
  final uncapped = exportReports.resolveAuthState(user);

  print('   - TomServerPrincipal.isConfigured : $isConfiguredAtStart');
  print('   - resolveAuthState(user)          : $uncapped');
  print('   → the user grant is returned untouched\n');

  // ---------------------------------------------------------------------------
  // Example 2: the symptom you probably arrived with.
  //   "The entitlement is in the token, the check still refuses."  It is, and
  //   it is still not enough — this deployment is licensed to *view* reports,
  //   not to export them.
  // ---------------------------------------------------------------------------
  print('2. A deployment NOT licensed for the feature:');

  TomServerPrincipal.install(
    _principal('reports-service', entitlements: ['feature.reports.view']),
  );
  final server = TomServerPrincipal.current!;

  // The two operands, read one at a time.
  final userOperand = exportReports.checkPrincipalAccess(user);
  final serverOperand = exportReports.resolveServerAuthState(server);

  // And their meet — the number the application actually acts on.
  final capped = exportReports.resolveAuthState(user);
  final cappedAccessible = exportReports.checkAccessibility(user);

  print('   - user.aci.entitlements     : ${user.aci.entitlements}');
  print('   - checkPrincipalAccess(user): $userOperand   ← the user operand');
  print('   - server.aci.entitlements   : ${server.aci.entitlements}');
  print('   - resolveServerAuthState()  : $serverOperand');
  print('   - resolveAuthState(user)    : $capped   ← the meet');
  print('   - checkAccessibility(user)  : $cappedAccessible');
  print('   → nothing is wrong with the user grant; the deployment lacks it\n');

  // ---------------------------------------------------------------------------
  // Example 3: license the deployment, and the same user passes.
  //   The only thing that changed is the server principal.
  // ---------------------------------------------------------------------------
  print('3. The same user, on a deployment that IS licensed:');

  TomServerPrincipal.install(
    _principal(
      'reports-service',
      entitlements: ['feature.reports.view', 'feature.reports.export'],
    ),
  );
  final licensed = exportReports.resolveAuthState(user);

  print('   - resolveAuthState(user): $licensed');
  print('   → same user, same control, different deployment\n');

  // ---------------------------------------------------------------------------
  // Example 4: the cap never widens.
  //   A generous deployment cannot hand a user something the user was never
  //   granted. min() is symmetric; the *guarantee* is not — it only ever
  //   removes.
  // ---------------------------------------------------------------------------
  print('4. A generous deployment cannot widen a user who lacks the grant:');

  final unentitledUser = _principal('sam', entitlements: ['feature.tasks']);
  final stillDenied = exportReports.resolveAuthState(unentitledUser);

  print(
    '   - deployment holds : ${TomServerPrincipal.current!.aci.entitlements}',
  );
  print('   - user holds       : ${unentitledUser.aci.entitlements}');
  print('   - resolveAuthState : $stillDenied');
  print('   → the meet removes; it never adds\n');

  // ---------------------------------------------------------------------------
  // Example 5: `null` and "empty" are opposites.
  //   The single most dangerous confusion in this area, because the two look
  //   alike in a debugger and behave inversely.
  // ---------------------------------------------------------------------------
  print('5. Unconfigured vs. a principal entitled to nothing:');

  TomServerPrincipal.install(_principal('locked-down'));
  final entitledToNothing = exportReports.resolveAuthState(user);

  TomServerPrincipal.clear();
  final noPrincipalAtAll = exportReports.resolveAuthState(user);

  print(
    '   - principal with no entitlements: $entitledToNothing  (denies all)',
  );
  print(
    '   - no principal at all           : $noPrincipalAtAll  (caps nothing)',
  );
  print('   → note the direction of clear(): it *widens* access, so it is');
  print('     never the right response to an expired service token\n');

  // ---------------------------------------------------------------------------
  // Example 6: controls that have no opinion return the identity element.
  //   A role control expresses nothing about which features a deployment
  //   licenses, so it must not contribute a veto. `full` is the correct
  //   answer, not a lenient shortcut.
  // ---------------------------------------------------------------------------
  print('6. A role control abstains from the deployment operand:');

  TomServerPrincipal.install(_principal('locked-down'));
  const analystOnly = TomRoleAccess(['analyst']);

  final roleServerOperand = analystOnly.resolveServerAuthState(
    TomServerPrincipal.current!,
  );
  final roleMeet = analystOnly.resolveAuthState(user);

  print('   - deployment holds no entitlements at all');
  print('   - TomRoleAccess.resolveServerAuthState(): $roleServerOperand');
  print('   - TomRoleAccess.resolveAuthState(user)  : $roleMeet');
  print('   → an unrelated deployment grant cannot veto a role check\n');

  // Leave the process as we found it.
  TomServerPrincipal.clear();

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: unconfigured is uncapped, and is the starting state.
  assert(!isConfiguredAtStart);
  assert(uncapped == TomAuthState.full);

  // Example 2: the user operand passes, the deployment operand refuses, and
  // the meet takes the refusal. This is the whole point of the sample.
  assert(userOperand);
  assert(serverOperand == TomAuthState.none);
  assert(capped == TomAuthState.none);
  assert(!cappedAccessible);

  // Example 3: licensing the deployment restores the user's own grade.
  assert(licensed == TomAuthState.full);

  // Example 4: the cap is one-directional.
  assert(stillDenied == TomAuthState.none);

  // Example 5: the two states are opposites, not synonyms.
  assert(entitledToNothing == TomAuthState.none);
  assert(noPrincipalAtAll == TomAuthState.full);

  // Example 6: a control with no opinion returns the identity element.
  assert(roleServerOperand == TomAuthState.full);
  assert(roleMeet == TomAuthState.full);

  // The holder is process-wide; the sample must not leak into the next one.
  assert(!TomServerPrincipal.isConfigured);

  print('Server principal / meet example complete.\n');
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
