/// Demonstrates per-principal-per-resource role authorization (C-5) — the
/// kernel's only shipped [TomAuthorizationAdapter].
///
/// The global [TomAccessControlInformation.roles] answer "*what is this
/// principal, everywhere?*". Resource roles answer the finer question "*what is
/// this principal **on this resource**?*", so the same user can be `owner` of
/// one project and `viewer` of another at the same moment.
///
/// Key concepts covered:
/// - [TomResourceRoleRegistry] as the process-wide `roleName → TomAuthState`
///   table, declared once at startup
/// - [TomResourceRoleAdapter] resolving a resource key through the principal's
///   `resourceKey → roleName` map and then through that table
/// - The **no-fallback guarantee**: an ungranted resource resolves to
///   [TomAuthState.none], and so does an unregistered role — neither degrades
///   to the global roles nor to `full`
/// - Installing the adapter on [TomAuthorization] so the whole UI resolves
///   through it
/// - [TomResourceRoleAdapter.stateOf] for server-side enforcement call sites
///   that gate an operation without going through the global singleton
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_preamble.dart';

// =============================================================================
// Resource Role Authorization Example
// =============================================================================

void run() {
  print('=== 07: Per-Resource Role Authorization Example ===\n');

  // Start from a clean slate: both the registry and the singleton are
  // process-wide, so a sample that leaves state behind corrupts the next one.
  TomResourceRoleRegistry.reset();
  TomAuthorization.reset();

  // ---------------------------------------------------------------------------
  // Example 1: declare what each role *means* as a resource-level state.
  //   Roles arrive from the grant data as opaque strings; the registry is the
  //   one place an application says what they are worth. Client and server
  //   declare the same mapping so presentation and enforcement agree.
  // ---------------------------------------------------------------------------
  print('1. Registering the role vocabulary:');

  TomResourceRoleRegistry.registerAll({
    'owner': TomAuthState.full,
    'editor': TomAuthState.full,
    'commenter': TomAuthState.read,
    'viewer': TomAuthState.read,
  });

  final ownerState = TomResourceRoleRegistry.stateFor('owner');
  final viewerState = TomResourceRoleRegistry.stateFor('viewer');
  final unknownRoleState = TomResourceRoleRegistry.stateFor('sovereign');

  print('   - owner     → $ownerState');
  print('   - viewer    → $viewerState');
  print('   - sovereign → $unknownRoleState (never registered)\n');

  // ---------------------------------------------------------------------------
  // Example 2: one principal, two resources, two different states at once.
  //   This is what the global `roles` list cannot express.
  // ---------------------------------------------------------------------------
  print('2. One principal holding different roles on different resources:');

  final alice = TomAccessControlInformation(
    // Global role — deliberately generous, to show it does not leak below.
    roles: ['admin'],
    resourceRoles: {'project.apollo': 'owner', 'project.gemini': 'viewer'},
  );

  final adapter = TomResourceRoleAdapter(alice.resourceRoles);

  final apollo = adapter.resolveAuth('project.apollo');
  final gemini = adapter.resolveAuth('project.gemini');

  print('   - project.apollo (owner):  $apollo');
  print('   - project.gemini (viewer): $gemini\n');

  // ---------------------------------------------------------------------------
  // Example 3: the no-fallback guarantee (C-5 done-bar), both halves.
  //   (a) A resource the principal has no role on resolves to `none`. Note that
  //       Alice is a global `admin` — that grant is irrelevant here, which is
  //       the entire point: resource roles do not degrade to global roles.
  //   (b) A role with no registry entry also resolves to `none`. An unknown
  //       role grants nothing rather than silently granting access.
  // ---------------------------------------------------------------------------
  print('3. No fallback — ungranted resource and unregistered role:');

  final ungranted = adapter.resolveAuth('project.mercury');

  final strangeRole = TomResourceRoleAdapter(const {
    'project.mercury': 'sovereign', // a role nobody registered
  });
  final unregistered = strangeRole.resolveAuth('project.mercury');

  print('   - project.mercury, no role at all:      $ungranted');
  print('   - project.mercury, role "sovereign":    $unregistered');
  print('     (Alice is a global `admin`; it does not leak through)\n');

  // ---------------------------------------------------------------------------
  // Example 4: installing the adapter on the global singleton.
  //   With no adapter, TomAuthorization resolves everything to `full`
  //   (development mode). Installing one closes that door.
  // ---------------------------------------------------------------------------
  print('4. Installing on TomAuthorization:');

  final beforeInstall = TomAuthorization.resolveAuth('project.apollo');

  TomAuthorization.adapter = adapter;
  final afterInstall = TomAuthorization.resolveAuth('project.apollo');
  final afterInstallOther = TomAuthorization.resolveAuth('project.gemini');
  final afterInstallUngranted = TomAuthorization.resolveAuth('project.mercury');

  print('   - before any adapter (dev default): $beforeInstall');
  print('   - project.apollo:                   $afterInstall');
  print('   - project.gemini:                   $afterInstallOther');
  print('   - project.mercury:                  $afterInstallUngranted\n');

  // ---------------------------------------------------------------------------
  // Example 5: driving a UI decision from the resolved state.
  // ---------------------------------------------------------------------------
  print('5. Rendering decisions from the resolved state:');

  final canEditApollo = afterInstall.isInteractive;
  final canReadGemini = afterInstallOther.showsContent;
  final mercuryVisible = afterInstallUngranted.isVisible;

  print('   - apollo editable:  $canEditApollo');
  print('   - gemini readable:  $canReadGemini');
  print('   - mercury visible:  $mercuryVisible\n');

  // ---------------------------------------------------------------------------
  // Example 6: `stateOf` — the same computation, named for server-side
  //   enforcement call sites that have an adapter in hand and deliberately do
  //   not want the ambient singleton.
  // ---------------------------------------------------------------------------
  print('6. Server-side enforcement via stateOf:');

  final enforcedApollo = adapter.stateOf('project.apollo');
  final enforcedMercury = adapter.stateOf('project.mercury');

  print('   - stateOf(project.apollo):  $enforcedApollo');
  print('   - stateOf(project.mercury): $enforcedMercury\n');

  // ---------------------------------------------------------------------------
  // Example 7: the registry snapshot is a copy, not a back door.
  // ---------------------------------------------------------------------------
  print('7. The registry mapping is an unmodifiable snapshot:');

  final snapshot = TomResourceRoleRegistry.mapping;
  var snapshotIsReadOnly = false;
  try {
    snapshot['intruder'] = TomAuthState.full;
  } on UnsupportedError {
    snapshotIsReadOnly = true;
  }

  print('   - roles registered:       ${snapshot.length}');
  print('   - rejects modification:   $snapshotIsReadOnly\n');

  // Clean up both pieces of process-wide state for the samples that follow.
  TomAuthorization.reset();
  TomResourceRoleRegistry.reset();

  // ===========================================================================
  // Assertions
  // ===========================================================================

  // Example 1: the registry answers for known roles and `null` for unknown ones.
  assert(ownerState == TomAuthState.full);
  assert(viewerState == TomAuthState.read);
  assert(unknownRoleState == null);

  // Example 2: one principal, two resources, two states.
  assert(apollo == TomAuthState.full);
  assert(gemini == TomAuthState.read);

  // Example 3: both halves of the no-fallback guarantee.
  assert(ungranted == TomAuthState.none);
  assert(unregistered == TomAuthState.none);

  // Example 4: no adapter means `full`; an installed adapter decides.
  assert(beforeInstall == TomAuthState.full);
  assert(afterInstall == TomAuthState.full);
  assert(afterInstallOther == TomAuthState.read);
  assert(afterInstallUngranted == TomAuthState.none);

  // Example 5: the state predicates.
  assert(canEditApollo);
  assert(canReadGemini);
  assert(!mercuryVisible);

  // Example 6: stateOf agrees with resolveAuth.
  assert(enforcedApollo == TomAuthState.full);
  assert(enforcedMercury == TomAuthState.none);

  // Example 7: the snapshot is unmodifiable.
  assert(snapshot.length == 4);
  assert(snapshotIsReadOnly);

  print('Resource role authorization example complete.\n');
}

/// Standalone entry point.
void main() {
  prepareSampleProcess();
  run();
}
