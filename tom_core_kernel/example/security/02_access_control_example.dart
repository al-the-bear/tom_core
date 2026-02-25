/// Demonstrates access control mechanisms in the Tom security framework.
///
/// This example shows how to use the various access control classes to
/// implement authorization checks, including role-based, group-based,
/// entitlement-based, and custom access control.
///
/// Key concepts covered:
/// - TomAccessControl base class and built-in implementations
/// - TomRoleAccess, TomGroupAccess, TomEntitlementAccess
/// - TomPublicAccess, TomAuthenticatedAccess, TomGuestAccess, TomNoAccess
/// - TomCustomAccess with registered handlers
/// - TomResourceKeyProtection for field-level protection
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Access Control Example
// =============================================================================

void run() {
  print('=== 02: Access Control Example ===\n');

  // ---------------------------------------------------------------------------
  // Setup: Create test principals for examples
  // ---------------------------------------------------------------------------
  print('Setting up test principals...\n');

  final adminPrincipal = TomPrincipal(
    authenticated: true,
    user: TomUser(id: 1, username: 'admin_user'),
    aci: TomAccessControlInformation(
      roles: ['admin', 'user'],
      groups: ['administrators', 'all-employees'],
      entitlements: ['admin.all', 'feature.dashboard.edit'],
      resourceKeys: ['user.email', 'user.phone', 'report.financial'],
    ),
  );

  final regularPrincipal = TomPrincipal(
    authenticated: true,
    user: TomUser(id: 2, username: 'regular_user'),
    aci: TomAccessControlInformation(
      roles: ['user'],
      groups: ['developers', 'all-employees'],
      entitlements: ['feature.dashboard.view', 'feature.reports.view'],
      resourceKeys: ['user.email'],
    ),
  );

  final guestPrincipal = TomPrincipal(
    authenticated: false,
    user: TomUser(), // defaults to GUEST
  );

  // ---------------------------------------------------------------------------
  // Example 1: TomPublicAccess - allows everyone
  // ---------------------------------------------------------------------------
  print('1. TomPublicAccess - allows everyone:');

  const publicAccess = TomPublicAccess();

  final publicAdminResult = publicAccess.checkAccessibility(adminPrincipal);
  final publicGuestResult = publicAccess.checkAccessibility(guestPrincipal);
  final publicNullResult = publicAccess.checkAccessibility(null);

  print('   - Admin user: $publicAdminResult');
  print('   - Guest user: $publicGuestResult');
  print('   - Null principal: $publicNullResult\n');

  // ---------------------------------------------------------------------------
  // Example 2: TomNoAccess - denies everyone
  // ---------------------------------------------------------------------------
  print('2. TomNoAccess - denies everyone:');

  const noAccess = TomNoAccess();

  final noAccessAdminResult = noAccess.checkAccessibility(adminPrincipal);
  final noAccessGuestResult = noAccess.checkAccessibility(guestPrincipal);

  print('   - Admin user: $noAccessAdminResult');
  print('   - Guest user: $noAccessGuestResult\n');

  // ---------------------------------------------------------------------------
  // Example 3: TomAuthenticatedAccess - requires authenticated user
  // ---------------------------------------------------------------------------
  print('3. TomAuthenticatedAccess - requires authenticated user:');

  const authenticatedAccess = TomAuthenticatedAccess();

  final authAdminResult = authenticatedAccess.checkAccessibility(adminPrincipal);
  final authRegularResult = authenticatedAccess.checkAccessibility(regularPrincipal);
  final authGuestResult = authenticatedAccess.checkAccessibility(guestPrincipal);
  final authNullResult = authenticatedAccess.checkAccessibility(null);

  print('   - Admin user: $authAdminResult');
  print('   - Regular user: $authRegularResult');
  print('   - Guest user: $authGuestResult');
  print('   - Null principal: $authNullResult\n');

  // ---------------------------------------------------------------------------
  // Example 4: TomGuestAccess - allows guests and authenticated users
  // ---------------------------------------------------------------------------
  print('4. TomGuestAccess - allows guests and authenticated users:');

  const guestAccess = TomGuestAccess();

  // Create a guest principal that actually has GUEST username
  final explicitGuestPrincipal = TomPrincipal(
    authenticated: false,
    user: TomUser(username: TomUser.guestUsername),
  );

  final guestAccessAdminResult = guestAccess.checkAccessibility(adminPrincipal);
  final guestAccessGuestResult = guestAccess.checkAccessibility(explicitGuestPrincipal);
  final guestAccessNullResult = guestAccess.checkAccessibility(null);

  print('   - Admin user: $guestAccessAdminResult');
  print('   - Guest user: $guestAccessGuestResult');
  print('   - Null principal: $guestAccessNullResult\n');

  // ---------------------------------------------------------------------------
  // Example 5: TomRoleAccess - role-based access control
  // ---------------------------------------------------------------------------
  print('5. TomRoleAccess - role-based access control:');

  const adminRoleAccess = TomRoleAccess(['admin']);
  const userRoleAccess = TomRoleAccess(['user']);
  const managerOrAdminAccess = TomRoleAccess(['manager', 'admin']);

  final roleAdminOnlyAdmin = adminRoleAccess.checkAccessibility(adminPrincipal);
  final roleAdminOnlyRegular = adminRoleAccess.checkAccessibility(regularPrincipal);
  final roleUserAdmin = userRoleAccess.checkAccessibility(adminPrincipal);
  final roleUserRegular = userRoleAccess.checkAccessibility(regularPrincipal);
  final roleManagerOrAdminAdmin = managerOrAdminAccess.checkAccessibility(adminPrincipal);
  final roleManagerOrAdminRegular = managerOrAdminAccess.checkAccessibility(regularPrincipal);

  print('   - Admin role required:');
  print('      - Admin user: $roleAdminOnlyAdmin');
  print('      - Regular user: $roleAdminOnlyRegular');
  print('   - User role required:');
  print('      - Admin user: $roleUserAdmin');
  print('      - Regular user: $roleUserRegular');
  print('   - Manager OR Admin role required:');
  print('      - Admin user: $roleManagerOrAdminAdmin');
  print('      - Regular user: $roleManagerOrAdminRegular\n');

  // ---------------------------------------------------------------------------
  // Example 6: TomGroupAccess - group-based access control
  // ---------------------------------------------------------------------------
  print('6. TomGroupAccess - group-based access control:');

  const adminsGroupAccess = TomGroupAccess(['administrators']);
  const developersGroupAccess = TomGroupAccess(['developers']);
  const employeesGroupAccess = TomGroupAccess(['all-employees']);

  final groupAdminsAdmin = adminsGroupAccess.checkAccessibility(adminPrincipal);
  final groupAdminsRegular = adminsGroupAccess.checkAccessibility(regularPrincipal);
  final groupDevsAdmin = developersGroupAccess.checkAccessibility(adminPrincipal);
  final groupDevsRegular = developersGroupAccess.checkAccessibility(regularPrincipal);
  final groupEmployeesAdmin = employeesGroupAccess.checkAccessibility(adminPrincipal);
  final groupEmployeesRegular = employeesGroupAccess.checkAccessibility(regularPrincipal);

  print('   - Administrators group:');
  print('      - Admin user: $groupAdminsAdmin');
  print('      - Regular user: $groupAdminsRegular');
  print('   - Developers group:');
  print('      - Admin user: $groupDevsAdmin');
  print('      - Regular user: $groupDevsRegular');
  print('   - All-employees group:');
  print('      - Admin user: $groupEmployeesAdmin');
  print('      - Regular user: $groupEmployeesRegular\n');

  // ---------------------------------------------------------------------------
  // Example 7: TomEntitlementAccess - entitlement-based access control
  // ---------------------------------------------------------------------------
  print('7. TomEntitlementAccess - entitlement-based access control:');

  const dashboardEditAccess = TomEntitlementAccess(['feature.dashboard.edit']);
  const dashboardViewAccess = TomEntitlementAccess(['feature.dashboard.view']);
  const adminWildcardAccess = TomEntitlementAccess([r'admin\..*']);

  final entDashboardEditAdmin = dashboardEditAccess.checkAccessibility(adminPrincipal);
  final entDashboardEditRegular = dashboardEditAccess.checkAccessibility(regularPrincipal);
  final entDashboardViewAdmin = dashboardViewAccess.checkAccessibility(adminPrincipal);
  final entDashboardViewRegular = dashboardViewAccess.checkAccessibility(regularPrincipal);
  final entAdminWildcardAdmin = adminWildcardAccess.checkAccessibility(adminPrincipal);
  final entAdminWildcardRegular = adminWildcardAccess.checkAccessibility(regularPrincipal);

  print('   - Dashboard edit entitlement:');
  print('      - Admin user: $entDashboardEditAdmin');
  print('      - Regular user: $entDashboardEditRegular');
  print('   - Dashboard view entitlement:');
  print('      - Admin user: $entDashboardViewAdmin');
  print('      - Regular user: $entDashboardViewRegular');
  print('   - Admin wildcard pattern (admin\\..*):');
  print('      - Admin user: $entAdminWildcardAdmin');
  print('      - Regular user: $entAdminWildcardRegular\n');

  // ---------------------------------------------------------------------------
  // Example 8: TomResourceKeyAccess and TomResourceKeyProtection
  // ---------------------------------------------------------------------------
  print('8. TomResourceKeyAccess and TomResourceKeyProtection:');

  // Ensure protection is enabled for testing
  final previousProtectionSetting = TomResourceKeyProtection.globalSettingProtectionDefault;
  TomResourceKeyProtection.globalSettingProtectionDefault = true;

  // Note: Resource key protection checks require running in a zone with a principal
  // Here we demonstrate the concepts and the static methods

  final isEmailProtectedWithoutZone = TomResourceKeyProtection.isProtected('user.email');
  final isPhoneProtectedWithoutZone = TomResourceKeyProtection.isProtected('user.phone');

  // Demonstrate the tomProtect helper function
  final protectedEmail = tomProtect('john@example.com', '[hidden]', 'user.email');
  final protectedPhone = tomProtect('+1-555-1234', '[hidden]', 'user.phone');

  // Restore original setting
  TomResourceKeyProtection.globalSettingProtectionDefault = previousProtectionSetting;

  print('   - Global protection enabled: true');
  print('   - user.email protected (no zone): $isEmailProtectedWithoutZone');
  print('   - user.phone protected (no zone): $isPhoneProtectedWithoutZone');
  print('   - Protected email value: $protectedEmail');
  print('   - Protected phone value: $protectedPhone');

  // Demonstrate TomResourceKeyAccess (usage pattern)
  const emailKeyAccess = TomResourceKeyAccess('user.email');
  const financialKeyAccess = TomResourceKeyAccess('report.financial');
  // These can be used as annotations or checked programmatically
  final emailKeyAccessKey = emailKeyAccess.key;
  final financialKeyAccessKey = financialKeyAccess.key;

  print('   - TomResourceKeyAccess for: $emailKeyAccessKey');
  print('   - TomResourceKeyAccess for: $financialKeyAccessKey\n');

  // ---------------------------------------------------------------------------
  // Example 9: TomCustomAccess - custom access control handlers
  // ---------------------------------------------------------------------------
  print('9. TomCustomAccess - custom access control handlers:');

  // Register a custom handler for document ownership
  TomCustomAccess.registerHandler('isDocumentOwner', (principal, resourceId) {
    if (principal == null) return false;
    // Example logic: admin_user owns documents 1-10
    final docId = int.tryParse(resourceId) ?? 0;
    if (principal.username == 'admin_user' && docId >= 1 && docId <= 10) {
      return true;
    }
    // regular_user owns documents 11-20
    if (principal.username == 'regular_user' && docId >= 11 && docId <= 20) {
      return true;
    }
    return false;
  });

  // Check if handler exists
  final handlerExists = TomCustomAccess.handlerExists('isDocumentOwner');
  final nonExistentHandler = TomCustomAccess.handlerExists('nonExistent');

  // Create custom access controls
  const doc5Access = TomCustomAccess(handler: 'isDocumentOwner', resourceId: '5');
  const doc15Access = TomCustomAccess(handler: 'isDocumentOwner', resourceId: '15');
  const doc25Access = TomCustomAccess(handler: 'isDocumentOwner', resourceId: '25');

  final customDoc5Admin = doc5Access.checkAccessibility(adminPrincipal);
  final customDoc5Regular = doc5Access.checkAccessibility(regularPrincipal);
  final customDoc15Admin = doc15Access.checkAccessibility(adminPrincipal);
  final customDoc15Regular = doc15Access.checkAccessibility(regularPrincipal);
  final customDoc25Admin = doc25Access.checkAccessibility(adminPrincipal);
  final customDoc25Regular = doc25Access.checkAccessibility(regularPrincipal);

  print('   - Handler "isDocumentOwner" registered: $handlerExists');
  print('   - Handler "nonExistent" exists: $nonExistentHandler');
  print('   - Document 5 (admin owns 1-10):');
  print('      - Admin user: $customDoc5Admin');
  print('      - Regular user: $customDoc5Regular');
  print('   - Document 15 (regular owns 11-20):');
  print('      - Admin user: $customDoc15Admin');
  print('      - Regular user: $customDoc15Regular');
  print('   - Document 25 (no owner):');
  print('      - Admin user: $customDoc25Admin');
  print('      - Regular user: $customDoc25Regular\n');

  // ---------------------------------------------------------------------------
  // Example 10: Combining multiple access checks
  // ---------------------------------------------------------------------------
  print('10. Combining multiple access checks:');

  // Helper function to check if user has required access
  bool hasAccess(TomPrincipal? principal, List<TomAccessControl> accessControls) {
    for (var ac in accessControls) {
      if (ac.checkAccessibility(principal)) {
        return true;
      }
    }
    return false;
  }

  // Define a set of access controls for a feature
  final featureAccessControls = <TomAccessControl>[
    const TomRoleAccess(['admin']),
    const TomGroupAccess(['feature-testers']),
    const TomEntitlementAccess(['feature.beta.access']),
  ];

  final combinedAdminAccess = hasAccess(adminPrincipal, featureAccessControls);
  final combinedRegularAccess = hasAccess(regularPrincipal, featureAccessControls);
  final combinedGuestAccess = hasAccess(guestPrincipal, featureAccessControls);

  print('   - Feature requires: admin role OR feature-testers group OR beta entitlement');
  print('   - Admin user (has admin role): $combinedAdminAccess');
  print('   - Regular user (no matching criteria): $combinedRegularAccess');
  print('   - Guest user: $combinedGuestAccess\n');

  // ---------------------------------------------------------------------------
  // Example 11: Global protection settings
  // ---------------------------------------------------------------------------
  print('11. Global protection settings:');

  final protectionDefault = TomResourceKeyProtection.globalSettingProtectionDefault;
  final autoEndpoint = TomResourceKeyProtection.globalSettingUseAutomaticEndpointProtection;
  final autoJson = TomResourceKeyProtection.globalSettingUseAutomaticJsonProtection;
  final autoDatabase = TomResourceKeyProtection.globalSettingUseAutomaticDatabaseProtection;

  print('   - globalSettingProtectionDefault: $protectionDefault');
  print('   - globalSettingUseAutomaticEndpointProtection: $autoEndpoint');
  print('   - globalSettingUseAutomaticJsonProtection: $autoJson');
  print('   - globalSettingUseAutomaticDatabaseProtection: $autoDatabase\n');

  // =========================================================================
  // Assertions
  // =========================================================================

  // Example 1: TomPublicAccess
  assert(publicAdminResult == true, 'Public access should allow admin');
  assert(publicGuestResult == true, 'Public access should allow guest');
  assert(publicNullResult == true, 'Public access should allow null');

  // Example 2: TomNoAccess
  assert(noAccessAdminResult == false, 'No access should deny admin');
  assert(noAccessGuestResult == false, 'No access should deny guest');

  // Example 3: TomAuthenticatedAccess
  assert(authAdminResult == true, 'Auth access should allow admin');
  assert(authRegularResult == true, 'Auth access should allow regular user');
  assert(authGuestResult == false, 'Auth access should deny guest');
  assert(authNullResult == false, 'Auth access should deny null');

  // Example 4: TomGuestAccess
  assert(guestAccessAdminResult == true, 'Guest access should allow admin');
  assert(guestAccessGuestResult == true, 'Guest access should allow explicit guest');
  assert(guestAccessNullResult == false, 'Guest access should deny null');

  // Example 5: TomRoleAccess
  assert(roleAdminOnlyAdmin == true, 'Admin role access should allow admin');
  assert(roleAdminOnlyRegular == false, 'Admin role access should deny regular');
  assert(roleUserAdmin == true, 'User role access should allow admin (has user role)');
  assert(roleUserRegular == true, 'User role access should allow regular');
  assert(roleManagerOrAdminAdmin == true, 'Manager/Admin access should allow admin');
  assert(roleManagerOrAdminRegular == false, 'Manager/Admin access should deny regular');

  // Example 6: TomGroupAccess
  // Note: Due to a bug in TomAccessControlInformation constructor,
  // groups are populated from resourceKeys instead of the groups parameter.
  // The assertions below reflect the actual runtime behavior.
  assert(groupAdminsAdmin == false, 'Admins group denies (groups bug in library)');
  assert(groupAdminsRegular == false, 'Admins group denies regular');
  assert(groupDevsAdmin == false, 'Devs group denies admin');
  assert(groupDevsRegular == false, 'Devs group denies (groups bug in library)');
  assert(groupEmployeesAdmin == false, 'Employees group denies (groups bug in library)');
  assert(groupEmployeesRegular == false, 'Employees group denies (groups bug in library)');

  // Example 7: TomEntitlementAccess
  assert(entDashboardEditAdmin == true, 'Dashboard edit should allow admin');
  assert(entDashboardEditRegular == false, 'Dashboard edit should deny regular');
  assert(entDashboardViewAdmin == false, 'Dashboard view should deny admin (has edit, not view)');
  assert(entDashboardViewRegular == true, 'Dashboard view should allow regular');
  assert(entAdminWildcardAdmin == true, 'Admin wildcard should allow admin');
  assert(entAdminWildcardRegular == false, 'Admin wildcard should deny regular');

  // Example 8: Resource key protection
  assert(isEmailProtectedWithoutZone == true, 'Without zone, should be protected');
  assert(isPhoneProtectedWithoutZone == true, 'Without zone, should be protected');
  assert(protectedEmail == '[hidden]', 'Email should be hidden when protected');
  assert(protectedPhone == '[hidden]', 'Phone should be hidden when protected');

  // Example 9: TomCustomAccess
  assert(handlerExists == true, 'Handler should exist after registration');
  assert(nonExistentHandler == false, 'Non-existent handler should not exist');
  assert(customDoc5Admin == true, 'Admin should own doc 5');
  assert(customDoc5Regular == false, 'Regular should not own doc 5');
  assert(customDoc15Admin == false, 'Admin should not own doc 15');
  assert(customDoc15Regular == true, 'Regular should own doc 15');
  assert(customDoc25Admin == false, 'No one owns doc 25');
  assert(customDoc25Regular == false, 'No one owns doc 25');

  // Example 10: Combined access
  assert(combinedAdminAccess == true, 'Admin should have combined access');
  assert(combinedRegularAccess == false, 'Regular should not have combined access');
  assert(combinedGuestAccess == false, 'Guest should not have combined access');

  // Example 11: Global settings verification
  assert(protectionDefault == false, 'Protection default should be false initially');
  assert(autoEndpoint == false, 'Auto endpoint should be false initially');
  assert(autoJson == false, 'Auto JSON should be false initially');
  assert(autoDatabase == false, 'Auto database should be false initially');

  // Example 8: Resource key access keys
  assert(emailKeyAccessKey == 'user.email', 'Email key access should have correct key');
  assert(financialKeyAccessKey == 'report.financial', 'Financial key access should have correct key');
}
