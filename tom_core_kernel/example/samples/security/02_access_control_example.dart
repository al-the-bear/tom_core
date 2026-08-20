/// Demonstrates access control mechanisms in the Tom security framework.
library;

import 'package:tom_core_kernel/tom_core_kernel.dart';

// =============================================================================
// Test Principals Setup
// =============================================================================

final adminPrincipal = TomPrincipal(
  authenticated: true,
  user: TomUser(id: 1, username: 'admin_user'),
  aci: TomAccessControlInformation(
    roles: ['admin', 'user'],
    groups: ['administrators', 'all-employees'],
    entitlements: ['admin.all', 'feature.dashboard.edit'],
    resourceKeys: ['user.email', 'user.phone'],
  ),
);

final regularPrincipal = TomPrincipal(
  authenticated: true,
  user: TomUser(id: 2, username: 'regular_user'),
  aci: TomAccessControlInformation(
    roles: ['user'],
    groups: ['developers', 'all-employees'],
    entitlements: ['feature.dashboard.view'],
    resourceKeys: ['user.email'],
  ),
);

final guestPrincipal = TomPrincipal(authenticated: false, user: TomUser());

// =============================================================================
// EXAMPLE 1: TomPublicAccess - Allows Everyone
// =============================================================================

class PublicAccessExample {
  static bool? adminResult;
  static bool? guestResult;
  static bool? nullResult;
  static bool publicAccessWorks = false;

  static void example1PublicAccess() {
    const publicAccess = TomPublicAccess();

    adminResult = publicAccess.checkAccessibility(adminPrincipal);
    guestResult = publicAccess.checkAccessibility(guestPrincipal);
    nullResult = publicAccess.checkAccessibility(null);

    publicAccessWorks =
        adminResult == true && guestResult == true && nullResult == true;

    assert(adminResult == true, 'Admin should have access');
    assert(guestResult == true, 'Guest should have access');
    assert(nullResult == true, 'Null should have access');
    assert(publicAccessWorks, 'Public access should work');
  }
}

// =============================================================================
// EXAMPLE 2: TomNoAccess - Denies Everyone
// =============================================================================

class NoAccessExample {
  static bool? adminResult;
  static bool? guestResult;
  static bool noAccessWorks = false;

  static void example2NoAccess() {
    const noAccess = TomNoAccess();

    adminResult = noAccess.checkAccessibility(adminPrincipal);
    guestResult = noAccess.checkAccessibility(guestPrincipal);

    noAccessWorks = adminResult == false && guestResult == false;

    assert(adminResult == false, 'Admin should be denied');
    assert(guestResult == false, 'Guest should be denied');
    assert(noAccessWorks, 'No access should work');
  }
}

// =============================================================================
// EXAMPLE 3: TomAuthenticatedAccess - Requires Authenticated User
// =============================================================================

class AuthenticatedAccessExample {
  static bool? adminResult;
  static bool? regularResult;
  static bool? guestResult;
  static bool? nullResult;
  static bool authAccessWorks = false;

  static void example3AuthenticatedAccess() {
    const authenticatedAccess = TomAuthenticatedAccess();

    adminResult = authenticatedAccess.checkAccessibility(adminPrincipal);
    regularResult = authenticatedAccess.checkAccessibility(regularPrincipal);
    guestResult = authenticatedAccess.checkAccessibility(guestPrincipal);
    nullResult = authenticatedAccess.checkAccessibility(null);

    authAccessWorks =
        adminResult == true &&
        regularResult == true &&
        guestResult == false &&
        nullResult == false;

    assert(adminResult == true, 'Admin should have access');
    assert(regularResult == true, 'Regular user should have access');
    assert(guestResult == false, 'Guest should be denied');
    assert(nullResult == false, 'Null should be denied');
    assert(authAccessWorks, 'Authenticated access should work');
  }
}

// =============================================================================
// EXAMPLE 4: TomRoleAccess - Role-Based Access Control
// =============================================================================

class RoleAccessExample {
  static bool? adminOnlyAdmin;
  static bool? adminOnlyRegular;
  static bool? userRoleAdmin;
  static bool? userRoleRegular;
  static bool roleAccessWorks = false;

  static void example4RoleAccess() {
    const adminRoleAccess = TomRoleAccess(['admin']);
    const userRoleAccess = TomRoleAccess(['user']);

    adminOnlyAdmin = adminRoleAccess.checkAccessibility(adminPrincipal);
    adminOnlyRegular = adminRoleAccess.checkAccessibility(regularPrincipal);
    userRoleAdmin = userRoleAccess.checkAccessibility(adminPrincipal);
    userRoleRegular = userRoleAccess.checkAccessibility(regularPrincipal);

    roleAccessWorks =
        adminOnlyAdmin == true &&
        adminOnlyRegular == false &&
        userRoleAdmin == true &&
        userRoleRegular == true;

    assert(adminOnlyAdmin == true, 'Admin should have admin role');
    assert(adminOnlyRegular == false, 'Regular should not have admin role');
    assert(userRoleAdmin == true, 'Admin should have user role');
    assert(userRoleRegular == true, 'Regular should have user role');
    assert(roleAccessWorks, 'Role access should work');
  }
}

