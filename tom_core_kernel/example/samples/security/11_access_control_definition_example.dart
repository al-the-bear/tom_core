/// Demonstrates **where a principal's permissions come from** — the definition
/// side of the security model, which is the half a token never shows you.
///
/// Everything else in these samples reads a [TomAccessControlInformation] that
/// already exists. This one builds it. A user is assigned one role; the roles,
/// groups and entitlements that role drags in are resolved from
/// [TomAccessControlDefinition] at login time, folded flat, and minted into the
/// authorization token. By the time an access control asks "does this principal
/// hold `reports.write`?", the inheritance has already happened — which is
/// exactly why a control never has to walk a graph, and why a permission
/// change takes effect on the next login rather than the next request.
///
/// ```text
///   assigned          defined                    completed (in the token)
///   roles: [lead] ──▶ lead ⊃ analyst, staff  ──▶ roles, groups, entitlements
///                     staff ⊃ everyone            and resource keys, flat
/// ```
///
/// Key concepts covered:
/// - [TomRole], [TomGroup] and [TomEntitlement] as the three definition kinds,
///   and the fact that all three can grant entitlements and resource keys
/// - [TomAccessControlDefinition.completeFromDefinition] as the one fold, run
///   once per login
/// - Inheritance is transitive and crosses kinds — a role can put you in a
///   group, and that group's parent group's entitlements still reach you
/// - The fold is a *union*: an assignment naming something the definition does
///   not define is kept, not dropped
/// - Resource roles (C-5) pass through untouched, because they are per-resource
///   assignments rather than anything the graph could derive
///
/// To run this file on its own:
/// ```bash
/// dart run --enable-asserts example/samples/security/11_access_control_definition_example.dart
/// ```
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// Access Control Definition Example
// =============================================================================

