/// Demonstrates graded (four-state) access control in the Tom security
/// framework.
///
/// Unlike the binary access controls (granted / denied), [TomGradedAccess]
/// composes three binary controls into all four [TomAuthState] values, so a
/// single field or widget can resolve to *full* (editable), *read* (visible but
/// locked), *disabled* (rendered but greyed out) or *none* (hidden) depending on
/// the current principal.
///
/// Key concepts covered:
/// - Building a [TomGradedAccess] from `full` / `read` / `disabled` controls
/// - [TomGradedAccess.resolveAuthState] resolving each of the four states
/// - The `read` → `full` and `disabled` → `read` defaulting that preserves
///   monotonicity (anyone who can edit can also read and see)
/// - [TomAccessControl.resolveAuthState]'s default binary→four-state bridge
/// - [TomGradedAccess.checkAccessibility] collapsing to [TomAuthState.showsContent]
/// - The [TomAuthState] predicates: `isVisible`, `isInteractive`, `showsContent`
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

import '../../sample_asserts.dart';

// =============================================================================
// Graded Access Example
// =============================================================================

void run() {
  print('=== 06: Graded (four-state) Access Example ===\n');

  // ---------------------------------------------------------------------------
  // Setup: four principals spanning the privilege ladder for a "salary" field.
  // ---------------------------------------------------------------------------
  print('Setting up principals across the privilege ladder...\n');

  final payrollAdmin = TomPrincipal(
    authenticated: true,
    user: TomUser(id: 1, username: 'payroll_admin'),
    aci: TomAccessControlInformation(roles: ['payroll.admin']),
  );

  final manager = TomPrincipal(
    authenticated: true,
    user: TomUser(id: 2, username: 'manager'),
    aci: TomAccessControlInformation(roles: ['manager']),
  );

  final staff = TomPrincipal(
    authenticated: true,
    user: TomUser(id: 3, username: 'staff'),
    aci: TomAccessControlInformation(roles: ['user']),
  );

  final TomPrincipal? anonymous = null; // unauthenticated visitor

  // ---------------------------------------------------------------------------
  // Example 1: a fully-specified graded control.
  //   full → payroll admins, read → managers, disabled → any authenticated user.
  // ---------------------------------------------------------------------------
  print('1. Fully-specified graded control (full/read/disabled):');

  final salary = TomGradedAccess(
    full: const TomRoleAccess(['payroll.admin']),
    read: const TomRoleAccess(['manager']),
    disabled: const TomAuthenticatedAccess(),
  );

  final adminState = salary.resolveAuthState(payrollAdmin);
  final managerState = salary.resolveAuthState(manager);
  final staffState = salary.resolveAuthState(staff);
  final anonState = salary.resolveAuthState(anonymous);

  print('   - payroll admin: $adminState');
  print('   - manager:       $managerState');
  print('   - staff:         $staffState');
  print('   - anonymous:     $anonState\n');

  assert(adminState == TomAuthState.full);
  assert(managerState == TomAuthState.read);
  assert(staffState == TomAuthState.disabled);
  assert(anonState == TomAuthState.none);

  // ---------------------------------------------------------------------------
  // Example 2: the state predicates drive UI rendering decisions.
  // ---------------------------------------------------------------------------
  print(
    '2. TomAuthState predicates (isVisible / isInteractive / showsContent):',
  );

  print(
    '   - full     → visible=${TomAuthState.full.isVisible}, '
    'interactive=${TomAuthState.full.isInteractive}, '
    'showsContent=${TomAuthState.full.showsContent}',
  );
  print(
    '   - read     → visible=${TomAuthState.read.isVisible}, '
    'interactive=${TomAuthState.read.isInteractive}, '
    'showsContent=${TomAuthState.read.showsContent}',
  );
  print(
    '   - disabled → visible=${TomAuthState.disabled.isVisible}, '
    'interactive=${TomAuthState.disabled.isInteractive}, '
    'showsContent=${TomAuthState.disabled.showsContent}',
  );
  print(
    '   - none     → visible=${TomAuthState.none.isVisible}, '
    'interactive=${TomAuthState.none.isInteractive}, '
    'showsContent=${TomAuthState.none.showsContent}\n',
  );

  assert(TomAuthState.full.isInteractive);
  assert(!TomAuthState.read.isInteractive);
  assert(TomAuthState.read.showsContent);
  assert(!TomAuthState.disabled.showsContent);
  assert(TomAuthState.disabled.isVisible);
  assert(!TomAuthState.none.isVisible);

  // ---------------------------------------------------------------------------
  // Example 3: defaulting — `read` defaults to `full`, `disabled` defaults to
  // `read`. Supplying only `full` yields a binary-shaped control that still
  // resolves through the four-state machinery.
  // ---------------------------------------------------------------------------
  print('3. Defaulting (only `full` supplied):');

  final adminOnly = TomGradedAccess(
    full: const TomRoleAccess(['payroll.admin']),
  );

  final adminOnlyForAdmin = adminOnly.resolveAuthState(payrollAdmin);
  final adminOnlyForManager = adminOnly.resolveAuthState(manager);

  print('   - payroll admin: $adminOnlyForAdmin');
  print('   - manager:       $adminOnlyForManager\n');

  // read defaulted to full and disabled defaulted to read (== full), so anyone
  // who is not a payroll admin resolves straight to `none`.
  assert(adminOnlyForAdmin == TomAuthState.full);
  assert(adminOnlyForManager == TomAuthState.none);

  // ---------------------------------------------------------------------------
  // Example 4: checkAccessibility collapses the four states to "can see content"
  // ([TomAuthState.showsContent]) for binary consumers.
  // ---------------------------------------------------------------------------
  print('4. Binary collapse via checkAccessibility (showsContent):');

  final adminCanSee = salary.checkAccessibility(payrollAdmin); // full  → true
  final managerCanSee = salary.checkAccessibility(manager); // read  → true
  final staffCanSee = salary.checkAccessibility(staff); // disabled → false
  final anonCanSee = salary.checkAccessibility(anonymous); // none  → false

  print('   - payroll admin: $adminCanSee');
  print('   - manager:       $managerCanSee');
  print('   - staff:         $staffCanSee');
  print('   - anonymous:     $anonCanSee\n');

  assert(adminCanSee);
  assert(managerCanSee);
  assert(!staffCanSee);
  assert(!anonCanSee);

  // ---------------------------------------------------------------------------
  // Example 5: a plain binary control's default four-state bridge.
  //   TomAccessControl.resolveAuthState maps granted → full, denied → none.
  // ---------------------------------------------------------------------------
  print('5. Binary control default bridge (granted→full, denied→none):');

  const roleOnly = TomRoleAccess(['manager']);
  final binaryGranted = roleOnly.resolveAuthState(manager);
  final binaryDenied = roleOnly.resolveAuthState(staff);

  print('   - manager (granted): $binaryGranted');
  print('   - staff (denied):    $binaryDenied\n');

  assert(binaryGranted == TomAuthState.full);
  assert(binaryDenied == TomAuthState.none);

  print('Graded access example complete.\n');
}

void main() {
  requireAsserts();
  run();
}