// =============================================================================
// EXAMPLE 5: TomGroupAccess - Group-Based Access Control
// =============================================================================

class GroupAccessExample {
  static bool? adminsGroupAdmin;
  static bool? adminsGroupRegular;
  static bool? devsGroupAdmin;
  static bool? devsGroupRegular;
  static bool groupAccessWorks = false;

  static void example5GroupAccess() {
    const adminsGroupAccess = TomGroupAccess(['administrators']);
    const developersGroupAccess = TomGroupAccess(['developers']);

    adminsGroupAdmin = adminsGroupAccess.checkAccessibility(adminPrincipal);
    adminsGroupRegular = adminsGroupAccess.checkAccessibility(regularPrincipal);
    devsGroupAdmin = developersGroupAccess.checkAccessibility(adminPrincipal);
    devsGroupRegular = developersGroupAccess.checkAccessibility(
      regularPrincipal,
    );

    groupAccessWorks =
        adminsGroupAdmin == true &&
        adminsGroupRegular == false &&
        devsGroupAdmin == false &&
        devsGroupRegular == true;

    assert(adminsGroupAdmin == true, 'Admin should be in administrators');
    assert(
      adminsGroupRegular == false,
      'Regular should not be in administrators',
    );
    assert(devsGroupAdmin == false, 'Admin should not be in developers');
    assert(devsGroupRegular == true, 'Regular should be in developers');
    assert(groupAccessWorks, 'Group access should work');
  }
}

// =============================================================================
// EXAMPLE 6: TomEntitlementAccess - Entitlement-Based Access Control
// =============================================================================

class EntitlementAccessExample {
  static bool? dashboardEditAdmin;
  static bool? dashboardEditRegular;
  static bool? dashboardViewAdmin;
  static bool? dashboardViewRegular;
  static bool entitlementAccessWorks = false;

  static void example6EntitlementAccess() {
    const dashboardEditAccess = TomEntitlementAccess([
      'feature.dashboard.edit',
    ]);
    const dashboardViewAccess = TomEntitlementAccess([
      'feature.dashboard.view',
    ]);

    dashboardEditAdmin = dashboardEditAccess.checkAccessibility(adminPrincipal);
    dashboardEditRegular = dashboardEditAccess.checkAccessibility(
      regularPrincipal,
    );
    dashboardViewAdmin = dashboardViewAccess.checkAccessibility(adminPrincipal);
    dashboardViewRegular = dashboardViewAccess.checkAccessibility(
      regularPrincipal,
    );

    entitlementAccessWorks =
        dashboardEditAdmin == true &&
        dashboardEditRegular == false &&
        dashboardViewRegular == true;

    assert(dashboardEditAdmin == true, 'Admin should have dashboard edit');
    assert(
      dashboardEditRegular == false,
      'Regular should not have dashboard edit',
    );
    assert(dashboardViewRegular == true, 'Regular should have dashboard view');
    assert(entitlementAccessWorks, 'Entitlement access should work');
  }
}

// =============================================================================
// EXAMPLE 7: Multiple Roles/Groups Check (OR Logic)
// =============================================================================

class MultipleRolesExample {
  static bool? managerOrAdminAdmin;
  static bool? managerOrAdminRegular;
  static bool multiRoleWorks = false;

  static void example7MultipleRoles() {
    // This checks if user has ANY of the specified roles (OR logic)
    const managerOrAdminAccess = TomRoleAccess(['manager', 'admin']);

    managerOrAdminAdmin = managerOrAdminAccess.checkAccessibility(
      adminPrincipal,
    );
    managerOrAdminRegular = managerOrAdminAccess.checkAccessibility(
      regularPrincipal,
    );

    multiRoleWorks =
        managerOrAdminAdmin == true && managerOrAdminRegular == false;

    assert(
      managerOrAdminAdmin == true,
      'Admin has admin role (one of manager/admin)',
    );
    assert(
      managerOrAdminRegular == false,
      'Regular has neither manager nor admin',
    );
    assert(multiRoleWorks, 'Multiple roles check should work');
  }
}

// =============================================================================
// RUN ALL EXAMPLES
// =============================================================================

void run() {
  PublicAccessExample.example1PublicAccess();
  NoAccessExample.example2NoAccess();
  AuthenticatedAccessExample.example3AuthenticatedAccess();
  RoleAccessExample.example4RoleAccess();
  GroupAccessExample.example5GroupAccess();
  EntitlementAccessExample.example6EntitlementAccess();
  MultipleRolesExample.example7MultipleRoles();
}

void main() => run();