void run() {
  print('=== 11: Where Permissions Come From ===\n');

  // ---------------------------------------------------------------------------
  // Example 1: the three definition kinds.
  //   Roles and groups look alike on purpose — both include roles, both join
  //   groups, both grant entitlements and keys. They differ in what they model,
  //   not in what they can express: a role is a job, a group is an org unit.
  //   An entitlement is the leaf: it grants keys and other entitlements, and
  //   nothing else.
  // ---------------------------------------------------------------------------
  print('1. Roles, groups and entitlements:');

  final reportsManage = TomEntitlement(
    name: 'reports.manage',
    entitlements: ['reports.read', 'reports.write'],
    resourceKeys: ['report.total'],
  );

  final analyst = TomRole(
    name: 'analyst',
    entitlements: ['reports.read'],
    resourceKeys: ['report.summary'],
  );

  // A role that inherits another role *and* joins a group.
  final lead = TomRole(
    name: 'lead',
    rolesIncluded: ['analyst'],
    groupMemberShips: ['staff'],
    entitlements: ['reports.manage'],
  );

  final staff = TomGroup(
    name: 'staff',
    groupMemberShips: ['everyone'],
    entitlements: ['directory.view'],
    resourceKeys: ['user.email'],
  );

  final everyone = TomGroup(name: 'everyone', entitlements: ['login']);

  final definition = TomAccessControlDefinition(
    roles: [analyst, lead],
    groups: [staff, everyone],
    entitlements: [reportsManage],
  );

  print('   - $lead');
  print('   - $staff');
  print('   - $reportsManage');
  print('   - definition: $definition');
  print('   → three kinds, one graph\n');

  // ---------------------------------------------------------------------------
  // Example 2: one assignment in, everything reachable out.
  //   This is the fold the login runs. Note how little the user is assigned:
  //   a single role name. Everything below it is definition, not data on the
  //   user.
  // ---------------------------------------------------------------------------
  print('2. Completing a one-role assignment:');

  final assigned = TomAccessControlInformation(roles: ['lead']);
  final completed = definition.completeFromDefinition(assigned);

  print('   - assigned.roles        : ${assigned.roles}');
  print('   - assigned.entitlements : ${assigned.entitlements}');
  print('   - completed.roles       : ${_sorted(completed.roles)}');
  print('   - completed.groups      : ${_sorted(completed.groups)}');
  print('   - completed.entitlements: ${_sorted(completed.entitlements)}');
  print('   - completed.resourceKeys: ${_sorted(completed.resourceKeys)}');
  print('   → "everyone" arrives via staff, via lead: two hops and a kind\n');

  // ---------------------------------------------------------------------------
  // Example 3: the fold unions, it does not filter.
  //   A name the definition has never heard of survives — deliberately. The
  //   definition is a *deployment's* configuration, and an ACI can legitimately
  //   carry grants from elsewhere; silently dropping them would turn a
  //   configuration gap into a permission that vanishes without a trace.
  // ---------------------------------------------------------------------------
  print('3. Undefined names are kept, not dropped:');

  final withUnknown = definition.completeFromDefinition(
    TomAccessControlInformation(
      roles: ['lead', 'auditor'],
      entitlements: ['legacy.export'],
    ),
  );

  print('   - "auditor" is not defined anywhere');
  print('   - completed.roles       : ${_sorted(withUnknown.roles)}');
  print('   - completed.entitlements: ${_sorted(withUnknown.entitlements)}');
  print('   → a configuration gap must not look like a revocation\n');

  // ---------------------------------------------------------------------------
  // Example 4: resource roles pass through.
  //   These are per-resource assignments (this document, that project) — there
  //   is nothing in a role graph that could derive them, so the fold carries
  //   them across untouched rather than pretending to resolve them.
  // ---------------------------------------------------------------------------
  print('4. Resource roles are carried, not derived:');

  final withResourceRoles = definition.completeFromDefinition(
    TomAccessControlInformation(
      roles: ['analyst'],
      resourceRoles: {'project:42': 'owner', 'project:99': 'viewer'},
    ),
  );

  print('   - resourceRoles: ${withResourceRoles.resourceRoles}');
  print('   - roles        : ${_sorted(withResourceRoles.roles)}');
  print('   → C-5 assignments are data about a resource, not about a role\n');

  // ---------------------------------------------------------------------------
  // Example 5: an empty definition is the identity.
  //   Worth knowing because it is what a deployment that configures nothing
  //   gets: the assignment reaches the token exactly as given.
  // ---------------------------------------------------------------------------
  print('5. An empty definition changes nothing:');

  final empty = TomAccessControlDefinition();
  final unchanged = empty.completeFromDefinition(assigned);

  print('   - $empty');
  print('   - completed.roles       : ${_sorted(unchanged.roles)}');
  print('   - completed.entitlements: ${_sorted(unchanged.entitlements)}');
  print('   → no definition, no inheritance — not "no access"\n');

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: the definition kinds keep what they were given.
  assert(lead.name == 'lead');
  assert(lead.rolesIncluded.join(',') == 'analyst');
  assert(lead.groupMemberShips.join(',') == 'staff');
  assert(analyst.resourceKeys.join(',') == 'report.summary');
  assert(staff.groupMemberShips.join(',') == 'everyone');
  assert(everyone.entitlements.join(',') == 'login');
  assert(reportsManage.entitlements.join(',') == 'reports.read,reports.write');
  assert(reportsManage.resourceKeys.join(',') == 'report.total');
  // A definition kind with nothing but a name is legal — the graph is allowed
  // to have leaves.
  assert(TomRole(name: 'bare').entitlements.isEmpty);
  assert(TomGroup(name: 'bare').rolesIncluded.isEmpty);
  assert(TomEntitlement(name: 'bare').resourceKeys.isEmpty);

  // Example 2: the fold is transitive and crosses kinds.
  assert(assigned.roles.join(',') == 'lead');
  assert(assigned.entitlements.isEmpty);
  assert(_sorted(completed.roles).join(',') == 'analyst,lead');
  // "everyone" is reached through staff, which is reached through lead.
  assert(_sorted(completed.groups).join(',') == 'everyone,staff');
  // reports.write comes from the reports.manage *entitlement* definition, which
  // the lead role granted by name.
  assert(
    _sorted(completed.entitlements).join(',') ==
        'directory.view,login,reports.manage,reports.read,reports.write',
  );
  assert(
    _sorted(completed.resourceKeys).join(',') ==
        'report.summary,report.total,user.email',
  );
  // The fold produces a new ACI; the assignment it was given is untouched.
  assert(assigned.roles.length == 1);

  // Example 3: unknown names survive the fold.
  assert(withUnknown.roles.contains('auditor'));
  assert(withUnknown.entitlements.contains('legacy.export'));
  // …and they inherit nothing, having nothing defined to inherit from.
  assert(_sorted(withUnknown.roles).join(',') == 'analyst,auditor,lead');

  // Example 4: resource roles cross unchanged, and the roles still complete.
  assert(withResourceRoles.resourceRoles['project:42'] == 'owner');
  assert(withResourceRoles.resourceRoles.length == 2);
  assert(_sorted(withResourceRoles.roles).join(',') == 'analyst');
  assert(withResourceRoles.entitlements.contains('reports.read'));

  // Example 5: the empty definition is the identity, not a denial.
  assert(_sorted(unchanged.roles).join(',') == 'lead');
  assert(unchanged.entitlements.isEmpty);
  assert(unchanged.groups.isEmpty);

  print('Access control definition example complete.\n');
}

/// Sorted copy, so the printed and asserted order does not depend on the
/// traversal order of the fold.
List<String> _sorted(List<String> values) => [...values]..sort();

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
